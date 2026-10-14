import 'package:flip_flop/ads/ads.dart';
import 'package:flip_flop/utils/utils.dart';
import 'package:flip_flop/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flip_flop/setting/setting.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ShopPage extends StatelessWidget {
  static const routeName = "app/shop";

  @override
  Widget build(BuildContext context) {
    final appBar = shopAppBarWidget(context);
    double width = MediaQuery.of(context).size.width - 16 + 3;
    double height = MediaQuery.of(context).size.height -
        appBar.preferredSize.height -
        16 -
        42 -
        120; // reserve for ad buttons + banner
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF424242),
      appBar: appBar,
      body: Column(
        children: [
          // Shop selector triangles
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    right: 2.5,
                    child: TriangleButton(
                      onTap: () {
                        context.read<SettingCubit>().playSound(path: 'select');
                        Navigator.of(context).pushNamed(MapShop.routeName);
                      },
                      path: TriangleShape.bottomHalfSquare.path(width, height),
                      child: Container(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage("assets/images/background/graveyardBg.png"),
                            fit: BoxFit.fill,
                          ),
                          color: Colors.red,
                          borderRadius: BorderRadius.all(Radius.circular(4.0)),
                        ),
                        width: width,
                        height: height,
                        child: Center(
                          child: Container(
                            margin: EdgeInsets.only(right: width / 2),
                            child: CustomText('Maps', fontSize: 24, strokeWidth: 1.0),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 2.5,
                    child: TriangleButton(
                      onTap: () {
                        context.read<SettingCubit>().playSound(path: 'select');
                        Navigator.of(context).pushNamed(BirdShop.routeName);
                      },
                      path: TriangleShape.upperHalfSquare.path(width, height),
                      child: Container(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage("assets/images/background/springBg.png"),
                            fit: BoxFit.fill,
                          ),
                          color: Colors.green,
                          borderRadius: BorderRadius.all(Radius.circular(4.0)),
                        ),
                        width: width,
                        height: height,
                        child: Center(
                          child: Container(
                            margin: EdgeInsets.only(left: width / 2),
                            child: CustomText('Birds', fontSize: 24, strokeWidth: 1.0,
                                color: wood_smoke, borderColor: white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Watch Ad reward buttons ───────────────────────────────────────
          Container(
            color: Colors.black45,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                WatchAdButton(
                  label: '🪙 +${AdConfig.rewardedCoinAmount} Coins',
                  rewardCoins: true,
                ),
                WatchAdButton(
                  label: '🍎 +${AdConfig.rewardedFruitAmount} Fruit',
                  rewardCoins: false,
                ),
              ],
            ),
          ),

          // ── Banner ad at the very bottom ──────────────────────────────────
          const BannerAdWidget(),
        ],
      ),
    );
  }
}
