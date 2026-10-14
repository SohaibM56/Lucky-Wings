part of 'raffle_cubit.dart';

class RaffleState extends Equatable {
  const RaffleState({
    this.todayActiveSeconds = 0,
    this.todayQualified = false,
    this.totalEntries = 0,
    this.maxEntries = 30,
    this.daysLeftInMonth = 0,
    this.missedDays = const [],
    this.qualifiedDays = const [],
    this.catchupDays = const [],
    this.bestScore = 0,
    this.totalSessions = 0,
    this.justEarnedEntry = false,
    this.lastEntryWasCatchup = false,
    this.pendingWin,
  });

  final int todayActiveSeconds;
  final bool todayQualified;
  final int totalEntries;
  final int maxEntries;
  final int daysLeftInMonth;
  final List<String> missedDays;
  final List<String> qualifiedDays;
  final List<String> catchupDays;
  final int bestScore;
  final int totalSessions;
  final bool justEarnedEntry;
  final bool lastEntryWasCatchup;
  final Map<String, dynamic>? pendingWin;

  double get qualifierProgress => (todayActiveSeconds / 300.0).clamp(0.0, 1.0);

  int get secondsRemaining =>
      todayQualified ? 0 : (300 - todayActiveSeconds).clamp(0, 300);

  String get timeRemainingLabel => _clock(secondsRemaining);

  bool get catchingUp => todayQualified && missedDays.isNotEmpty;

  // Once today is qualified, every further 5 minutes fills one missed day.
  int get catchupSecondsRemaining => 300 - todayActiveSeconds % 300;

  double get catchupProgress => (todayActiveSeconds % 300) / 300.0;

  String get catchupRemainingLabel => _clock(catchupSecondsRemaining);

  String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  List<Object?> get props => [
        todayActiveSeconds,
        todayQualified,
        totalEntries,
        maxEntries,
        daysLeftInMonth,
        missedDays,
        qualifiedDays,
        catchupDays,
        bestScore,
        totalSessions,
        justEarnedEntry,
        lastEntryWasCatchup,
        pendingWin,
      ];

  RaffleState copyWith({
    int? todayActiveSeconds,
    bool? todayQualified,
    int? totalEntries,
    int? maxEntries,
    int? daysLeftInMonth,
    List<String>? missedDays,
    List<String>? qualifiedDays,
    List<String>? catchupDays,
    int? bestScore,
    int? totalSessions,
    bool? justEarnedEntry,
    bool? lastEntryWasCatchup,
    Map<String, dynamic>? pendingWin,
    bool clearPendingWin = false,
  }) {
    return RaffleState(
      todayActiveSeconds: todayActiveSeconds ?? this.todayActiveSeconds,
      todayQualified: todayQualified ?? this.todayQualified,
      totalEntries: totalEntries ?? this.totalEntries,
      maxEntries: maxEntries ?? this.maxEntries,
      daysLeftInMonth: daysLeftInMonth ?? this.daysLeftInMonth,
      missedDays: missedDays ?? this.missedDays,
      qualifiedDays: qualifiedDays ?? this.qualifiedDays,
      catchupDays: catchupDays ?? this.catchupDays,
      bestScore: bestScore ?? this.bestScore,
      totalSessions: totalSessions ?? this.totalSessions,
      justEarnedEntry: justEarnedEntry ?? this.justEarnedEntry,
      lastEntryWasCatchup: lastEntryWasCatchup ?? this.lastEntryWasCatchup,
      pendingWin: clearPendingWin ? null : (pendingWin ?? this.pendingWin),
    );
  }
}
