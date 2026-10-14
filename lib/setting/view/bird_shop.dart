import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flip_flop/ads/ads.dart';
import 'package:flip_flop/setting/setting.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flip_flop/components/components.dart';
import 'package:flip_flop/utils/utils.dart';
import 'package:flip_flop/widgets/widgets.dart';
import 'package:share_plus/share_plus.dart';

class BirdShop extends StatelessWidget {
  static const routeName = "app/bird_shop";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: shopAppBarWidget(context),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              BlocBuilder<SettingCubit, SettingState>(
                builder: (context, state) {
                  return GridView.builder(
                    padding: EdgeInsets.all(12.0),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: (1 / 1),
                    ),
                    controller: ScrollController(keepScrollOffset: false),
                    shrinkWrap: true,
                    scrollDirection: Axis.vertical,
                    itemCount: state.birds.length,
                    itemBuilder: (BuildContext context, int index) {
                      return _BirdAvatar(
                        isSelected: state.currentBird == state.birds[index],
                        isBought: state.myBirds.contains(state.birds[index]),
                        onTap: () async {
                          final settingCubit = context.read<SettingCubit>();
                          bool _isBought =
                              state.myBirds.contains(state.birds[index]);
                          if (state.birds[index].type == ItemType.needWatchAd &&
                              !_isBought) {
                            settingCubit.showRewardedAd(
                              onError: () => GameUtils.showSnackBar(context),
                              onCompleted: (rewardedAd) {
                                rewardedAd.show(
                                  onUserEarnedReward: (ad, rewardItem) {
                                    settingCubit.unlockBird(
                                      bird: state.birds[index],
                                      index: index,
                                      onSuccess: () =>
                                          GameUtils.showSuccessDialog(
                                        context,
                                        onUse: () => context.read<SettingCubit>().birdChanged(bird: state.birds[index], index: index),
                                        bodyBuilder: (w, h) {
                                          return Container(
                                            width: w - 120,
                                            child: BirdWidget(
                                              startAnimation: true,
                                              sprites:
                                                  state.birds[index].sprites,
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          } else if (state.birds[index].type ==
                              ItemType.needShareSocial && !_isBought) {
                            ShareResult result = await SharePlus.instance.share(
                              ShareParams(
                                // The iOS store page does not exist yet, so everyone
                                // gets the Play link for now.
                                text: 'https://play.google.com/store/apps/details?id=com.robinson.luckywings',
                                subject:
                                    'Check out Lucky Wings - the daily raffle game! 🐦🏆',
                              ),
                            );
                            if (result.status == ShareResultStatus.success) {
                              settingCubit.unlockBird(
                                bird: state.birds[index],
                                index: index,
                                onSuccess: () => GameUtils.showSuccessDialog(
                                  context,
                                  onUse: () => context.read<SettingCubit>().birdChanged(bird: state.birds[index], index: index),
                                  bodyBuilder: (w, h) {
                                    return Container(
                                      width: w - 120,
                                      child: BirdWidget(
                                        startAnimation: true,
                                        sprites: state.birds[index].sprites,
                                      ),
                                    );
                                  },
                                ),
                              );
                            }
                          } else {
                            settingCubit.birdChanged(
                              bird: state.birds[index],
                              index: index,
                              onFailure: (status) {
                                if (status != SettingStatus.unknown)
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
                                      title:
                                          "+${status == SettingStatus.needMoreCoin ? AdConfig.rewardedCoinAmount : AdConfig.rewardedFruitAmount} ${status == SettingStatus.needMoreCoin ? "Coin" : "Fruit"} ?",
                                      showTitle: true,
                                      secondaryButtonPressed: () =>
                                          Navigator.pop(context),
                                      primaryButtonPressed: () {
                                        settingCubit.showRewardedAd(
                                          onError: () =>
                                              GameUtils.showSnackBar(context),
                                          onCompleted: (rewardedAd) {
                                            rewardedAd.show(
                                              onUserEarnedReward:
                                                  (ad, rewardItem) {
                                                settingCubit.getReward(
                                                  isCoin: status ==
                                                      SettingStatus
                                                          .needMoreCoin,
                                                  value: status == SettingStatus.needMoreCoin
                                                      ? AdConfig
                                                          .rewardedCoinAmount
                                                      : AdConfig
                                                          .rewardedFruitAmount,
                                                  onSuccess: () => GameUtils
                                                      .showSuccessDialog(
                                                    context,
                                                    autoHide: const Duration(
                                                        seconds: 6),
                                                    title:
                                                        "+${status == SettingStatus.needMoreCoin ? AdConfig.rewardedCoinAmount : AdConfig.rewardedFruitAmount} ${status == SettingStatus.needMoreCoin ? "Coin" : "Fruit"}",
                                                    showTitle: true,
                                                    bodyBuilder: (w, h) {
                                                      return Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Text(
                                                            "+${status == SettingStatus.needMoreCoin ? AdConfig.rewardedCoinAmount : AdConfig.rewardedFruitAmount} ",
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  'DiloWorld',
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: wood_smoke,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          CustomButton(
                                                            height: 40,
                                                            clickImagePath:
                                                                'assets/images/objects/${status == SettingStatus.needMoreCoin ? "gold" : "fruit"}.png',
                                                            normalImagePath:
                                                                'assets/images/objects/${status == SettingStatus.needMoreCoin ? "gold" : "fruit"}.png',
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
                                              aspectRatio:
                                              status == SettingStatus.needMoreCoin
                                                  ? 224 / 252
                                                  : 167 / 150,
                                              backgroundImage: status ==
                                                      SettingStatus.needMoreCoin
                                                  ? 'assets/images/ad2.png'
                                                  : 'assets/images/watchAd.png',
                                            ),
                                            const SizedBox(height: 8),
                                            CustomText(
                                              'Sorry! Your ${status == SettingStatus.needMoreCoin ? 'coin' : 'fruit'} not enough.\nDo you want to watch ads?',
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
                              onSuccess: () => GameUtils.showSuccessDialog(
                                context,
                                onUse: () => context.read<SettingCubit>().birdChanged(bird: state.birds[index], index: index),
                                title:
                                    "-${state.birds[index].cost} ${state.birds[index].type == ItemType.needBuyByCoin ? " coin" : " fruit"}",
                                showTitle: true,
                                bodyBuilder: (w, h) {
                                  return Container(
                                    width: w - 120,
                                    child: BirdWidget(
                                      startAnimation: true,
                                      sprites: state.birds[index].sprites,
                                    ),
                                  );
                                },
                              ),
                            );
                          }
                        },
                        birdModel: state.birds[index],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BirdAvatar extends StatelessWidget {
  const _BirdAvatar({
    this.isSelected = false,
    this.isBought = false,
    this.onTap,
    required this.birdModel,
  });

  final double width = 70;
  final bool isSelected;
  final bool isBought;
  final Function? onTap;
  final BirdModel birdModel;

  @override
  Widget build(BuildContext context) {
    double w = (MediaQuery.of(context).size.width - 48) / 2;
    return Container(
      padding: const EdgeInsets.all(8),
      child: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            width: w,
            height: w + 20,
            decoration: ShapeDecoration(
              color: isSelected ? lightening_yellow : primary_color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8.0)),
                side: BorderSide(
                    color: isSelected ? flamingo : wood_smoke, width: 2),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CustomText(
                    birdModel.name,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: width,
                    child: BirdWidget(
                      key: Key('${birdModel.name}_$isSelected'),
                      startAnimation: isSelected,
                      sprites: birdModel.sprites,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isSelected)
                    Container(
                      width: width - 10,
                      height: (width - 10) / 5,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(color: Colors.black, width: 0.0),
                        borderRadius: BorderRadius.all(
                            Radius.elliptical((width - 10), (width - 10) / 5)),
                      ),
                    )
                ],
              ),
            ),
          ),
          Positioned(bottom: 0, child: selectButton),
        ],
      ),
    );
  }

  Widget get selectButton {
    return PlainShadowButton(
      borderColor: wood_smoke,
      color: buttonColor,
      bodyBuilder: bodyButton,
      height: 40,
      size: 120,
      shadowColor: isSelected ? athens_gray : wood_smoke,
      callback: isSelected ? null : () => onTap?.call(),
    );
  }

  Color get buttonColor => isSelected ? athens_gray : lightening_yellow;

  Widget bodyButton(bool isTapped) {
    if ((birdModel.type == ItemType.needWatchAd ||
            birdModel.type == ItemType.needShareSocial) &&
        !isBought) {
      return CustomText(
        birdModel.type == ItemType.needWatchAd ? "Watch Ad" : "Share",
        textAlign: TextAlign.center,
        fontSize: isTapped ? 12 : 16,
        fontWeight: FontWeight.w800,
      );
    } else if (isBought || isSelected) {
      return CustomText(
        "${isSelected ? 'Selected' : 'Use'}",
        textAlign: TextAlign.center,
        fontSize: isTapped || isSelected ? 12 : 16,
        fontWeight: FontWeight.w800,
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            birdModel.type == ItemType.needBuyByCoin
                ? 'assets/images/objects/gold.png'
                : 'assets/images/objects/multiFruit.png',
            fit: BoxFit.cover,
            height: isTapped ? 16 : 20,
          ),
          SizedBox(width: isTapped ? 2 : 4),
          CustomText(
            '${birdModel.cost}',
            textAlign: TextAlign.center,
            fontSize: isTapped ? 12 : 16,
            fontWeight: FontWeight.bold,
          ),
        ],
      );
    }
  }
}
