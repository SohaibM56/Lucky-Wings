part of 'my_game_cubit.dart';

class MyGameState extends Equatable {
  const MyGameState({
    this.score = 0,
    this.bestScore = const [],
    this.personalBest = 0,
    this.coin = 0,
    this.fruit = 0,
    this.gameState = GameState.ready,
  });

  final int score;
  final List<String> bestScore;
  final int personalBest;
  final int coin;
  final int fruit;
  final GameState gameState;

  @override
  List<Object?> get props => [
        score,
        bestScore,
        personalBest,
        coin,
        fruit,
        gameState,
      ];

  MyGameState copyWith({
    int? score,
    List<String>? bestScore,
    int? personalBest,
    int? coin,
    int? fruit,
    GameState? gameState,
  }) {
    return MyGameState(
      score: score ?? this.score,
      bestScore: bestScore ?? this.bestScore,
      personalBest: personalBest ?? this.personalBest,
      coin: coin ?? this.coin,
      fruit: fruit ?? this.fruit,
      gameState: gameState ?? this.gameState,
    );
  }

  int get best {
    if (this.bestScore.isEmpty) return 0;
    int bestTemp = int.parse(bestScore[0].split("@@@@")[1]);
    for (final item in bestScore) {
      int best = int.parse(item.split("@@@@")[1]);
      if (bestTemp < best) bestTemp = best;
    }
    return bestTemp;
  }
}
