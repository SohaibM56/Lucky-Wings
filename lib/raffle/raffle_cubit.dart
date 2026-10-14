import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../backend/backend_service.dart';
import 'raffle_service.dart';

part 'raffle_state.dart';

class RaffleCubit extends Cubit<RaffleState> {
  RaffleCubit() : super(const RaffleState());

  final _service = RaffleService.instance;
  Timer? _liveTimer;
  String? _currentUserId;
  // Seconds already banked today from earlier sessions (persisted), so the
  // live display below combines it with the current session's live ticking
  // counter — letting the 5-minute qualifier add up across multiple games.
  int _bankedTodaySeconds = 0;

  // ─── Init ──────────────────────────────────────────────────────────────────

  Future<void> init({String? userId}) async {
    // DashboardPage calls init() with no argument on every open/refresh —
    // without this fallback, that silently wiped an already-known uid back
    // to null, breaking startSession()/onGameOver() (both guard on
    // uid == null) for the rest of the app session.
    _currentUserId = userId ?? _currentUserId;
    await _service.initialize();
    final uid = _currentUserId;
    if (uid != null) {
      await _refresh();
      unawaited(_syncInBackground(uid));
      await checkPendingWin();
    }
  }

  /// Called whenever AuthCubit resolves to a real uid (sign-in, guest
  /// sign-in, or account linking) so the raffle data loads for that user.
  Future<void> setUser(String userId) async {
    if (_currentUserId == userId) return;
    _currentUserId = userId;
    await _refresh();
    unawaited(_syncInBackground(userId));
    await checkPendingWin();
  }

  /// Sends queued games to the server and pulls its copy back, then re-reads
  /// the local record. Runs behind the UI — the timer never waits on it.
  Future<void> _syncInBackground(String uid) async {
    await _service.syncWithServer(uid);
    if (isClosed || _currentUserId != uid) return;
    _applyRecord(await _service.localRecord(uid));
  }

  /// Surfaces an unclaimed raffle win (if any) so the dashboard can show a
  /// claim dialog — called on every dashboard load/sign-in rather than only
  /// from the winner push, since a user might not have been online to
  /// receive that notification.
  Future<void> checkPendingWin() async {
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      final win = await _service.getPendingWin(uid);
      emit(state.copyWith(pendingWin: win));
    } catch (_) {
      // Offline — nothing to show; checked again next time the dashboard
      // opens or the app restarts.
    }
  }

  Future<void> claimWin() async {
    final winId = state.pendingWin?['id'] as String?;
    if (winId == null) return;
    await _service.claimWin(winId);
    emit(state.copyWith(clearPendingWin: true));
  }

  Future<void> _refresh() async {
    final uid = _currentUserId;
    if (uid == null) return;
    _applyRecord(await _service.localRecord(uid));
  }

  void _applyRecord(MonthlyRecord record) {
    final dayKey = _service.todayKey();
    final missedDays = _service.computeMissedDays(record);
    final totalEntries = record.totalEntries;
    _bankedTodaySeconds = record.dailyActiveSeconds[dayKey] ?? 0;
    // From the seconds as well as the record: a sync landing mid-game must not
    // flip this back to false (and re-fire the celebration on the next tick).
    final qualified = record.qualifiedDays.contains(dayKey) ||
        _bankedTodaySeconds + _service.liveActiveSeconds >= 300;

    emit(state.copyWith(
      todayActiveSeconds: _bankedTodaySeconds + _service.liveActiveSeconds,
      todayQualified: qualified,
      totalEntries: totalEntries,
      missedDays: missedDays,
      qualifiedDays: record.qualifiedDays,
      catchupDays: record.catchupDays,
      bestScore: record.bestScore,
      totalSessions: record.totalSessions,
      maxEntries: _service.maxEntries,
      daysLeftInMonth: _service.daysLeftInMonth,
    ));
  }

  // ─── Timer control ────────────────────────────────────────────────────────

  /// Seconds the current game has actually been played (pauses excluded).
  /// Read it before [onGameOver], which ends the session.
  int get currentSessionSeconds => _service.liveActiveSeconds;

  void startSession() {
    final uid = _currentUserId;
    if (uid == null) return;
    _service.beginSession(uid);
    _startLiveTimer();
  }

  void pauseSession() {
    _service.pauseSession();
    _liveTimer?.cancel();
  }

  void resumeSession() {
    _service.resumeSession();
    _startLiveTimer();
  }

  /// Ticks every second, combining today's already-banked seconds (from
  /// earlier sessions) with this session's live counter — so the bar
  /// updates in realtime and the 5-minute qualifier adds up across games.
  void _startLiveTimer() {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final secs = _bankedTodaySeconds + _service.liveActiveSeconds;
      emit(state.copyWith(todayActiveSeconds: secs));
      if (!state.todayQualified && secs >= 300) {
        emit(state.copyWith(todayQualified: true, justEarnedEntry: true));
      }
    });
  }

  // ─── Game over ────────────────────────────────────────────────────────────

  Future<void> onGameOver(int score) async {
    _liveTimer?.cancel();
    final uid = _currentUserId;
    if (uid == null) return;
    // Saved on the device first, no network — returns right away, so the next
    // game always starts from the new total.
    final result = await _service.endSession(userId: uid, finalScore: score);
    _applyRecord(result.record);
    unawaited(_syncInBackground(uid));

    if (result.earnedEntry && !result.suspicious) {
      emit(state.copyWith(
        justEarnedEntry: true,
        lastEntryWasCatchup: result.catchupApplied,
      ));
    }
  }

  void clearJustEarned() {
    emit(state.copyWith(justEarnedEntry: false, lastEntryWasCatchup: false));
  }

  @override
  Future<void> close() {
    _liveTimer?.cancel();
    return super.close();
  }
}
