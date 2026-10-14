import 'package:flip_flop/ads/ads.dart';
import 'package:flip_flop/components/components.dart';
import 'package:flip_flop/setting/setting.dart';
import 'package:flip_flop/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flip_flop/utils/utils.dart';
import 'package:flip_flop/widgets/widgets.dart';

class MapShop extends StatelessWidget {
  static const routeName = "app/map_shop";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: shopAppBarWidget(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: BlocBuilder<SettingCubit, SettingState>(
          builder: (context, state) {
            return ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              reverse: false,
              itemCount: state.maps.length,
              itemBuilder: (_, index) => _MapCard(
                isSelected: state.currentMap == state.maps[index],
                isBought: state.myMaps.contains(state.maps[index]),
                mapModel: state.maps[index],
                onTap: () {
                  final settingCubit = context.read<SettingCubit>();
                  bool _isBought = state.myMaps.contains(state.maps[index]);
                  if (state.maps[index].type == ItemType.needWatchAd &&
                      !_isBought) {
                    settingCubit.showRewardedAd(
                      onError: () => GameUtils.showSnackBar(context),
                      onCompleted: (rewardedAd) {
                        rewardedAd.show(
                          onUserEarnedReward: (ad, rewardItem) {
                            settingCubit.unlockMap(
                              map: state.maps[index],
                              index: index,
                              onSuccess: () => GameUtils.showSuccessDialog(
                                context,
                                onUse: () => context.read<SettingCubit>().mapChanged(map: state.maps[index], index: index),
                                bodyBuilder: (w, h) {
                                  return Container(
                                    width: w - 50,
                                    height: h - 170,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(8.0),
                                      ),
                                      image: DecorationImage(
                                        image: AssetImage(
                                            state.maps[index].sprites.first),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    );
                  } else {
                    settingCubit.mapChanged(
                      map: state.maps[index],
                      index: index,
                      onFailure: (status) {
                        if (status != SettingStatus.unknown)
                          showDialog(
                            context: context,
                            builder: (_) => CustomDialog(
                              width:  MediaQuery.of(context).size.width / 1.4,
                              height: MediaQuery.of(context).size.height / 2.5,
                              showCloseButton: false,
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
                                      onUserEarnedReward: (ad, rewardItem) {
                                        settingCubit.getReward(
                                          isCoin: status ==
                                              SettingStatus.needMoreCoin,
                                          value: status == SettingStatus.needMoreCoin ? AdConfig.rewardedCoinAmount : AdConfig.rewardedFruitAmount,
                                          onSuccess: () =>
                                              GameUtils.showSuccessDialog(
                                            context,
                                            autoHide:
                                                const Duration(seconds: 6),
                                            title:
                                                "+${status == SettingStatus.needMoreCoin ? AdConfig.rewardedCoinAmount : AdConfig.rewardedFruitAmount} ${status == SettingStatus.needMoreCoin ? "Coin" : "Fruit"}",
                                            showTitle: true,
                                            bodyBuilder: (w, h) {
                                              return Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    "+${status == SettingStatus.needMoreCoin ? AdConfig.rewardedCoinAmount : AdConfig.rewardedFruitAmount} ",
                                                    style: TextStyle(
                                                      fontFamily: fontFamily,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: wood_smoke,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
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
                                      backgroundImage:
                                          status == SettingStatus.needMoreCoin
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
                        onUse: () => context.read<SettingCubit>().mapChanged(map: state.maps[index], index: index),
                        title:
                        "-${state.maps[index].cost} ${state.maps[index].type == ItemType.needBuyByCoin ? " coin" : " fruit"}",
                        showTitle: true,
                        bodyBuilder: (w, h) {
                          return Container(
                            width: w - 50,
                            height: h - 170,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(
                                Radius.circular(8.0),
                              ),
                              image: DecorationImage(
                                image:
                                    AssetImage(state.maps[index].sprites.first),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  final MapModel mapModel;
  final bool isSelected;
  final bool isBought;
  final Function? onTap;

  const _MapCard({
    required this.mapModel,
    this.isSelected = false,
    this.isBought = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    double w = (MediaQuery.of(context).size.width - 24) / 2;
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(left: 4, right: 4, bottom: 16),
      decoration: ShapeDecoration(
        color: isSelected ? lightening_yellow : primary_color,
        shadows: [
          BoxShadow(
            color: wood_smoke,
            offset: Offset(
              0.0, // Move to right 10  horizontally
              2.0, // Move to bottom 5 Vertically
            ),
          )
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
          side: BorderSide(
              color: isSelected ? flamingo : wood_smoke, width: 2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              width: w,
              height: w,
              decoration: BoxDecoration(
                color: primary_color,
                borderRadius: BorderRadius.all(Radius.circular(8.0)),
                image: DecorationImage(
                  image: AssetImage(mapModel.sprites.first),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 20),
                CustomText(
                  mapModel.name,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: selectButton,
                ),
              ],
            ),
          ),
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
    if ((mapModel.type == ItemType.needWatchAd ||
            mapModel.type == ItemType.needShareSocial) &&
        !isBought) {
      return CustomText(
        mapModel.type == ItemType.needWatchAd ? "Watch Ad" : "Share",
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
            mapModel.type == ItemType.needBuyByCoin
                ? 'assets/images/objects/gold.png'
                : 'assets/images/objects/multiFruit.png',
            fit: BoxFit.cover,
            height: isTapped ? 16 : 20,
          ),
          SizedBox(width: isTapped ? 2 : 4),
          CustomText(
            '${mapModel.cost}',
            textAlign: TextAlign.center,
            fontSize: isTapped ? 12 : 16,
            fontWeight: FontWeight.bold,
          ),
        ],
      );
    }
  }
}
