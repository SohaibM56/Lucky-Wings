import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/backend_service.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(const AuthState());

  final _backend = BackendService.instance;

  /// Clears any error/loading state left over from a previous attempt —
  /// used when the UI switches between sign-up and sign-in so the old
  /// error banner doesn't linger under the other form.
  ///
  /// Keeps the current user: the guest link screen toggles between link and
  /// sign-in while the guest is still the active session.
  void reset() => emit(AuthState(
      status: state.user != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
      user: state.user));

  Future<void> checkAuth() async {
    emit(state.copyWith(status: AuthStatus.loading));
    final user = await _backend.getCurrentUser();
    if (user != null) {
      emit(state.copyWith(status: AuthStatus.authenticated, user: user));
    } else {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    emit(state.copyWith(
        status: AuthStatus.loading,
        loadingAction: AuthLoadingAction.emailPassword,
        error: null));
    try {
      if (username.trim().length < 3) {
        emit(state.copyWith(
            status: AuthStatus.error,
            loadingAction: AuthLoadingAction.none,
            error: 'Username must be at least 3 characters'));
        return;
      }
      if (password.length < 6) {
        emit(state.copyWith(
            status: AuthStatus.error,
            loadingAction: AuthLoadingAction.none,
            error: 'Password must be at least 6 characters'));
        return;
      }
      final user = await _backend.signUp(
          email: email, password: password, username: username);
      emit(state.copyWith(
          status: AuthStatus.authenticated,
          loadingAction: AuthLoadingAction.none,
          user: user));
    } catch (e) {
      emit(state.copyWith(
          status: AuthStatus.error,
          loadingAction: AuthLoadingAction.none,
          error: e.toString()));
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(
        status: AuthStatus.loading,
        loadingAction: AuthLoadingAction.emailPassword,
        error: null));
    try {
      final user = await _backend.signIn(email: email, password: password);
      if (user != null) {
        emit(state.copyWith(
            status: AuthStatus.authenticated,
            loadingAction: AuthLoadingAction.none,
            user: user));
      } else {
        emit(state.copyWith(
            status: AuthStatus.error,
            loadingAction: AuthLoadingAction.none,
            error: 'Invalid email or password'));
      }
    } catch (e) {
      emit(state.copyWith(
          status: AuthStatus.error,
          loadingAction: AuthLoadingAction.none,
          error: e.toString()));
    }
  }

  Future<void> signInWithGoogle() async {
    emit(state.copyWith(
        status: AuthStatus.loading,
        loadingAction: AuthLoadingAction.google,
        error: null));
    try {
      final user = await _backend.signInWithGoogle();
      emit(state.copyWith(
          status: AuthStatus.authenticated,
          loadingAction: AuthLoadingAction.none,
          user: user));
    } on GoogleLinkRequired catch (e) {
      emit(state.copyWith(
          status: AuthStatus.needsGoogleLink,
          loadingAction: AuthLoadingAction.none,
          conflictEmail: e.email,
          pendingGoogleCredential: e.pendingCredential));
    } catch (e) {
      emit(state.copyWith(
          status: AuthStatus.error,
          loadingAction: AuthLoadingAction.none,
          error: e.toString()));
    }
  }

  /// Finishes the Google-link recovery: signs into the pre-existing
  /// account with its original password, then attaches the Google
  /// credential that triggered needsGoogleLink.
  Future<void> completeGoogleLink(String password) async {
    final email = state.conflictEmail;
    final pendingCredential = state.pendingGoogleCredential;
    if (email == null || pendingCredential == null) return;
    emit(state.copyWith(
        status: AuthStatus.loading,
        loadingAction: AuthLoadingAction.google,
        error: null));
    try {
      final user = await _backend.completeGoogleLink(
          email: email, password: password, pendingCredential: pendingCredential);
      emit(state.copyWith(
          status: AuthStatus.authenticated,
          loadingAction: AuthLoadingAction.none,
          user: user,
          clearGoogleLinkConflict: true));
    } catch (e) {
      emit(state.copyWith(
          status: AuthStatus.error,
          loadingAction: AuthLoadingAction.none,
          error: e.toString(),
          clearGoogleLinkConflict: true));
    }
  }

  void cancelGoogleLink() {
    emit(state.copyWith(
        status: AuthStatus.unauthenticated, clearGoogleLinkConflict: true));
  }

  Future<void> continueAsGuest() async {
    emit(state.copyWith(
        status: AuthStatus.loading,
        loadingAction: AuthLoadingAction.guest,
        error: null));
    try {
      final user = await _backend.continueAsGuest();
      emit(state.copyWith(
          status: AuthStatus.authenticated,
          loadingAction: AuthLoadingAction.none,
          user: user,
          justBecameGuest: true));
    } catch (e) {
      emit(state.copyWith(
          status: AuthStatus.error,
          loadingAction: AuthLoadingAction.none,
          error: e.toString()));
    }
  }

  void clearJustBecameGuest() {
    if (!state.justBecameGuest) return;
    emit(state.copyWith(justBecameGuest: false));
  }

  /// Turns a guest session into a real account, keeping the same uid so
  /// progress/raffle entries carry over.
  Future<void> linkGuestAccount({
    required String email,
    required String password,
    required String username,
  }) async {
    emit(state.copyWith(
        status: AuthStatus.loading,
        loadingAction: AuthLoadingAction.emailPassword,
        error: null));
    try {
      if (username.trim().length < 3) {
        emit(state.copyWith(
            status: AuthStatus.error,
            loadingAction: AuthLoadingAction.none,
            error: 'Username must be at least 3 characters'));
        return;
      }
      if (password.length < 6) {
        emit(state.copyWith(
            status: AuthStatus.error,
            loadingAction: AuthLoadingAction.none,
            error: 'Password must be at least 6 characters'));
        return;
      }
      final user = await _backend.linkGuestToEmail(
          email: email, password: password, username: username);
      emit(state.copyWith(
          status: AuthStatus.authenticated,
          loadingAction: AuthLoadingAction.none,
          user: user));
    } catch (e) {
      emit(state.copyWith(
          status: AuthStatus.error,
          loadingAction: AuthLoadingAction.none,
          error: e.toString()));
    }
  }

  Future<void> sendPasswordReset(String email) =>
      _backend.sendPasswordReset(email);

  Future<void> resendVerificationEmail() => _backend.resendVerificationEmail();

  Future<void> refreshEmailVerification() async {
    final user = await _backend.refreshCurrentUser();
    if (user != null) emit(state.copyWith(user: user));
  }

  Future<void> signOut() async {
    await _backend.signOut();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  /// Re-authenticates (password users give [password]; Google users pick
  /// their account again; guests need nothing), then deletes the account
  /// everywhere. Returns null on success or a message to show the player.
  Future<String?> deleteAccount({String? password}) async {
    final uid = state.user?.uid;
    try {
      switch (_backend.signInMethod) {
        case 'password':
          await _backend.reauthenticateWithPassword(password ?? '');
          break;
        case 'google':
          await _backend.reauthenticateWithGoogle();
          break;
      }
      await _backend.deleteAccount();
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not delete the account, please try again';
    }
    if (uid != null) await _clearLocalData(uid);
    emit(const AuthState(status: AuthStatus.unauthenticated));
    return null;
  }

  /// Removes everything this device stored for the deleted account (coins,
  /// unlocks, scores, queued games, cached records). All keys carry the uid.
  Future<void> _clearLocalData(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.contains(uid)).toList()) {
      await prefs.remove(key);
    }
  }

  Future<void> updateUsername(String username) async {
    if (state.user == null) return;
    await _backend.updateUsername(state.user!.uid, username);
    final updated = await _backend.getCurrentUser();
    if (updated != null) {
      emit(state.copyWith(user: updated));
    }
  }
}
