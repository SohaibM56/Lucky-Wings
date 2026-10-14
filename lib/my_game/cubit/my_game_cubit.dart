import 'package:equatable/equatable.dart';
import 'package:flip_flop/game_manager.dart';
import 'package:flip_flop/utils/utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'my_game_state.dart';

class MyGameCubit extends Cubit<MyGameState> with GameSound {
  MyGameCubit() : super(const MyGameState());

  // Namespaces the best-score list and personal best by uid so each
  // account's own records stay isolated on a shared device.
  String? _uid;
  String _k(String base) => _uid == null ? base : '${_uid}_$base';

  /// Called once AuthCubit resolves to a real uid (sign-in, guest sign-in,
  /// or account linking) so this account's own scores load instead of
  /// whichever account last used the device.
  Future<void> setUser(String uid) async {
    if (_uid == uid) return;
    _uid = uid;
    await _migrateLegacyData();
    await init();
  }

  /// The first time a uid is attached on this device, carry over scores
  /// saved under the old un-scoped keys instead of orphaning them.
  Future<void> _migrateLegacyData() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_k(GameConstant.personalBest))) return;
    final legacyBest = prefs.getInt(GameConstant.personalBest);
    if (legacyBest != null) {
      await prefs.setInt(_k(GameConstant.personalBest), legacyBest);
      await prefs.remove(GameConstant.personalBest); // first account only
    }
    final legacyScores = prefs.getStringList(GameConstant.bestScore);
    if (legacyScores != null) {
      await prefs.setStringList(_k(GameConstant.bestScore), legacyScores);
      await prefs.remove(GameConstant.bestScore);
    }
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> bestScore = (prefs.getStringList(_k(GameConstant.bestScore)) ??
        [
          "0@@@@0",
          "0@@@@0",
          "0@@@@0",
          "0@@@@0",
          "0@@@@0",
          "0@@@@0",
          "0@@@@0",
          "0@@@@0",
          "0@@@@0",
          "0@@@@0",
        ]);
    int personalBest = prefs.getInt(_k(GameConstant.personalBest)) ?? 0;
    emit(state.copyWith(bestScore: bestScore, personalBest: personalBest));
  }

  Future<void> getTurn() async {
    final prefs = await SharedPreferences.getInstance();
    bool isFirstTime = prefs.getBool(GameConstant.isFirstTime) ?? true;
    await prefs.setBool(GameConstant.isFirstTime, false);
    emit(state.copyWith(
        gameState: isFirstTime ? GameState.firstTime : GameState.ready));
  }

  void start() => emit(
      state.copyWith(score: 0, fruit: 0, coin: 0, gameState: GameState.play));

  void updateReward({required RewardType rewardType}) {
    switch (rewardType) {
      case RewardType.score:
        emit(state.copyWith(score: state.score + 1));
        break;
      case RewardType.fruit:
        emit(state.copyWith(fruit: state.fruit + 1));
        break;
      case RewardType.coin:
        emit(state.copyWith(coin: state.coin + 1));
        break;
    }
  }

  Future<void> gameOver({int playSeconds = 0}) async {
    // Record this run in the best-scores list shown on the leaderboard's
    // MY BEST tab. saveScore() used to be dead code (nothing called it), so
    // the list never filled. Must run before the HUD reset below.
    await saveScore('Player', score: state.score, playSeconds: playSeconds);
    int personalBest = state.personalBest;
    if (state.score > personalBest) {
      personalBest = state.score;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_k(GameConstant.personalBest), personalBest);
    }
    emit(state.copyWith(
      gameState: GameState.gameOver,
      bestScore: state.bestScore,
      personalBest: personalBest,
    ));
    // Reset the AppBar HUD now, rather than waiting for the next "Try Again"
    // tap — the game-over dialog already captured the real final numbers via
    // its own listener above, and callers needing them (raffle/coin credit)
    // must read cubit state before calling gameOver(), not after.
    emit(state.copyWith(score: 0, fruit: 0, coin: 0));
  }

  /// Entries are "name@@@@score" or, once a run's play time is known,
  /// "name@@@@score@@@@seconds" (older entries simply have no time).
  Future<void> saveScore(String username,
      {int? score, int playSeconds = 0}) async {
    final runScore = score ?? state.score;
    if (runScore <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    state.bestScore.sort((a, b) {
      int aT = int.parse(a.split("@@@@")[1]);
      int bT = int.parse(b.split("@@@@")[1]);
      if (aT < bT) {
        return -1;
      } else if (aT > bT) {
        return 1;
      } else {
        return 0;
      }
    });
    for (int i = 0; i < state.bestScore.length; i++) {
      int best = int.parse(state.bestScore[i].split("@@@@")[1]);
      if (runScore > best) {
        state.bestScore[i] = playSeconds > 0
            ? '$username@@@@$runScore@@@@$playSeconds'
            : '$username@@@@$runScore';
        await prefs.setStringList(_k(GameConstant.bestScore),
            state.bestScore.map((i) => i.toString()).toList());
        // New list instance so listeners (the MY BEST tab) rebuild.
        emit(state.copyWith(bestScore: List<String>.of(state.bestScore)));
        break;
      }
    }
  }

  void playButtonSound() => playSound(path: 'select');
}
