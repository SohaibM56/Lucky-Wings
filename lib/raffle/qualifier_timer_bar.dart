import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../raffle/raffle_cubit.dart';

/// A slim progress bar + label shown in the game AppBar area.
/// Shows how far the player is toward the 5-minute daily qualifier.
class QualifierTimerBar extends StatelessWidget {
  const QualifierTimerBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RaffleCubit, RaffleState>(
      buildWhen: (p, c) =>
          p.todayActiveSeconds != c.todayActiveSeconds ||
          p.todayQualified != c.todayQualified ||
          p.missedDays.length != c.missedDays.length,
      builder: (context, state) {
        if (state.catchingUp) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TimerProgress(
                label: '${state.catchupRemainingLabel} to catch up',
                progress: state.catchupProgress,
              ),
              _QualifiedBadge(),
            ],
          );
        }
        if (state.todayQualified) {
          return _QualifiedBadge();
        }
        return _TimerProgress(
          label: '${state.timeRemainingLabel} to qualify',
          progress: state.qualifierProgress,
        );
      },
    );
  }
}

class _TimerProgress extends StatelessWidget {
  const _TimerProgress({required this.label, required this.progress});
  final String label;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontFamily: 'DiloWorld',
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 130,
          height: 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 0.66
                    ? const Color(0xFF4ECB71)
                    : progress > 0.33
                        ? const Color(0xFFF5A623)
                        : const Color(0xFF00D4FF),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QualifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF4ECB71).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4ECB71), width: 1),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 13, color: Color(0xFF4ECB71)),
          SizedBox(width: 4),
          Text(
            'Entry Earned Today!',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF4ECB71),
              fontFamily: 'DiloWorld',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen overlay shown briefly when the player just qualifies.
class QualifiedCelebration extends StatelessWidget {
  final VoidCallback onDismiss;
  const QualifiedCelebration({Key? key, required this.onDismiss})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF4ECB71), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text(
                  'RAFFLE ENTRY EARNED!',
                  style: TextStyle(
                    fontFamily: 'DiloWorld',
                    fontSize: 20,
                    color: Color(0xFF4ECB71),
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Keep playing — all your scores\nstill count on the leaderboard!',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    fontFamily: 'DiloWorld',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECB71),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                  ),
                  onPressed: onDismiss,
                  child: const Text(
                    'KEEP PLAYING',
                    style: TextStyle(
                        fontFamily: 'DiloWorld',
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
