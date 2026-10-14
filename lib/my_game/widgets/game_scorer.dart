import 'dart:io';

import 'package:flip_flop/ads/ads.dart';
import 'package:flip_flop/game_manager.dart';
import 'package:flip_flop/my_game/my_game.dart';
import 'package:flip_flop/setting/setting.dart';
import 'package:flip_flop/widgets/widgets.dart';
import 'package:flip_flop/utils/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GameScorer extends StatelessWidget {
  const GameScorer({Key? key, this.onRestart}) : super(key: key);

  final Function? onRestart;

  @override
  Widget build(BuildContext context) {
    return BlocListener<MyGameCubit, MyGameState>(
      listenWhen: (pre, cur) => pre.gameState != cur.gameState,
      listener: (context, state) {
        if (state.gameState == GameState.firstTime) {
          showDialog(
            barrierDismissible: false,
            context: context,
            builder: (_) => UserGuide(),
          );
        } else if (state.gameState == GameState.gameOver) {
          showDialog(
            barrierDismissible: false,
            context: context,
            builder: (_) {
              double height = MediaQuery.of(context).size.height;
              return WillPopScope(
                // The dialog route would otherwise just dismiss itself on
                // back press, leaving the bare game-over screen behind with
                // no visible way forward — route system back to the main
                // screen instead, same as the Exit button.
                onWillPop: () async {
                  _exitToMainScreen(context);
                  return false;
                },
                child: Center(
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(
                      top: height / 4,
                      child: Column(
                        children: [
                          SizedBox(
                            width: 200,
                            child: Image.asset(
                              'assets/images/go.png',
                              fit: BoxFit.fill,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 200,
                            height: 100,
                            decoration: BoxDecoration(
                              color: lightening_yellow,
                              borderRadius: BorderRadius.all(
                                Radius.circular(8.0),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 35,
                                  child: Image.asset(
                                    'assets/images/reward.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CustomText(
                                      'SCORE  ${state.score}',
                                      fontSize: 22,
                                      strokeWidth: 1.0,
                                    ),
                                    const SizedBox(height: 4),
                                    CustomText(
                                      'BEST   ${state.personalBest}',
                                      fontSize: 22,
                                      strokeWidth: 1.0,
                                    ),
                                  ],
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    Positioned(
                      top: height / 4 + 143 + 108 + 68,
                      child: PlainShadowButton(
                        borderColor: wood_smoke,
                        color: lightening_yellow,
                        bodyBuilder: (isTapped) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.home,
                                  size: isTapped ? 16 : 21, color: wood_smoke),
                              const SizedBox(width: 6),
                              CustomText(
                                "EXIT",
                                fontSize: isTapped ? 16 : 21,
                                fontWeight: FontWeight.w800,
                                strokeWidth: 1.0,
                              ),
                            ],
                          );
                        },
                        height: 60,
                        size: 200,
                        callback: () => _exitToMainScreen(context),
                        shadowColor: wood_smoke,
                      ),
                    ),
                    Positioned(
                      top: height / 4 + 143 + 108,
                      child: PlainShadowButton(
                        borderColor: wood_smoke,
                        color: lightening_yellow,
                        bodyBuilder: (isTapped) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.replay,
                                  size: isTapped ? 16 : 21, color: wood_smoke),
                              const SizedBox(width: 6),
                              CustomText(
                                "Try Again",
                                fontSize: isTapped ? 16 : 21,
                                fontWeight: FontWeight.w800,
                                strokeWidth: 1.0,
                              ),
                            ],
                          );
                        },
                        height: 60,
                        size: 200,
                        callback: () {
                          Navigator.pop(context);
                          onRestart?.call();
                        },
                        shadowColor: wood_smoke,
                      ),
                    ),
                    // Watch Ad for coins button
                    Positioned(
                      top: height / 4 + 143 + 108 + 136,
                      child: WatchAdButton(
                        label:
                            'Watch Ad • Get ${AdConfig.rewardedCoinAmount} Coins',
                        rewardCoins: true,
                      ),
                    ),
                    if (Platform.isAndroid)
                      Positioned(
                        top: height / 4 + 143 + 108 + 204,
                        child: PlainShadowButton(
                          borderColor: wood_smoke,
                          color: lightening_yellow,
                          bodyBuilder: (isTapped) {
                            return CustomText(
                              "Rate Us",
                              fontSize: isTapped ? 16 : 21,
                              fontWeight: FontWeight.w800,
                              strokeWidth: 1.0,
                            );
                          },
                          height: 60,
                          size: 200,
                          callback: () =>
                              GameSound.platform.invokeMethod('ratingUs'),
                          shadowColor: wood_smoke,
                        ),
                      )
                  ],
                ),
                ),
              );
            },
          );
        }
      },
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CupertinoButton(
              padding: const EdgeInsets.all(0),
              onPressed: () {
                context.read<MyGameCubit>().playButtonSound();
                // maybePop (not pop) so WillPopScope's exit confirmation in
                // GamePage runs the same way it does for the system back
                // button, instead of bypassing it.
                Navigator.of(context).maybePop();
              },
              child: Icon(
                const IconData(
                  0xf3cf,
                  fontFamily: CupertinoIcons.iconFont,
                  fontPackage: CupertinoIcons.iconFontPackage,
                ),
                size: 30,
              ),
            ),
            const SizedBox(width: 10),
            _ScoreBuilder(),
            const SizedBox(width: 20),
            Image.asset(
              'assets/images/objects/fruit.png',
              fit: BoxFit.cover,
              height: 30,
            ),
            const SizedBox(width: 8),
            _FruitBuilder(),
            const SizedBox(width: 20),
            Image.asset(
              'assets/images/objects/gold.png',
              fit: BoxFit.cover,
              height: 30,
            ),
            const SizedBox(width: 8),
            _CoinBuilder(),
          ],
        ),
      ),
    );
  }
}

/// Pops every route pushed on top of the main menu (game screen, any
/// leaderboard/dashboard navigated to mid-game) in one go, so Exit always
/// lands back on the main screen regardless of how deep the stack is.
void _exitToMainScreen(BuildContext context) {
  Navigator.of(context)
      .popUntil(ModalRoute.withName(SettingPage.routeName));
}

class _ScoreBuilder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyGameCubit, MyGameState>(
      buildWhen: (pre, cur) => pre.score != cur.score,
      builder: (context, state) {
        return CustomText(
          'Score: ${state.score}',
          fontSize: 18,
          fontWeight: FontWeight.w800,
          strokeWidth: 0.75,
        );
      },
    );
  }
}

class _FruitBuilder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyGameCubit, MyGameState>(
      buildWhen: (pre, cur) => pre.fruit != cur.fruit,
      builder: (context, state) {
        return CustomText(
          'x${state.fruit}',
          fontSize: 18,
          fontWeight: FontWeight.w800,
          strokeWidth: 0.75,
        );
      },
    );
  }
}

class _CoinBuilder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyGameCubit, MyGameState>(
      buildWhen: (pre, cur) => pre.coin != cur.coin,
      builder: (context, state) {
        return CustomText(
          '${state.coin}',
          fontSize: 18,
          fontWeight: FontWeight.w800,
          strokeWidth: 0.75,
        );
      },
    );
  }
}
