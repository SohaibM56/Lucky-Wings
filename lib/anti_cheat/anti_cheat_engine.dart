// ============================================================
// anti_cheat_engine.dart
//
// Protects the qualifier timer and raffle entry system from:
//   1. Clock manipulation (system time cheating)
//   2. App modification (self-reporting qualification)
//   3. Session replay (resubmitting the same session twice)
//   4. Background timer accumulation
//   5. Heartbeat forgery (rapid fake pings)
//
// The engine runs entirely on the CLIENT and produces signed
// session tokens. In production these tokens are verified by
// a Firebase Cloud Function before entries are granted.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Session Token ─────────────────────────────────────────────────────────

/// A signed proof that a player accumulated real playtime.
/// The server validates this token before granting a raffle entry.
class SessionToken {
  final String sessionId;
  final String userId;
  final String dayKey; // "2026-05-15"
  final String monthKey; // "2026-05"
  final int activeSeconds; // verified active seconds
  final int score;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<int> heartbeatTimestamps; // epoch-ms of each heartbeat
  final String checksum; // HMAC-style integrity check

  const SessionToken({
    required this.sessionId,
    required this.userId,
    required this.dayKey,
    required this.monthKey,
    required this.activeSeconds,
    required this.score,
    required this.startedAt,
    required this.endedAt,
    required this.heartbeatTimestamps,
    required this.checksum,
  });

  bool get meetsQualifierThreshold => activeSeconds >= 300;

  Map<String, dynamic> toMap() => {
        'sessionId': sessionId,
        'userId': userId,
        'dayKey': dayKey,
        'monthKey': monthKey,
        'activeSeconds': activeSeconds,
        'score': score,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'heartbeatCount': heartbeatTimestamps.length,
        'heartbeatTimestamps': heartbeatTimestamps,
        'checksum': checksum,
      };
}

// ─── Heartbeat Monitor ────────────────────────────────────────────────────────

/// Tracks the rhythm of heartbeat pings to detect forgery.
/// Real gameplay produces heartbeats spaced ~30s apart.
/// Forged heartbeats are typically too fast or perfectly uniform.
class HeartbeatMonitor {
  final List<int> _beats = []; // epoch-ms timestamps
  static const _intervalMs = 30000; // expected ~30s between beats
  static const _toleranceMs = 5000; // ±5s tolerance

  void recordBeat() {
    _beats.add(DateTime.now().millisecondsSinceEpoch);
  }

  /// Returns false if the heartbeat pattern looks forged.
  bool isPatternLegitimate() {
    if (_beats.length < 2) return true;
    int suspicious = 0;
    for (int i = 1; i < _beats.length; i++) {
      final gap = _beats[i] - _beats[i - 1];
      if (gap < _intervalMs - _toleranceMs ||
          gap > _intervalMs + _toleranceMs * 4) {
        suspicious++;
      }
    }
    // Allow up to 30% anomalous gaps (pauses, backgrounding are legitimate)
    return suspicious / (_beats.length - 1) < 0.3;
  }

  List<int> get beats => List.unmodifiable(_beats);
  void reset() => _beats.clear();
}

// ─── Anti-Cheat Engine ────────────────────────────────────────────────────────

class AntiCheatEngine {
  static AntiCheatEngine? _instance;
  static AntiCheatEngine get instance => _instance ??= AntiCheatEngine._();
  AntiCheatEngine._();

  // ─── State ──────────────────────────────────────────────────────────────

  String? _currentSessionId;
  String? _currentUserId;
  DateTime? _sessionStart;
  DateTime? _lastPauseAt;
  Duration _totalPauseDuration = Duration.zero;
  int _score = 0;
  bool _isRunning = false;
  // True from beginSession() until endSession(). activeSeconds reads 0
  // outside that window — otherwise the timestamp-derived value keeps
  // growing after game over and gets added on top of the banked total that
  // already includes this session, double-counting it.
  bool _sessionActive = false;
  bool _isSuspicious = false;

  Timer? _heartbeatTimer;
  final HeartbeatMonitor _heartbeatMonitor = HeartbeatMonitor();

  // Replay protection: store used session IDs locally
  static const _kUsedSessions = 'ac_used_sessions';

  // ─── Session lifecycle ───────────────────────────────────────────────────

  /// Call when a new game session begins.
  void beginSession(String userId) {
    _currentSessionId = _generateSessionId();
    _currentUserId = userId;
    _sessionStart = DateTime.now();
    _score = 0;
    _isRunning = true;
    _sessionActive = true;
    _isSuspicious = false;
    _heartbeatMonitor.reset();
    _totalPauseDuration = Duration.zero;
    _lastPauseAt = null;

    _startHeartbeat();
  }

  /// Call when game is paused (by player or backgrounded).
  void pauseSession() {
    if (!_isRunning) return;
    _isRunning = false;
    _lastPauseAt = DateTime.now();
    _heartbeatTimer?.cancel();
  }

  /// Call when game resumes from pause.
  void resumeSession() {
    // No session has actually been started — nothing to resume. Without
    // this guard, any background/foreground toggle (even just checking a
    // notification while sitting on the main menu) would start the
    // qualifier clock running with no game being played.
    if (_currentSessionId == null || !_sessionActive) return;
    if (_isRunning) return;
    if (_lastPauseAt != null) {
      _totalPauseDuration += DateTime.now().difference(_lastPauseAt!);
      _lastPauseAt = null;
    }
    _isRunning = true;
    _startHeartbeat();
  }

  /// Call on game over. Returns a signed token to submit to the server.
  Future<SessionToken?> endSession(int finalScore) async {
    _heartbeatTimer?.cancel();
    _isRunning = false;
    _score = finalScore;

    if (_currentSessionId == null || _currentUserId == null) return null;

    final endedAt = DateTime.now();
    // Snapshot once — activeSeconds is now derived from DateTime.now(), so
    // reading it repeatedly through this method could tick between reads.
    var activeSeconds = this.activeSeconds;
    _sessionActive = false;
    final now = DateTime.now();
    final dayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    // Flag if pattern is suspicious
    if (!_heartbeatMonitor.isPatternLegitimate()) {
      _isSuspicious = true;
    }

    // Validate active time doesn't exceed wall-clock time
    final wallSeconds = endedAt.difference(_sessionStart!).inSeconds -
        _totalPauseDuration.inSeconds;
    if (activeSeconds > wallSeconds + 10) {
      // More active seconds than wall time — impossible, flag it
      _isSuspicious = true;
      activeSeconds = min(activeSeconds, wallSeconds);
    }

    // Check replay attack
    final alreadyUsed = await _isSessionUsed(_currentSessionId!);
    if (alreadyUsed) return null;
    await _markSessionUsed(_currentSessionId!);

    final checksum = _computeChecksum(
      sessionId: _currentSessionId!,
      userId: _currentUserId!,
      activeSeconds: _isSuspicious ? 0 : activeSeconds, // zero out suspicious
      score: _score,
      startedAt: _sessionStart!,
    );

    return SessionToken(
      sessionId: _currentSessionId!,
      userId: _currentUserId!,
      dayKey: dayKey,
      monthKey: monthKey,
      activeSeconds: _isSuspicious ? 0 : activeSeconds,
      score: _score,
      startedAt: _sessionStart!,
      endedAt: endedAt,
      heartbeatTimestamps: _heartbeatMonitor.beats,
      checksum: checksum,
    );
  }

  // ─── Accessors ───────────────────────────────────────────────────────────

  /// Computed from real timestamps rather than an incremented per-tick
  /// counter — a Timer.periodic(seconds:1) doesn't fire at exact 1-second
  /// boundaries under load (competing with the game's render Ticker, GC,
  /// etc.), so a counter that just does activeSeconds++ per callback loses
  /// a little time on every late tick and never catches up — over a full
  /// 5-minute session that drift reached several real seconds. Deriving it
  /// from elapsed wall-clock time minus paused time is immune to that.
  int get activeSeconds {
    if (!_sessionActive || _sessionStart == null) return 0;
    final now = DateTime.now();
    var pauseDuration = _totalPauseDuration;
    if (!_isRunning && _lastPauseAt != null) {
      pauseDuration += now.difference(_lastPauseAt!);
    }
    final active = now.difference(_sessionStart!) - pauseDuration;
    return active.inSeconds.clamp(0, 1 << 30);
  }

  bool get isSuspicious => _isSuspicious;
  bool get isRunning => _isRunning;

  // ─── Private helpers ─────────────────────────────────────────────────────

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // Heartbeat every 30 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isRunning) {
        _heartbeatMonitor.recordBeat();
        // In production: POST to Firebase Cloud Function here
        // _sendHeartbeatToServer(_currentSessionId!, _activeSeconds);
      }
    });
  }

  String _generateSessionId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Simple checksum — in production, replace with HMAC-SHA256 using a
  /// server-side secret key that is never embedded in the client.
  String _computeChecksum({
    required String sessionId,
    required String userId,
    required int activeSeconds,
    required int score,
    required DateTime startedAt,
  }) {
    final payload =
        '$sessionId|$userId|$activeSeconds|$score|${startedAt.millisecondsSinceEpoch}';
    // XOR-fold the UTF-8 bytes as a simple integrity check (not cryptographic).
    // Replace with HMAC in production.
    final bytes = utf8.encode(payload);
    int hash = 0xDEADBEEF;
    for (final b in bytes) {
      hash = ((hash << 5) ^ (hash >> 27) ^ b) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  // ─── Replay protection ───────────────────────────────────────────────────

  Future<bool> _isSessionUsed(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getStringList(_kUsedSessions) ?? [];
    return used.contains(sessionId);
  }

  Future<void> _markSessionUsed(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getStringList(_kUsedSessions) ?? [];
    used.add(sessionId);
    // Keep only last 200 sessions to prevent unbounded growth
    if (used.length > 200) used.removeRange(0, used.length - 200);
    await prefs.setStringList(_kUsedSessions, used);
  }
}
