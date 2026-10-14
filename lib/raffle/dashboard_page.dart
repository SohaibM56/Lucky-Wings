import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../raffle/raffle_cubit.dart';
import '../widgets/custom_dialog.dart';

class DashboardPage extends StatefulWidget {
  static const routeName = 'app/dashboard';

  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _winDialogOpen = false;

  @override
  void initState() {
    super.initState();
    // The listener below only fires on a null -> win change. A win that was
    // already loaded at app start (checkPendingWin runs on sign-in, before
    // this page exists) never triggers it, so also check once init() is done.
    context.read<RaffleCubit>().init().then((_) {
      if (!mounted) return;
      final win = context.read<RaffleCubit>().state.pendingWin;
      if (win != null) _showWinDialog(context, win);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RaffleCubit, RaffleState>(
      listenWhen: (p, c) => p.pendingWin == null && c.pendingWin != null,
      listener: (context, state) => _showWinDialog(context, state.pendingWin!),
      child: _buildScaffold(context),
    );
  }

  void _showWinDialog(BuildContext context, Map<String, dynamic> win) {
    if (_winDialogOpen) return;
    _winDialogOpen = true;
    final prizeName = win['prizeName'] as String? ?? 'a prize';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => CustomDialog(
        // No close arrow (it also hides the title ribbon); the only way out
        // is CLAIM PRIZE. Sized to the content, like SuccessDialog, so the
        // body is centered instead of leaving a dead gap above the button.
        showCloseButton: false,
        width: MediaQuery.of(context).size.width / 1.5,
        height: MediaQuery.of(context).size.height / 2.6,
        bodyMargin: 40,
        bodyMarginBottom: 90,
        actionButtonFontSize: 16,
        showTitle: true,
        title: 'YOU WON!',
        showPrimaryButton: true,
        primaryText: 'CLAIM PRIZE',
        bodyWidget: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                'Congratulations! You won:\n$prizeName',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'DiloWorld',
                  fontSize: 15,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        primaryButtonPressed: () {
          context.read<RaffleCubit>().claimWin();
          Navigator.pop(dialogContext);
        },
      ),
    ).then((_) => _winDialogOpen = false);
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.black38,
        elevation: 0,
        title: const Text(
          'LUCKY WINGS',
          style: TextStyle(
            fontFamily: 'DiloWorld',
            fontSize: 18,
            color: Color(0xFFF5A623),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.sports_esports, color: Color(0xFFF5A623)),
            label: const Text('PLAY',
                style: TextStyle(
                    color: Color(0xFFF5A623),
                    fontFamily: 'DiloWorld',
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: BlocBuilder<RaffleCubit, RaffleState>(
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: () => context.read<RaffleCubit>().init(),
            color: const Color(0xFFF5A623),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NudgeBanner(state: state),
                  const SizedBox(height: 12),
                  _RaffleHeroCard(state: state),
                  const SizedBox(height: 20),
                  _sectionTitle(
                      '${_monthName(DateTime.now().month).toUpperCase()} ${DateTime.now().year} CALENDAR'),
                  const SizedBox(height: 10),
                  _CalendarGrid(state: state),
                  const SizedBox(height: 8),
                  _Legend(),
                  const SizedBox(height: 20),
                  if (state.missedDays.isNotEmpty) ...[
                    _CatchupCard(
                        missedCount: state.missedDays.length,
                        progress:
                            state.catchingUp ? state.catchupProgress : null),
                    const SizedBox(height: 20),
                  ],
                  _sectionTitle('YOUR STATS'),
                  const SizedBox(height: 10),
                  _StatsGrid(state: state),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'DiloWorld',
        fontSize: 11,
        color: Colors.white38,
        letterSpacing: 1.2,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

// ─── Nudge Banner ─────────────────────────────────────────────────────────────

class _NudgeBanner extends StatelessWidget {
  final RaffleState state;
  const _NudgeBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final missed = state.missedDays.length;
    final daysLeft = state.daysLeftInMonth;
    if (missed == 0 || daysLeft > 7) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4D6D).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF4D6D).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active,
              color: Color(0xFFFF4D6D), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$daysLeft days left — you have $missed catch-up ${missed == 1 ? 'day' : 'days'} available. Play now!',
              style: const TextStyle(
                fontFamily: 'DiloWorld',
                fontSize: 13,
                color: Color(0xFFFF4D6D),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D6D),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('PLAY',
                  style: TextStyle(
                      fontFamily: 'DiloWorld',
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Raffle Hero Card ─────────────────────────────────────────────────────────

class _RaffleHeroCard extends StatelessWidget {
  final RaffleState state;
  const _RaffleHeroCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final drawMonth = now.month == 12 ? 'January' : _monthName(now.month + 1);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF5A623).withOpacity(0.15),
            const Color(0xFFFF4D6D).withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF5A623).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${state.totalEntries}',
                style: const TextStyle(
                  fontFamily: 'DiloWorld',
                  fontSize: 52,
                  color: Color(0xFFF5A623),
                  height: 1,
                ),
              ),
              const Text(
                'RAFFLE ENTRIES',
                style: TextStyle(
                    fontFamily: 'DiloWorld',
                    fontSize: 11,
                    color: Colors.white54,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Max ${state.maxEntries} this month',
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white38,
                    fontFamily: 'DiloWorld'),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Days left in month',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white38,
                      fontFamily: 'DiloWorld')),
              Text(
                '${state.daysLeftInMonth}',
                style: const TextStyle(
                    fontFamily: 'DiloWorld',
                    fontSize: 28,
                    color: Color(0xFFFF4D6D),
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '🎁 Draw: $drawMonth 1',
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                    fontFamily: 'DiloWorld'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _monthName(int m) {
  const names = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  return names[m.clamp(1, 12)];
}

// ─── Calendar Grid ────────────────────────────────────────────────────────────

class _CalendarGrid extends StatelessWidget {
  final RaffleState state;
  const _CalendarGrid({required this.state});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final qualified = {...state.qualifiedDays};
    final caughtUp = {...state.catchupDays};

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: daysInMonth,
      itemBuilder: (context, i) {
        final day = i + 1;
        final key =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
        final isToday = day == now.day;
        final isPast = day < now.day;
        final isFuture = day > now.day;
        final isDone = qualified.contains(key) || caughtUp.contains(key);
        final isMissed = isPast && !isDone;

        Color bg;
        Color border;
        Widget inner;

        if (isFuture) {
          bg = Colors.white.withOpacity(0.04);
          border = Colors.transparent;
          inner = Text('$day',
              style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white24,
                  fontFamily: 'DiloWorld'));
        } else if (isDone) {
          bg = const Color(0xFF4ECB71).withOpacity(0.18);
          border = const Color(0xFF4ECB71).withOpacity(0.5);
          inner =
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$day',
                style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF4ECB71),
                    fontFamily: 'DiloWorld')),
            const Text('✓',
                style: TextStyle(fontSize: 11, color: Color(0xFF4ECB71))),
          ]);
        } else if (isMissed) {
          final filling = state.catchingUp && state.missedDays.first == key;
          bg = const Color(0xFFFF4D6D).withOpacity(0.08);
          border = filling
              ? const Color(0xFF00D4FF)
              : const Color(0xFFFF4D6D).withOpacity(0.25);
          inner =
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$day',
                style: TextStyle(
                    fontSize: 9,
                    color: filling ? const Color(0xFF00D4FF) : Colors.white38,
                    fontFamily: 'DiloWorld')),
            filling
                ? Text('${(state.catchupProgress * 100).round()}%',
                    style:
                        const TextStyle(fontSize: 8, color: Color(0xFF00D4FF)))
                : const Text('↺',
                    style: TextStyle(fontSize: 11, color: Color(0xFF00D4FF))),
          ]);
        } else {
          // today
          bg = const Color(0xFFF5A623).withOpacity(0.12);
          border = const Color(0xFFF5A623);
          final pct = (state.qualifierProgress * 100).round();
          inner =
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$day',
                style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFFF5A623),
                    fontFamily: 'DiloWorld')),
            Text('$pct%',
                style: const TextStyle(fontSize: 8, color: Color(0xFFF5A623))),
          ]);
        }

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: isToday && !isDone ? const Color(0xFFF5A623) : border,
                width: isToday ? 1.5 : 1),
          ),
          child: Center(child: inner),
        );
      },
    );
  }
}

// ─── Legend ───────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: const [
        _LegendItem(color: Color(0xFF4ECB71), label: 'Qualified'),
        _LegendItem(color: Color(0xFFFF4D6D), label: 'Missed'),
        _LegendItem(color: Color(0xFF00D4FF), label: 'Catch-up'),
        _LegendItem(color: Color(0xFFF5A623), label: 'Today'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 5),
      Text(label,
          style: const TextStyle(
              fontSize: 11, color: Colors.white38, fontFamily: 'DiloWorld')),
    ]);
  }
}

// ─── Catch-Up Card ────────────────────────────────────────────────────────────

class _CatchupCard extends StatelessWidget {
  final int missedCount;
  final double? progress;
  const _CatchupCard({required this.missedCount, this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF00D4FF).withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, color: Color(0xFF00D4FF), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Catch Up Previous Days',
                    style: TextStyle(
                        fontFamily: 'DiloWorld',
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
                Text(
                    '$missedCount ${missedCount == 1 ? 'day' : 'days'} missed · each extra 5 mins fills one',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                        fontFamily: 'DiloWorld')),
                if (progress != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF00D4FF)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5A623),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('PLAY →',
                  style: TextStyle(
                      fontFamily: 'DiloWorld',
                      fontSize: 11,
                      color: Colors.black,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats Grid ───────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final RaffleState state;
  const _StatsGrid({required this.state});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _StatCard(
            value: '${state.qualifiedDays.length}',
            label: 'Days Qualified',
            color: const Color(0xFF4ECB71)),
        _StatCard(
            value: '${state.catchupDays.length}',
            label: 'Catch-up Days',
            color: const Color(0xFF00D4FF)),
        _StatCard(
            value: '${state.missedDays.length}',
            label: 'Missed Days',
            color: const Color(0xFFFF4D6D)),
        _StatCard(
            value: '${state.totalEntries}/${state.maxEntries}',
            label: 'Total Entries',
            color: const Color(0xFFF5A623)),
        _StatCard(
            value: '${state.bestScore}',
            label: 'Best Score',
            color: Colors.white),
        _StatCard(
            value: '${state.totalSessions}',
            label: 'Games Played',
            color: Colors.white),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatCard(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: TextStyle(
                  fontFamily: 'DiloWorld',
                  fontSize: 22,
                  color: color,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white38,
                  fontFamily: 'DiloWorld')),
        ],
      ),
    );
  }
}
