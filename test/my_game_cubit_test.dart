import 'package:flip_flop/game_manager.dart';
import 'package:flip_flop/my_game/cubit/my_game_cubit.dart';
import 'package:flip_flop/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<MyGameCubit> newCubit() async {
    SharedPreferences.setMockInitialValues({});
    final cubit = MyGameCubit();
    await cubit.setUser('u1');
    return cubit;
  }

  Future<void> playRun(MyGameCubit c, int score, {int seconds = 0}) async {
    c.start();
    for (var i = 0; i < score; i++) {
      c.updateReward(rewardType: RewardType.score);
    }
    await c.gameOver(playSeconds: seconds);
  }

  List<int> scores(MyGameCubit c) => c.state.bestScore
      .map((e) => int.parse(e.split('@@@@')[1]))
      .where((s) => s > 0)
      .toList()
    ..sort((a, b) => b.compareTo(a));

  test('a finished run is recorded in the best-scores list and persisted',
      () async {
    final c = await newCubit();
    await playRun(c, 5);
    expect(scores(c), [5]);
    expect(c.state.personalBest, 5);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('u1_${GameConstant.bestScore}'),
        contains('Player@@@@5'));
  });

  test('runs accumulate, sort, and a 0-point run is ignored', () async {
    final c = await newCubit();
    await playRun(c, 3);
    await playRun(c, 9);
    await playRun(c, 0);
    await playRun(c, 6);
    expect(scores(c), [9, 6, 3]);
    expect(c.state.bestScore.length, 10);
  });

  test('only the top 10 are kept: a better run replaces the lowest', () async {
    final c = await newCubit();
    for (var s = 1; s <= 10; s++) {
      await playRun(c, s);
    }
    await playRun(c, 5); // beats only the 1 and 2... replaces the lowest (1)
    final list = scores(c);
    expect(list.length, 10);
    expect(list.contains(1), isFalse);
    await playRun(c, 1); // worse than everything kept -> not added
    expect(scores(c).contains(1), isFalse);
  });

  test('scores are kept per account', () async {
    final c = await newCubit();
    await playRun(c, 4);
    await c.setUser('u2');
    expect(scores(c), isEmpty);
    await c.setUser('u1');
    expect(scores(c), [4]);
  });

  test('upgrade: legacy un-prefixed scores migrate once into the first uid',
      () async {
    SharedPreferences.setMockInitialValues({
      GameConstant.personalBest: 12,
      GameConstant.bestScore: ['Old@@@@12', '0@@@@0'],
    });
    final c = MyGameCubit();
    await c.setUser('u1');
    expect(c.state.personalBest, 12);
    expect(scores(c), [12]);
    // A second account must not inherit the legacy data.
    await c.setUser('u2');
    expect(c.state.personalBest, 0);
    expect(scores(c), isEmpty);
    // Re-attaching u1 keeps (does not re-copy over) its own data.
    await playRun(c, 3);
    await c.setUser('u1');
    expect(c.state.personalBest, 12);
  });

  test('a run stores its play time; runs without one stay readable', () async {
    final c = await newCubit();
    await playRun(c, 5, seconds: 35);
    await playRun(c, 3); // no time known
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('u1_${GameConstant.bestScore}')!;
    expect(saved, contains('Player@@@@5@@@@35'));
    expect(saved, contains('Player@@@@3'));
    expect(scores(c), [5, 3]);
    expect(c.state.personalBest, 5);
  });
}
