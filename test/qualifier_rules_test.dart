import 'package:flip_flop/backend/backend_models.dart';
import 'package:flip_flop/raffle/qualifier_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const day = '2026-10-11';
  final now = DateTime(2026, 10, 11); // days 1..10 are in the past

  MonthlyRecord fresh() => const MonthlyRecord(userId: 'u', monthKey: '2026-10');

  MonthlyRecord play(MonthlyRecord r, int seconds) =>
      applySessionToRecord(r,
              dayKey: day, activeSeconds: seconds, score: 0, now: now)
          .record;

  test('first 5 minutes qualifies today, no catch-up', () {
    final out = applySessionToRecord(fresh(),
        dayKey: day, activeSeconds: 300, score: 0, now: now);
    expect(out.record.qualifiedDays, [day]);
    expect(out.record.catchupDays, isEmpty);
    expect(out.earnedEntry, isTrue);
    expect(out.catchupApplied, isFalse);
  });

  test('short games after qualifying earn nothing', () {
    var r = play(fresh(), 300);
    for (var i = 0; i < 6; i++) {
      final out = applySessionToRecord(r,
          dayKey: day, activeSeconds: 3, score: 0, now: now);
      expect(out.earnedEntry, isFalse);
      r = out.record;
    }
    expect(r.catchupDays, isEmpty);
  });

  test('each further 5 minutes earns the next missed day, oldest first', () {
    var r = play(fresh(), 300);
    r = play(r, 300);
    expect(r.catchupDays, ['2026-10-01']);
    r = play(r, 300);
    expect(r.catchupDays, ['2026-10-01', '2026-10-02']);
  });

  test('time adds up across games and crossing the mark mid-game counts', () {
    var r = play(fresh(), 100);
    r = play(r, 150);
    expect(r.qualifiedDays, isEmpty);
    r = play(r, 100);
    expect(r.qualifiedDays, [day]);
    expect(r.catchupDays, isEmpty);
  });

  test('one long game crossing two marks = today + one catch-up', () {
    final r = play(fresh(), 650);
    expect(r.qualifiedDays, [day]);
    expect(r.catchupDays, ['2026-10-01']);
  });

  test('already-caught-up days are skipped', () {
    var r = MonthlyRecord(
      userId: 'u',
      monthKey: '2026-10',
      qualifiedDays: const [day],
      catchupDays: const ['2026-10-01', '2026-10-02'],
      dailyActiveSeconds: const {day: 300},
    );
    r = play(r, 300);
    expect(r.catchupDays.last, '2026-10-03');
  });

  test('no missed days left: still qualifies, no crash', () {
    final r = applySessionToRecord(fresh(),
            dayKey: '2026-10-01',
            activeSeconds: 600,
            score: 0,
            now: DateTime(2026, 10, 1))
        .record;
    expect(r.qualifiedDays, ['2026-10-01']);
    expect(r.catchupDays, isEmpty);
  });

  test('best score and totals update', () {
    final r = applySessionToRecord(fresh(),
            dayKey: day, activeSeconds: 40, score: 7, now: now)
        .record;
    expect(r.bestScore, 7);
    expect(r.totalSessions, 1);
    expect(r.totalPlaySeconds, 40);
    expect(r.dailyActiveSeconds[day], 40);
  });
}
