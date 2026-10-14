// ============================================================
// raffle_service.dart  (v3 — local-first, background sync)
//
// Every finished game is saved on the device first, before any network call,
// and the next timer is read from that local copy. A background sync then
// sends queued games to the server (the Cloud Function is the authority) and
// pulls the server's copy back down — so play never waits on, or gets lost
// to, the network.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../anti_cheat/anti_cheat_engine.dart';
import '../backend/backend_service.dart';
import '../notifications/notification_service.dart';
import 'qualifier_rules.dart';

class RaffleService {
  static RaffleService? _instance;
  static RaffleService get instance => _instance ??= RaffleService._();
  RaffleService._();

  final _backend = BackendService.instance;
  final _antiCheat = AntiCheatEngine.instance;
  final _notifService = NotificationService.instance;

  // Firestore writes only complete once the server acknowledges them, so
  // offline they never complete. Nothing user-facing waits longer than this.
  static const _networkTimeout = Duration(seconds: 4);
  static const _functionTimeout = Duration(seconds: 12);

  String todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String monthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<void> initialize() async {
    await _notifService.initialize();
  }

  // ─── Reading: always from the local copy ──────────────────────────────────

  /// This month's record as this device should show it: the last
  /// server-confirmed copy it holds, plus every game still waiting to sync.
  /// Never waits on the network once the device has a local copy.
  Future<MonthlyRecord> localRecord(String userId) async {
    final base = await _cachedRecord(userId, monthKey()) ??
        await refreshFromServer(userId) ??
        MonthlyRecord(userId: userId, monthKey: monthKey());
    return _applyOutbox(base, userId);
  }

  /// Pulls the server's copy into the local one. Null if unreachable.
  Future<MonthlyRecord?> refreshFromServer(String userId) async {
    try {
      final record = await _backend
          .getMonthlyRecord(userId, monthKey())
          .timeout(_networkTimeout);
      await _cacheRecord(record);
      return record;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getPendingWin(String userId) =>
      _backend.getPendingWin(userId);

  Future<void> claimWin(String winId) => _backend.claimWin(winId);

  // ─── Timer control ────────────────────────────────────────────────────────

  void beginSession(String userId) => _antiCheat.beginSession(userId);
  void pauseSession() => _antiCheat.pauseSession();
  void resumeSession() => _antiCheat.resumeSession();
  int get liveActiveSeconds => _antiCheat.activeSeconds;

  // ─── End of session: save locally first ───────────────────────────────────

  /// Local only — no network. The game goes into the outbox and the returned
  /// record already includes it; call [syncWithServer] afterwards.
  Future<SessionResult> endSession({
    required String userId,
    required int finalScore,
  }) async {
    final token = await _antiCheat.endSession(finalScore);

    if (token == null) {
      return SessionResult(
        earnedEntry: false,
        catchupApplied: false,
        isQualified: false,
        record: await localRecord(userId),
        suspicious: true,
      );
    }

    final suspicious = token.activeSeconds == 0 || _antiCheat.isSuspicious;
    SessionResult result;

    if (suspicious) {
      final record = await localRecord(userId);
      result = SessionResult(
        earnedEntry: false,
        catchupApplied: false,
        isQualified: record.qualifiedDays.contains(token.dayKey),
        record: record,
        suspicious: true,
      );
    } else {
      final before = await localRecord(userId);
      await _enqueue(userId, token);
      final applied = _applySession(before,
          dayKey: token.dayKey,
          activeSeconds: token.activeSeconds,
          score: finalScore);
      result = SessionResult(
        earnedEntry: applied.earnedEntry,
        catchupApplied: applied.catchupApplied,
        isQualified: applied.record.qualifiedDays.contains(token.dayKey),
        record: applied.record,
        suspicious: false,
      );
    }

    try {
      await _notifService.rescheduleAll(
        qualifiedToday: result.isQualified,
        missedCount: computeMissedDays(result.record).length,
        daysLeftInMonth: daysLeftInMonth,
      );
    } catch (_) {
      // Scheduling a reminder is a side effect, not part of the result — a
      // failure here (e.g. Android 12+'s exact-alarm permission not granted)
      // must never take down endSession(): it used to propagate up through
      // RaffleCubit.onGameOver() before the new total was applied, so the
      // countdown kept counting from a stale value.
    }

    return result;
  }

  /// Banks a session's seconds and grants entries — see qualifier_rules.dart.
  /// Pure (no I/O), so the live path and outbox replay share it.
  ({MonthlyRecord record, bool earnedEntry, bool catchupApplied}) _applySession(
    MonthlyRecord record, {
    required String dayKey,
    required int activeSeconds,
    required int score,
  }) =>
      applySessionToRecord(record,
          dayKey: dayKey,
          activeSeconds: activeSeconds,
          score: score,
          now: DateTime.now());

  // ─── Outbox: games saved locally, waiting to reach the server ─────────────

  String _outboxKey(String userId) => 'outbox_$userId';

  Future<void> _enqueue(String userId, SessionToken token) async {
    final prefs = await SharedPreferences.getInstance();
    final outbox = prefs.getStringList(_outboxKey(userId)) ?? [];
    // The full signed token, so the server can still verify it later.
    outbox.add(jsonEncode(token.toMap()));
    await prefs.setStringList(_outboxKey(userId), outbox);
  }

  Future<void> _dequeue(String userId, String entry) async {
    final prefs = await SharedPreferences.getInstance();
    final outbox = prefs.getStringList(_outboxKey(userId)) ?? [];
    outbox.remove(entry);
    await prefs.setStringList(_outboxKey(userId), outbox);
  }

  /// Replays queued games on top of [record], for display only.
  Future<MonthlyRecord> _applyOutbox(
      MonthlyRecord record, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    var result = record;
    for (final raw in prefs.getStringList(_outboxKey(userId)) ?? <String>[]) {
      final game = jsonDecode(raw) as Map<String, dynamic>;
      if (game['monthKey'] != result.monthKey) continue;
      result = _applySession(result,
              dayKey: game['dayKey'] as String,
              activeSeconds: game['activeSeconds'] as int,
              score: game['score'] as int)
          .record;
    }
    return result;
  }

  // ─── Background sync ──────────────────────────────────────────────────────

  bool _syncing = false;
  bool _syncAgain = false;

  /// Sends queued games to the server, then pulls its copy down. Safe to call
  /// any time and as often as you like: offline it just leaves everything
  /// queued, and overlapping calls are folded into the one already running.
  Future<void> syncWithServer(String userId) async {
    await reconcilePendingSessions(userId);
    await refreshFromServer(userId);
  }

  Future<void> reconcilePendingSessions(String userId) async {
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncAgain = false;
        while (await _sendNext(userId)) {}
      } while (_syncAgain);
    } finally {
      _syncing = false;
    }
  }

  /// Sends the oldest queued game. True once it's settled (so the next one can
  /// go); false when there's nothing left or the server couldn't be reached.
  Future<bool> _sendNext(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final outbox = prefs.getStringList(_outboxKey(userId)) ?? [];
    if (outbox.isEmpty) return false;
    final entry = outbox.first;
    final game = jsonDecode(entry) as Map<String, dynamic>;

    Map<String, dynamic> response;
    try {
      response =
          await _backend.verifyQualification(game).timeout(_functionTimeout);
    } catch (_) {
      return false; // offline, slow or function down — stays queued
    }

    final record = response['record'];
    if (record != null) {
      await _cacheRecord(
          MonthlyRecord.fromMap(Map<String, dynamic>.from(record)));
    }
    // No record means the server turned the game down (or, for
    // duplicate_session, already counted it) — either way it's settled.
    await _dequeue(userId, entry);
    return true;
  }

  // ─── Local copy of the last server-confirmed record ───────────────────────

  String _lastRecordKey(String userId, String monthKey) =>
      'last_record_${userId}_$monthKey';

  Future<void> _cacheRecord(MonthlyRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastRecordKey(record.userId, record.monthKey),
        jsonEncode(record.toMap()));
  }

  Future<MonthlyRecord?> _cachedRecord(String userId, String monthKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastRecordKey(userId, monthKey));
    if (raw == null) return null;
    return MonthlyRecord.fromMap(Map<String, dynamic>.from(jsonDecode(raw)));
  }

  // ─── Calendar helpers ─────────────────────────────────────────────────────

  Future<List<String>> getMissedDays(String userId) async {
    final record = await localRecord(userId);
    return computeMissedDays(record);
  }

  List<String> computeMissedDays(MonthlyRecord record) =>
      missedDaysFor(record, DateTime.now());

  int get daysLeftInMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0).day - now.day;
  }

  int get maxEntries {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0).day;
  }
}

class SessionResult {
  final bool earnedEntry;
  final bool catchupApplied;
  final bool isQualified;
  final MonthlyRecord record;
  final bool suspicious;
  const SessionResult({
    required this.earnedEntry,
    required this.catchupApplied,
    required this.isQualified,
    required this.record,
    required this.suspicious,
  });
}
