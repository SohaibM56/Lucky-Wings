import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'backend_models.dart';

export 'backend_models.dart';

class BackendService {
  static BackendService? _instance;
  static BackendService get instance => _instance ??= BackendService._();
  BackendService._();

  final _auth = fb_auth.FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;
  final _googleSignIn = GoogleSignIn();

  Future<FireBaseUser?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    return _userDoc(firebaseUser);
  }

  Future<FireBaseUser> signUp(
      {required String email,
      required String password,
      required String username}) {
    return _authCall(() async {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await cred.user!.sendEmailVerification();
      return _userDoc(cred.user!, fallbackUsername: username);
    });
  }

  Future<FireBaseUser?> signIn(
      {required String email, required String password}) {
    return _authCall(() async {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _userDoc(cred.user!);
    });
  }

  Future<FireBaseUser> signInWithGoogle() {
    return _authCall(() async {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw fb_auth.FirebaseAuthException(
          code: 'sign-in-cancelled',
          message: 'Google sign-in was cancelled.',
        );
      }
      final googleAuth = await googleUser.authentication;
      final credential = fb_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final current = _auth.currentUser;
      final wasGuest = current != null && current.isAnonymous;
      fb_auth.UserCredential cred;

      if (wasGuest) {
        try {
          cred = await current.linkWithCredential(credential);
          await _upgradeGuestDoc(cred.user!.uid,
              username: googleUser.displayName ?? 'Player',
              email: cred.user!.email);
        } on fb_auth.FirebaseAuthException catch (e) {
          if (e.code != 'credential-already-in-use' &&
              e.code != 'email-already-in-use') rethrow;
          // This Google identity already belongs to a different existing
          // account — it can't be merged into the guest session, so sign
          // into that existing account instead of leaving the user stuck
          // behind an "account already exists" dead end. The guest
          // session's local progress is abandoned, same as any other
          // switch to a pre-existing account.
          cred = await _signInWithGoogleCredential(credential);
        }
      } else {
        cred = await _signInWithGoogleCredential(credential);
      }

      return _userDoc(cred.user!, fallbackUsername: googleUser.displayName);
    });
  }

  /// Plain Google sign-in (no guest session to link from). If this email
  /// already belongs to an account registered under a different provider
  /// (e.g. email/password) that was never linked to Google, Firebase
  /// refuses to sign in directly — the user has to prove ownership via
  /// their original method first, so this surfaces that as a distinct
  /// exception instead of a flat "account already exists" dead end.
  Future<fb_auth.UserCredential> _signInWithGoogleCredential(
      fb_auth.AuthCredential credential) async {
    try {
      return await _auth.signInWithCredential(credential);
    } on fb_auth.FirebaseAuthException catch (e) {
      if (e.code != 'account-exists-with-different-credential') rethrow;
      throw GoogleLinkRequired(e.email ?? '', credential);
    }
  }

  /// Finishes the GoogleLinkRequired recovery: signs into the pre-existing
  /// account with its original password, then attaches the Google
  /// credential that was blocked earlier so future Google sign-ins work
  /// directly without hitting this again.
  Future<FireBaseUser> completeGoogleLink({
    required String email,
    required String password,
    required fb_auth.AuthCredential pendingCredential,
  }) {
    return _authCall(() async {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      await cred.user!.linkWithCredential(pendingCredential);
      return _userDoc(cred.user!);
    });
  }

  Future<FireBaseUser> continueAsGuest() {
    return _authCall(() async {
      final cred = await _auth.signInAnonymously();
      return _userDoc(cred.user!, fallbackUsername: 'Guest');
    });
  }

  Future<FireBaseUser> linkGuestToEmail(
      {required String email,
      required String password,
      required String username}) {
    return _authCall(() async {
      final current = _auth.currentUser;
      if (current == null || !current.isAnonymous) {
        throw StateError('No guest session to link');
      }
      final credential = fb_auth.EmailAuthProvider.credential(
          email: email, password: password);
      final cred = await current.linkWithCredential(credential);
      await cred.user!.sendEmailVerification();
      await _upgradeGuestDoc(cred.user!.uid, username: username, email: email);
      return _userDoc(cred.user!, fallbackUsername: username);
    });
  }

  /// Linking a guest keeps the same uid, so users/{uid} already exists with
  /// the placeholder data continueAsGuest() wrote ('Guest', no email).
  /// _userDoc()'s existing-doc branch only reads that doc, it never writes —
  /// without this, the real name/email picked at link time would silently
  /// never reach Firestore, stuck behind the old placeholder forever.
  Future<void> _upgradeGuestDoc(String uid,
      {required String username, String? email}) async {
    await _firestore.collection('users').doc(uid).set({
      'username': username,
      if (email != null) 'email': email,
    }, SetOptions(merge: true));
  }

  Future<void> sendPasswordReset(String email) =>
      _authCall(() => _auth.sendPasswordResetEmail(email: email));

  Future<void> resendVerificationEmail() =>
      _auth.currentUser?.sendEmailVerification() ?? Future.value();

  static const _knownAuthCodes = [
    'sign-in-cancelled',
    'user-not-found',
    'wrong-password',
    'invalid-credential',
    'email-already-in-use',
    'credential-already-in-use',
    'invalid-email',
    'missing-email',
    'weak-password',
    'missing-password',
    'network-request-failed',
    'too-many-requests',
  ];

  /// Runs a Firebase auth call, translating FirebaseAuthException into a
  /// short AuthException so the UI never has to show raw Firebase error codes.
  ///
  /// Confirmed via logcat (2026-10-12): the very first sign-up/sign-in/link
  /// call after a cold app start can race the Auth SDK's internal reCAPTCHA
  /// Enterprise verification client (used for its abuse protection) — that
  /// client's own network request gets an SSL "Connection reset by peer"
  /// before the TLS session is fully warmed up, which Firebase Auth then
  /// surfaces as a FirebaseAuthException with code "unknown" rather than any
  /// of its normal named codes. An identical retry a moment later always
  /// succeeds, since by then the connection is warm. Rather than surface
  /// that to the user as "Something went wrong, please try again" and make
  /// them do the retry by hand, retry it here once, transparently.
  Future<T> _authCall<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on fb_auth.FirebaseAuthException catch (e) {
      if (e.code == 'unknown') {
        try {
          return await action();
        } on fb_auth.FirebaseAuthException catch (e2) {
          if (!_knownAuthCodes.contains(e2.code)) {
            debugPrint(
                'Unmapped FirebaseAuthException in _authCall (after retry): code=${e2.code} message=${e2.message}');
          }
          throw AuthException(_friendlyAuthMessage(e2));
        }
      }
      if (!_knownAuthCodes.contains(e.code)) {
        debugPrint(
            'Unmapped FirebaseAuthException in _authCall: code=${e.code} message=${e.message}');
      }
      throw AuthException(_friendlyAuthMessage(e));
    }
  }

  String _friendlyAuthMessage(fb_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'sign-in-cancelled':
        return 'Google sign-in cancelled';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password';
      case 'email-already-in-use':
      case 'credential-already-in-use':
        return 'An account already exists for that email';
      case 'invalid-email':
        return 'That email address looks invalid';
      case 'missing-email':
        return 'Please enter an email address';
      case 'weak-password':
        return 'Choose a stronger password';
      case 'missing-password':
        return 'Please enter a password';
      case 'network-request-failed':
        return 'No internet connection';
      case 'too-many-requests':
        return 'Too many attempts — try again later';
      default:
        return 'Something went wrong, please try again';
    }
  }

  Future<FireBaseUser?> refreshCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    await firebaseUser.reload();
    return _userDoc(_auth.currentUser!);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ─── Account deletion ───────────────────────────────────────────────────────

  /// How the current user signed in: 'anonymous' (guest), 'google' or
  /// 'password'. Decides which re-authentication step deletion needs.
  String get signInMethod {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return 'anonymous';
    final providers = user.providerData.map((p) => p.providerId).toList();
    if (providers.contains('password')) return 'password';
    if (providers.contains('google.com')) return 'google';
    return 'password';
  }

  /// Confirms the player's identity again (Firebase / the server require a
  /// sign-in from the last few minutes before an account can be deleted).
  Future<void> reauthenticateWithPassword(String password) => _authCall(() async {
        final user = _auth.currentUser!;
        final cred = fb_auth.EmailAuthProvider.credential(
            email: user.email ?? '', password: password);
        await user.reauthenticateWithCredential(cred);
      });

  Future<void> reauthenticateWithGoogle() => _authCall(() async {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          throw fb_auth.FirebaseAuthException(
              code: 'sign-in-cancelled', message: 'Google sign-in cancelled.');
        }
        final googleAuth = await googleUser.authentication;
        final cred = fb_auth.GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
        await _auth.currentUser!.reauthenticateWithCredential(cred);
      });

  /// Deletes the signed-in player's data and sign-in on the server (Cloud
  /// Function `deleteAccount`), then clears the local session. Throws
  /// [AuthException] with a message that is safe to show.
  Future<void> deleteAccount() async {
    try {
      // Fresh ID token so the server sees the re-authentication just done.
      await _auth.currentUser?.getIdToken(true);
      await _functions.httpsCallable('deleteAccount').call();
    } on FirebaseFunctionsException catch (e) {
      if (e.message == 'reauth-required') {
        throw const AuthException('Please confirm your identity and try again');
      }
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw const AuthException('No internet connection');
      }
      debugPrint('deleteAccount failed: ${e.code} ${e.message}');
      throw const AuthException('Could not delete the account, please try again');
    }
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut(); // the user no longer exists; this clears the cache
  }

  Future<void> updateUsername(String uid, String username) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .update({'username': username});
  }

  /// Persists this device's FCM token so the Cloud Functions (winner push,
  /// draw-day reminder) can reach it. Safe to call repeatedly — merges
  /// rather than overwrites the rest of the user doc.
  Future<void> updateFcmToken(String uid, String token) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }

  Future<FireBaseUser> _userDoc(fb_auth.User firebaseUser,
      {String? fallbackUsername}) async {
    final docRef = _firestore.collection('users').doc(firebaseUser.uid);
    final doc = await docRef.get();

    if (doc.exists) {
      final data = doc.data()!;
      return FireBaseUser(
        uid: firebaseUser.uid,
        username: data['username'] ?? fallbackUsername ?? 'Player',
        email: firebaseUser.email ?? '',
        avatarId: data['avatarId'] ?? 'bird_1',
        totalWins: data['totalWins'] ?? 0,
        createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
        isAnonymous: firebaseUser.isAnonymous,
        emailVerified: firebaseUser.emailVerified,
      );
    }

    final user = FireBaseUser(
      uid: firebaseUser.uid,
      username: fallbackUsername ?? 'Player',
      email: firebaseUser.email ?? '',
      createdAt: DateTime.now(),
      isAnonymous: firebaseUser.isAnonymous,
      emailVerified: firebaseUser.emailVerified,
    );
    await docRef.set(user.toMap());
    return user;
  }

  /// Read-only: an empty record when none exists yet. The doc is created by
  /// the first verified game (Cloud Function) — creating it here used to risk
  /// an offline-queued empty write overwriting the real record once synced.
  Future<MonthlyRecord> getMonthlyRecord(String uid, String monthKey) async {
    final doc = await _firestore
        .collection('monthly_records')
        .doc('${uid}_$monthKey')
        .get();
    return doc.exists
        ? MonthlyRecord.fromMap(doc.data()!)
        : MonthlyRecord(userId: uid, monthKey: monthKey);
  }

  // ─── Leaderboard ──────────────────────────────────────────────────────────

  /// Fetch top N players for the current month leaderboard.
  Future<List<LeaderboardEntry>> getLeaderboard(String monthKey,
      {int limit = 50}) async {
    final snap = await _firestore
        .collection('monthly_records')
        .where('monthKey', isEqualTo: monthKey)
        .orderBy('bestScore', descending: true)
        .limit(limit)
        .get();

    // username/avatarId are denormalized onto monthly_records by
    // verifyQualification, so no per-entry join against users/{uid} is
    // needed here.
    return snap.docs.map((doc) {
      final data = doc.data();
      return LeaderboardEntry(
        userId: data['userId'] ?? '',
        username: data['username'] ?? 'Player',
        avatarId: data['avatarId'] ?? 'bird_1',
        bestScore: data['bestScore'] ?? 0,
        totalEntries: data['totalEntries'] ?? 0,
        monthKey: monthKey,
      );
    }).toList();
  }

  /// Rank and entry for a user who didn't show up in getLeaderboard's
  /// top-N — e.g. outside the top 50. Reads the user's own monthly_records
  /// doc directly (cheap, single doc by id), then uses a count() aggregation
  /// query (no document downloads) to find how many players rank above
  /// them. Returns null if the user has no record for this month yet.
  Future<LeaderboardOwnRank?> getOwnRank(String uid, String monthKey) async {
    final ownDoc = await _firestore
        .collection('monthly_records')
        .doc('${uid}_$monthKey')
        .get();
    if (!ownDoc.exists) return null;
    final data = ownDoc.data()!;
    final bestScore = data['bestScore'] ?? 0;

    final aheadCount = await _firestore
        .collection('monthly_records')
        .where('monthKey', isEqualTo: monthKey)
        .where('bestScore', isGreaterThan: bestScore)
        .count()
        .get();

    return LeaderboardOwnRank(
      rank: (aheadCount.count ?? 0) + 1,
      entry: LeaderboardEntry(
        userId: data['userId'] ?? uid,
        username: data['username'] ?? 'Player',
        avatarId: data['avatarId'] ?? 'bird_1',
        bestScore: bestScore,
        totalEntries: data['totalEntries'] ?? 0,
        monthKey: monthKey,
      ),
    );
  }

  // ─── Anti-cheat ─────────────────────────────────────────────────────────────

  /// Server-side re-validation of a completed session's signed token. The
  /// Cloud Function is the authoritative decision-maker — it re-checks the
  /// heartbeats/wall-clock/replay guards and writes monthly_records itself;
  /// the client only reads the result back.
  Future<Map<String, dynamic>> verifyQualification(
      Map<String, dynamic> sessionToken) async {
    final callable = _functions.httpsCallable('verifyQualification');
    final result = await callable.call<Map<Object?, Object?>>(sessionToken);
    return Map<String, dynamic>.from(result.data);
  }

  // ─── Raffle ───────────────────────────────────────────────────────────────

  /// Fetch the current month's prize info (set by admin in raffle_config).
  Future<String> getCurrentPrize(String monthKey) async {
    final doc =
        await _firestore.collection('raffle_config').doc(monthKey).get();
    return doc.data()?['prize'] ?? 'Monthly Prize 🎁';
  }

  /// Check if there is an unclaimed win waiting for this user.
  Future<Map<String, dynamic>?> getPendingWin(String uid) async {
    final snap = await _firestore
        .collection('raffle_winners')
        .where('userId', isEqualTo: uid)
        .where('claimed', isEqualTo: false)
        .get();
    // expireUnclaimedWins flags missed wins `expired` but leaves claimed
    // false, so filter them here or the claim dialog would keep reappearing.
    final open = snap.docs.where((d) => d.data()['expired'] != true);
    if (open.isEmpty) return null;
    final doc = open.first;
    return {...doc.data(), 'id': doc.id};
  }

  /// Mark a win as claimed so expireUnclaimedWins stops counting it down.
  Future<void> claimWin(String winId) async {
    await _firestore.collection('raffle_winners').doc(winId).update({
      'claimed': true,
      'claimedAt': FieldValue.serverTimestamp(),
    });
  }
}
