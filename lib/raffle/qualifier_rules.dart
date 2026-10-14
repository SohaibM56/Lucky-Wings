import '../backend/backend_models.dart';

/// Active play needed for one raffle entry.
const qualifierSeconds = 300;

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Days of the current month before [now] that have no entry yet, oldest first.
List<String> missedDaysFor(MonthlyRecord record, DateTime now) {
  final earned = {...record.qualifiedDays, ...record.catchupDays};
  return [
    for (var d = 1; d < now.day; d++)
      if (!earned.contains(_dayKey(DateTime(now.year, now.month, d))))
        _dayKey(DateTime(now.year, now.month, d)),
  ];
}

/// Banks [activeSeconds] onto [dayKey]'s running total and grants entries.
///
/// Every full [qualifierSeconds] of play that day is worth one entry: the
/// first block qualifies the day itself, each further block earns the oldest
/// missed day. Entries are decided by how many 5-minute marks this session
/// crosses, so a short game after qualifying earns nothing.
({MonthlyRecord record, bool earnedEntry, bool catchupApplied})
    applySessionToRecord(
  MonthlyRecord record, {
  required String dayKey,
  required int activeSeconds,
  required int score,
  required DateTime now,
}) {
  final bankedBefore = record.dailyActiveSeconds[dayKey] ?? 0;
  final todayTotal = bankedBefore + activeSeconds;
  var blocks =
      todayTotal ~/ qualifierSeconds - bankedBefore ~/ qualifierSeconds;

  var qualifiedDays = record.qualifiedDays;
  var catchupDays = record.catchupDays;
  var earnedEntry = false;
  var catchupApplied = false;

  // Also covers a day that already has 5+ minutes banked but was never
  // marked qualified (older data), instead of waiting for the next block.
  if (todayTotal >= qualifierSeconds && !qualifiedDays.contains(dayKey)) {
    qualifiedDays = [...qualifiedDays, dayKey];
    earnedEntry = true;
    if (blocks > 0) blocks--;
  }

  if (blocks > 0) {
    final missed = missedDaysFor(record, now);
    for (var i = 0; i < blocks && i < missed.length; i++) {
      catchupDays = [...catchupDays, missed[i]];
      earnedEntry = true;
      catchupApplied = true;
    }
  }

  final updated = MonthlyRecord(
    userId: record.userId,
    monthKey: record.monthKey,
    qualifiedDays: qualifiedDays,
    catchupDays: catchupDays,
    bestScore: score > record.bestScore ? score : record.bestScore,
    totalSessions: record.totalSessions + 1,
    totalPlaySeconds: record.totalPlaySeconds + activeSeconds,
    dailyActiveSeconds: {...record.dailyActiveSeconds, dayKey: todayTotal},
  );

  return (
    record: updated,
    earnedEntry: earnedEntry,
    catchupApplied: catchupApplied,
  );
}
