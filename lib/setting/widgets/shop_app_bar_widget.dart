import 'package:flip_flop/ads/ads.dart';
import 'package:flip_flop/components/components.dart';
import 'package:flip_flop/theme.dart';
import 'package:flip_flop/utils/utils.dart';
import 'package:flip_flop/widgets/widgets.dart';
import 'package:flip_flop/setting/setting.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

AppBar shopAppBarWidget(BuildContext context) => AppBar(
      flexibleSpace: Container(
        decoration: BoxDecoration(color: primary_color),
      ),
      backgroundColor: Colors.transparent,
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CupertinoButton(
            padding: const EdgeInsets.all(0),
            onPressed: () {
              context.read<SettingCubit>().playButtonSound();
              Navigator.of(context).pop();
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
          const SizedBox(width: 12),
          CustomButton(
            height: 40,
            clickImagePath: 'assets/images/objects/fruit.png',
            normalImagePath: 'assets/images/objects/fruit.png',
          ),
          const SizedBox(width: 8),
          _FruitInfoWidget(),
          Spacer(),
          _MoreCoinButton(),
          CustomButton(
            height: 40,
            clickImagePath: 'assets/images/objects/gold.png',
            normalImagePath: 'assets/images/objects/gold.png',
          ),
          const SizedBox(width: 8),
          _CoinInfoWidget(),
          const SizedBox(width: 12),
        ],
      ),
      elevation: 0,
    );

class _FruitInfoWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingCubit, SettingState>(
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

class _CoinInfoWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingCubit, SettingState>(
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

class _MoreCoinButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingCubit, SettingState>(
      builder: (context, state) {
        final settingCubit = context.read<SettingCubit>();
        return CupertinoButton(
          padding: const EdgeInsets.all(0.0),
          child: Icon(
            const IconData(
              0xf489,
              fontFamily: CupertinoIcons.iconFont,
              fontPackage: CupertinoIcons.iconFontPackage,
            ),
            size: 30,
          ),
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => CustomDialog(
                showCloseButton: false,
                width:  MediaQuery.of(context).size.width / 1.4,
                height: MediaQuery.of(context).size.height / 2.5,
                showSecondaryButton: true,
                showPrimaryButton: true,
                secondaryText: "No",
                primaryText: "Yes",
                title: "+${AdConfig.rewardedCoinAmount} Coin ?",
                showTitle: true,
                secondaryButtonPressed: () => Navigator.pop(context),
                primaryButtonPressed: () {
                  settingCubit.showRewardedAd(
                    onError: () => GameUtils.showSnackBar(context),
                    onCompleted: (rewardedAd) {
                      rewardedAd.show(
                        onUserEarnedReward: (ad, rewardItem) {
                          settingCubit.getReward(
                            isCoin: true,
                            value: AdConfig.rewardedCoinAmount,
                            onSuccess: () => GameUtils.showSuccessDialog(
                              context,
                              autoHide: const Duration(seconds: 6),
                              title: "+${AdConfig.rewardedCoinAmount} Coin",
                              showTitle: true,
                              bodyBuilder: (w, h) {
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "+${AdConfig.rewardedCoinAmount} ",
                                      style: TextStyle(
                                        fontFamily: fontFamily,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: wood_smoke,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    CustomButton(
                                      height: 40,
                                      clickImagePath:
                                          'assets/images/objects/gold.png',
                                      normalImagePath:
                                          'assets/images/objects/gold.png',
                                    ),
                                  ],
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                  Navigator.pop(context);
                },
                bodyWidget: Center(
                  child: Column(
                    children: [
                      ImageScaleTransition(
                        width: 120,
                        aspectRatio: 224 / 252,
                        backgroundImage: 'assets/images/ad2.png',
                      ),
                      const SizedBox(height: 8),
                      CustomText(
                        'Watch ads to receive 30 coin.\nDo you want to watch?',
                        textAlign: TextAlign.center,
                        strokeWidth: 0.15,
                        color: wood_smoke,
                        borderColor: white,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
