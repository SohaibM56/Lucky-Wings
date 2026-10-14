import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../backend/backend_service.dart';
import '../auth/auth_cubit.dart';
import '../my_game/my_game.dart';
import '../ads/ads.dart';

// ─── State ────────────────────────────────────────────────────────────────────

enum LeaderboardStatus { initial, loading, loaded, error }

class LeaderboardState extends Equatable {
  const LeaderboardState({
    this.status = LeaderboardStatus.initial,
    this.entries = const [],
    this.currentUserRank = -1,
    this.ownRank,
    this.monthKey = '',
    this.prize = '',
  });

  final LeaderboardStatus status;
  final List<LeaderboardEntry> entries;
  final int currentUserRank;  // index into entries, -1 if not in the fetched window
  // Set only when the user has a record this month but didn't show up in
  // entries (i.e. outside the fetched top-N) — computed via a separate
  // query rather than relying on currentUserRank/entries.
  final LeaderboardOwnRank? ownRank;
  final String monthKey;
  final String prize;

  @override
  List<Object?> get props =>
      [status, entries, currentUserRank, ownRank, monthKey, prize];

  LeaderboardState copyWith({
    LeaderboardStatus? status,
    List<LeaderboardEntry>? entries,
    int? currentUserRank,
    LeaderboardOwnRank? ownRank,
    bool clearOwnRank = false,
    String? monthKey,
    String? prize,
  }) {
    return LeaderboardState(
      status: status ?? this.status,
      entries: entries ?? this.entries,
      currentUserRank: currentUserRank ?? this.currentUserRank,
      ownRank: clearOwnRank ? null : (ownRank ?? this.ownRank),
      monthKey: monthKey ?? this.monthKey,
      prize: prize ?? this.prize,
    );
  }
}

// ─── Cubit ────────────────────────────────────────────────────────────────────

class LeaderboardCubit extends Cubit<LeaderboardState> {
  LeaderboardCubit() : super(const LeaderboardState());

  final _backend = BackendService.instance;

  Future<void> load(String? currentUserId) async {
    emit(state.copyWith(status: LeaderboardStatus.loading));
    try {
      final now = DateTime.now();
      final monthKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final entries = await _backend.getLeaderboard(monthKey, limit: 50);
      final prize   = await _backend.getCurrentPrize(monthKey);

      // Sort by best score descending
      final sorted = List<LeaderboardEntry>.from(entries)
        ..sort((a, b) => b.bestScore.compareTo(a.bestScore));

      int rank = -1;
      if (currentUserId != null) {
        rank = sorted.indexWhere((e) => e.userId == currentUserId);
      }

      // Not in the fetched window (e.g. ranked 51st+) — look up their rank
      // separately instead of silently showing nothing. A user with no
      // record yet this month correctly gets no pin (getOwnRank -> null).
      // Caught separately from the rest of load(): this query needs its own
      // Firestore composite index (monthKey ==, bestScore >) which may not
      // exist yet in every environment — if it's missing or the call
      // otherwise fails, the leaderboard itself should still render rather
      // than the whole screen falling back to the error state.
      LeaderboardOwnRank? ownRank;
      if (currentUserId != null && rank == -1) {
        try {
          ownRank = await _backend.getOwnRank(currentUserId, monthKey);
        } catch (_) {
          ownRank = null;
        }
      }

      emit(state.copyWith(
        status: LeaderboardStatus.loaded,
        entries: sorted,
        currentUserRank: rank,
        ownRank: ownRank,
        clearOwnRank: ownRank == null,
        monthKey: monthKey,
        prize: prize,
      ));
    } catch (e) {
      emit(state.copyWith(status: LeaderboardStatus.error));
    }
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class LeaderboardPage extends StatefulWidget {
  static const routeName = 'app/leaderboard';
  const LeaderboardPage({Key? key}) : super(key: key);

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  @override
  void initState() {
    super.initState();
    final userId = context.read<AuthCubit>().state.user?.uid;
    context.read<LeaderboardCubit>().load(userId);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.black38,
        elevation: 0,
        bottom: const TabBar(
          indicatorColor: Color(0xFFF5A623),
          labelColor: Color(0xFFF5A623),
          unselectedLabelColor: Colors.white54,
          labelStyle: TextStyle(fontFamily: 'DiloWorld', fontSize: 13),
          tabs: [Tab(text: 'THIS MONTH'), Tab(text: 'MY BEST')],
        ),
        title: const Text('LEADERBOARD',
            style: TextStyle(
                fontFamily: 'DiloWorld',
                fontSize: 18,
                color: Color(0xFFF5A623),
                fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: TabBarView(children: [
        _buildMonthly(),
        const _MyBestScores(),
      ]),
      ),
    );
  }

  Widget _buildMonthly() {
    return BlocBuilder<LeaderboardCubit, LeaderboardState>(
        builder: (context, state) {
          if (state.status == LeaderboardStatus.loading) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFF5A623)));
          }
          if (state.status == LeaderboardStatus.error) {
            return Center(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, color: Colors.white24, size: 48),
                const SizedBox(height: 12),
                const Text('Could not load leaderboard',
                    style: TextStyle(color: Colors.white38, fontFamily: 'DiloWorld')),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.read<LeaderboardCubit>()
                      .load(context.read<AuthCubit>().state.user?.uid),
                  child: const Text('Retry',
                      style: TextStyle(color: Color(0xFFF5A623))),
                ),
              ],
            ));
          }

          final entries = state.entries;
          final currentUid = context.read<AuthCubit>().state.user?.uid;

          return RefreshIndicator(
            color: const Color(0xFFF5A623),
            onRefresh: () =>
                context.read<LeaderboardCubit>().load(currentUid),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _PrizeHeader(prize: state.prize),
                ),
                if (entries.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Text('No scores yet this month.\nBe the first!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white38, fontFamily: 'DiloWorld')),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        // A native ad after every N rows (see AdConfig); the
                        // widget collapses to nothing if no ad is available.
                        const every = AdConfig.nativeEveryNRows;
                        if ((i + 1) % (every + 1) == 0) {
                          return const NativeAdWidget();
                        }
                        final row = i - (i ~/ (every + 1));
                        final entry = entries[row];
                        final isYou = entry.userId == currentUid;
                        return _LeaderboardRow(
                          rank: row + 1,
                          entry: entry,
                          isYou: isYou,
                        );
                      },
                      childCount: entries.length +
                          entries.length ~/ AdConfig.nativeEveryNRows,
                    ),
                  ),
                // Short list: no in-list slot is reached, so show one ad
                // below it instead.
                if (entries.isNotEmpty &&
                    entries.length < AdConfig.nativeEveryNRows)
                  const SliverToBoxAdapter(child: NativeAdWidget()),

                // Shown when the user has a record this month but didn't
                // appear in the fetched top-N (e.g. ranked 51st+) — see
                // LeaderboardCubit.load's getOwnRank call.
                if (state.ownRank != null)
                  SliverToBoxAdapter(
                    child: _YourRankPin(
                        rank: state.ownRank!.rank,
                        entry: state.ownRank!.entry),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
    );
  }
}

/// The player's own best runs, kept on the device (MyGameCubit). Moved here
/// from the old main-menu "Leaderboard" dialog, which showed the same list
/// under a title that suggested a global ranking.
class _MyBestScores extends StatelessWidget {
  const _MyBestScores();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyGameCubit, MyGameState>(
      builder: (context, state) {
        // Entries are "name@@@@score" or "name@@@@score@@@@seconds".
        final runs = state.bestScore
            .map((e) => e.split('@@@@'))
            .where((p) => p.length >= 2 && (int.tryParse(p[1]) ?? 0) > 0)
            .map((p) => (
                  score: int.parse(p[1]),
                  seconds: p.length >= 3 ? int.tryParse(p[2]) : null,
                ))
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));
        final scores = runs.map((r) => r.score).toList();
        String timeLabel(int? s) => s == null
            ? '--'
            : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
        if (scores.isEmpty) {
          return const Center(
            child: Text('No scores yet.\nPlay a game to set your first one!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontFamily: 'DiloWorld')),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: scores.length,
          itemBuilder: (context, i) {
            final rank = i + 1;
            final emoji =
                rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : null;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(rank == 1 ? 0.08 : 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: rank == 1
                      ? const Color(0xFFF5A623).withOpacity(0.4)
                      : Colors.white.withOpacity(0.06),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(emoji ?? '#$rank',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: 'DiloWorld',
                            fontSize: emoji != null ? 20 : 14,
                            color: Colors.white38)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text('${scores[i]}',
                        style: TextStyle(
                            fontFamily: 'DiloWorld',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: rank == 1
                                ? const Color(0xFFF5A623)
                                : Colors.white)),
                  ),
                  const Text('points',
                      style: TextStyle(
                          fontFamily: 'DiloWorld',
                          fontSize: 12,
                          color: Colors.white38)),
                  const SizedBox(width: 14),
                  const Icon(Icons.timer_outlined,
                      size: 14, color: Colors.white38),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 38,
                    child: Text(timeLabel(runs[i].seconds),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontFamily: 'DiloWorld',
                            fontSize: 13,
                            color: Colors.white70)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PrizeHeader extends StatelessWidget {
  final String prize;
  const _PrizeHeader({required this.prize});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final drawMonth = now.month == 12
        ? 'January'
        : _monthName(now.month + 1);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF5A623).withOpacity(0.15),
            const Color(0xFFFF4D6D).withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFF5A623).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🏆  THIS MONTH\'S PRIZE',
              style: TextStyle(
                  fontFamily: 'DiloWorld',
                  fontSize: 11,
                  color: Colors.white38,
                  letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text(prize,
              style: const TextStyle(
                  fontFamily: 'DiloWorld',
                  fontSize: 18,
                  color: Color(0xFFF5A623),
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Draw: $drawMonth 1  •  More entries = better odds',
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white38,
                  fontFamily: 'DiloWorld')),
        ],
      ),
    );
  }

  String _monthName(int m) {
    const names = ['','January','February','March','April','May','June',
        'July','August','September','October','November','December'];
    return names[m.clamp(1, 12)];
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final bool isYou;
  const _LeaderboardRow(
      {required this.rank, required this.entry, required this.isYou});

  @override
  Widget build(BuildContext context) {
    final rankEmoji =
        rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : null;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isYou
            ? const Color(0xFFF5A623).withOpacity(0.08)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isYou
              ? const Color(0xFFF5A623).withOpacity(0.4)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: rankEmoji != null
                ? Text(rankEmoji,
                    style: const TextStyle(fontSize: 20),
                    textAlign: TextAlign.center)
                : Text('#$rank',
                    style: const TextStyle(
                        fontFamily: 'DiloWorld',
                        fontSize: 14,
                        color: Colors.white38),
                    textAlign: TextAlign.center),
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isYou
                  ? const Color(0xFFF5A623).withOpacity(0.2)
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(child: Text('🐦', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(entry.username,
                      style: TextStyle(
                          fontFamily: 'DiloWorld',
                          fontSize: 14,
                          color: isYou
                              ? const Color(0xFFF5A623)
                              : Colors.white,
                          fontWeight: FontWeight.bold)),
                  if (isYou) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFFF5A623).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('YOU',
                          style: TextStyle(
                              fontSize: 9,
                              color: Color(0xFFF5A623),
                              fontFamily: 'DiloWorld',
                              fontWeight: FontWeight.bold)),
                    ),
                  ]
                ]),
                Text('${entry.totalEntries} raffle entries',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                        fontFamily: 'DiloWorld')),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${entry.bestScore}',
                  style: const TextStyle(
                      fontFamily: 'DiloWorld',
                      fontSize: 18,
                      color: Color(0xFFF5A623),
                      fontWeight: FontWeight.bold)),
              const Text('best score',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white38,
                      fontFamily: 'DiloWorld')),
            ],
          ),
        ],
      ),
    );
  }
}

class _YourRankPin extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  const _YourRankPin({required this.rank, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(children: [
        const Icon(Icons.more_vert, color: Colors.white24, size: 16),
        const SizedBox(width: 8),
        Text('Your rank: #$rank',
            style: const TextStyle(
                color: Color(0xFFF5A623),
                fontFamily: 'DiloWorld',
                fontSize: 13)),
        const Spacer(),
        Text('Score: ${entry.bestScore}',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }
}
