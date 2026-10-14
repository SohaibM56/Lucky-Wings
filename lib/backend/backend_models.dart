import 'package:firebase_auth/firebase_auth.dart' show AuthCredential;

/// A Firebase auth error translated to a short, user-facing message —
/// cubits/pages can just display `e.toString()` without leaking Firebase
/// error codes to the UI.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

/// Thrown when a Google sign-in's email already belongs to a different,
/// pre-existing account under another provider (e.g. email/password).
/// Google credentials can't be linked onto a different account directly —
/// the user has to sign in with their original method first, then this
/// pending credential gets attached to that account.
class GoogleLinkRequired implements Exception {
  final String email;
  final AuthCredential pendingCredential;
  const GoogleLinkRequired(this.email, this.pendingCredential);
}

class FireBaseUser {
  final String uid;
  final String username;
  final String email;
  final String avatarId;
  final int totalWins;
  final DateTime createdAt;
  final bool isAnonymous;
  final bool emailVerified;

  const FireBaseUser({
    required this.uid,
    required this.username,
    required this.email,
    this.avatarId = 'bird_1',
    this.totalWins = 0,
    required this.createdAt,
    this.isAnonymous = false,
    this.emailVerified = false,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'username': username,
        'email': email,
        'avatarId': avatarId,
        'totalWins': totalWins,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FireBaseUser.fromMap(Map<String, dynamic> m) => FireBaseUser(
        uid: m['uid'] ?? '',
        username: m['username'] ?? 'Player',
        email: m['email'] ?? '',
        avatarId: m['avatarId'] ?? 'bird_1',
        totalWins: m['totalWins'] ?? 0,
        createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
      );
}

class MonthlyRecord {
  final String userId;
  final String monthKey; // "2026-05"
  final List<String> qualifiedDays;
  final List<String> catchupDays;
  final int bestScore;
  final int totalSessions;
  final int totalPlaySeconds;
  // Cumulative active-play seconds per calendar day ("2026-05-15" -> secs),
  // so the 5-minute qualifier can be earned across multiple games in the
  // same day rather than requiring one continuous session.
  final Map<String, int> dailyActiveSeconds;

  const MonthlyRecord({
    required this.userId,
    required this.monthKey,
    this.qualifiedDays = const [],
    this.catchupDays = const [],
    this.bestScore = 0,
    this.totalSessions = 0,
    this.totalPlaySeconds = 0,
    this.dailyActiveSeconds = const {},
  });

  int get totalEntries => qualifiedDays.length + catchupDays.length;

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'monthKey': monthKey,
        'qualifiedDays': qualifiedDays,
        'catchupDays': catchupDays,
        'bestScore': bestScore,
        'totalSessions': totalSessions,
        'totalPlaySeconds': totalPlaySeconds,
        'dailyActiveSeconds': dailyActiveSeconds,
        'totalEntries': totalEntries,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  factory MonthlyRecord.fromMap(Map<String, dynamic> m) => MonthlyRecord(
        userId: m['userId'] ?? '',
        monthKey: m['monthKey'] ?? '',
        qualifiedDays: List<String>.from(m['qualifiedDays'] ?? []),
        catchupDays: List<String>.from(m['catchupDays'] ?? []),
        bestScore: m['bestScore'] ?? 0,
        totalSessions: m['totalSessions'] ?? 0,
        totalPlaySeconds: m['totalPlaySeconds'] ?? 0,
        dailyActiveSeconds:
            Map<String, int>.from(m['dailyActiveSeconds'] ?? {}),
      );
}

class LeaderboardEntry {
  final String userId;
  final String username;
  final String avatarId;
  final int bestScore;
  final int totalEntries;
  final String monthKey;

  const LeaderboardEntry({
    required this.userId,
    required this.username,
    required this.avatarId,
    required this.bestScore,
    required this.totalEntries,
    required this.monthKey,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> m) => LeaderboardEntry(
        userId: m['userId'] ?? '',
        username: m['username'] ?? 'Player',
        avatarId: m['avatarId'] ?? 'bird_1',
        bestScore: m['bestScore'] ?? 0,
        totalEntries: m['totalEntries'] ?? 0,
        monthKey: m['monthKey'] ?? '',
      );
}

/// A user's rank/entry when they fall outside getLeaderboard's fetched
/// top-N window — computed separately via BackendService.getOwnRank.
class LeaderboardOwnRank {
  final int rank; // 1-based
  final LeaderboardEntry entry;

  const LeaderboardOwnRank({required this.rank, required this.entry});
}
