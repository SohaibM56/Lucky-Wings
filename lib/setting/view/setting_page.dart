import 'dart:io';
import 'dart:ui';

import 'package:flip_flop/ads/ads.dart';
import 'package:flip_flop/auth/auth.dart';
import 'package:flip_flop/components/components.dart';
import 'package:flip_flop/game_page.dart';
import 'package:flip_flop/leaderboard/leaderboard_page.dart';
import 'package:flip_flop/my_game/my_game.dart';
import 'package:flip_flop/setting/setting.dart';
import 'package:flip_flop/utils/utils.dart';
import 'package:flip_flop/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingPage extends StatelessWidget {
  static const routeName = "app/setting";

  SettingPage({Key? key, this.components}) : super(key: key);

  final List<Component>? components;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: transparentStatusBarDark,
      child: BlocListener<AuthCubit, AuthState>(
        listenWhen: (p, c) => !p.justBecameGuest && c.justBecameGuest,
        listener: (context, state) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "You're playing as a guest — sign in anytime to save your progress."),
            duration: Duration(seconds: 5),
          ));
          context.read<AuthCubit>().clearJustBecameGuest();
        },
        child: Scaffold(
          body: Stack(
            alignment: Alignment.center,
            children: [
              _Background(),
              _DialogBackground(),
              _TopCornerActions(),
              // const Positioned(
              //   top: 0,
              //   left: 0,
              //   right: 0,
              //   child: SafeArea(
              //     child: Padding(
              //       padding: EdgeInsets.only(top: 12),
              //       child: Center(child: _CurrencyBadge()),
              //     ),
              //   ),
              // ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  // ── Lucky Wings Logo ──────────────────────────────────
                  Image.asset(
                    'assets/images/logo/lucky_wings_logo.png',
                    width: 140,
                    height: 140,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'LUCKY WINGS',
                    style: TextStyle(
                      fontFamily: 'DiloWorld',
                      fontSize: 22,
                      color: Color(0xFFFFD700),
                      letterSpacing: 3,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                            color: Color(0xFF8B4500),
                            offset: Offset(1, 2),
                            blurRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PlayButton(),
                  const SizedBox(height: 20),
                  _ShopButton(),
                  const SizedBox(height: 20),
                  _ScoreButton(),
                  const SizedBox(height: 20),
                  _PrivacyButton(),
                  if (Platform.isAndroid) ...[
                    const SizedBox(height: 20),
                    _ExitButton(),
                  ],
                ],
              ),
              const Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: BannerAdWidget(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Background extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingCubit, SettingState>(
      buildWhen: (pre, cur) => pre.currentMap != cur.currentMap,
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            image: DecorationImage(
              image: AssetImage(state.currentMap.sprites.first),
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }
}

class _DialogBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width / 1.5;
    double height = MediaQuery.of(context).size.height / 1.7;
    // Android shows an extra Exit button the card wasn't sized for. Grow the
    // card downward only, so the logo keeps straddling the same top edge.
    final extraHeight = Platform.isAndroid ? 85.0 : 0.0;
    height += extraHeight;
    return Center(
      child: Transform.translate(
        offset: Offset(0, extraHeight / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            width: width,
            height: height,
            alignment: Alignment.bottomCenter,
            margin: EdgeInsets.all(24),
            padding: EdgeInsets.all(24),
            decoration: ShapeDecoration(
              shadows: [
                BoxShadow(color: wood_smoke, offset: Offset(0, 6)),
              ],
              shape: RoundedRectangleBorder(
                side: BorderSide(width: 2, color: wood_smoke),
                borderRadius: BorderRadius.circular(16),
              ),
              color: primary_color.withOpacity(0.8),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PlainShadowButton(
      borderColor: wood_smoke,
      color: lightening_yellow,
      bodyBuilder: (isTapped) {
        return CustomText(
          "Privacy Policy",
          fontSize: isTapped ? 16 : 21,
          fontWeight: FontWeight.w800,
          strokeWidth: 1.0,
          textAlign: TextAlign.center,
        );
      },
      height: 65,
      size: 200,
      callback: () {
        context.read<SettingCubit>().playButtonSound();
        showDialog(
          context: context,
          builder: (_) => CustomDialog(
            showSecondaryButton: false,
            showPrimaryButton: true,
            primaryText: "OK",
            primaryButtonPressed: () => Navigator.pop(context),
            bodyMarginBottom: 100,
            bodyWidget: PrivacyWidget(),
          ),
        );
      },
      shadowColor: wood_smoke,
    );
  }
}

class _ShopButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PlainShadowButton(
      borderColor: wood_smoke,
      color: lightening_yellow,
      bodyBuilder: (isTapped) {
        return CustomText(
          "Store",
          fontSize: isTapped ? 16 : 21,
          fontWeight: FontWeight.w800,
          strokeWidth: 1.0,
        );
      },
      height: 65,
      size: 200,
      callback: () {
        context.read<SettingCubit>().playButtonSound();
        Navigator.of(context).pushNamed(ShopPage.routeName);
      },
      shadowColor: wood_smoke,
    );
  }
}

class _PlayButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PlainShadowButton(
      borderColor: wood_smoke,
      color: lightening_yellow,
      bodyBuilder: (isTapped) {
        return CustomText(
          "New Game",
          fontSize: isTapped ? 16 : 21,
          fontWeight: FontWeight.w800,
          strokeWidth: 1.0,
        );
      },
      height: 65,
      size: 200,
      callback: () {
        final settingCubit = context.read<SettingCubit>();
        final gameCubit = context.read<MyGameCubit>();
        settingCubit.playButtonSound();
        gameCubit.getTurn();
        Navigator.of(context).pushNamed(
          GamePage.routeName,
          arguments: settingCubit.state.components,
        );
      },
      shadowColor: wood_smoke,
    );
  }
}

class _ScoreButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PlainShadowButton(
      borderColor: wood_smoke,
      color: lightening_yellow,
      bodyBuilder: (isTapped) {
        return CustomText(
          "Leaderboard",
          fontSize: isTapped ? 16 : 21,
          fontWeight: FontWeight.w800,
          strokeWidth: 1.0,
        );
      },
      height: 65,
      size: 200,
      callback: () {
        context.read<SettingCubit>().playButtonSound();
        Navigator.pushNamed(context, LeaderboardPage.routeName);
      },
      shadowColor: wood_smoke,
    );
  }
}

// Main-menu header: a single tappable account pill (username + avatar icon,
// or "Playing as Guest") on the left that opens AccountPage, and the
// currency badge on the right. Everything else that used to live here
// (logout icon, verify-email icon, "Hi, X" text, the separate guest badge)
// now lives inside AccountPage — this row got crowded enough to clip the
// username behind the currency badge before that move.
class _TopCornerActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const _AccountPill(),
              const Spacer(),
              _CurrencyBadge(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountPill extends StatelessWidget {
  const _AccountPill();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (p, c) =>
          p.isGuest != c.isGuest ||
          p.user?.username != c.user?.username ||
          p.needsEmailVerification != c.needsEmailVerification,
      builder: (context, state) {
        final username = state.user?.username;
        final label = state.isGuest
            ? 'Guest'
            : (username?.isNotEmpty == true ? username! : 'Player');
        return GestureDetector(
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const AccountPage())),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon-only pill, same circular style as the old logout
              // button — the username now reads as a label next to it
              // rather than being printed on top of the yellow fill.
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: ShapeDecoration(
                      color: lightening_yellow,
                      shadows: [
                        BoxShadow(color: wood_smoke, offset: Offset(0, 4))
                      ],
                      shape: CircleBorder(
                          side: BorderSide(color: wood_smoke, width: 2)),
                    ),
                    child: const Icon(Icons.person,
                        color: Colors.black87, size: 20),
                  ),
                  // Small dot instead of a whole second icon — enough to
                  // flag "something needs attention" without crowding the
                  // row; tapping through to AccountPage shows what it is.
                  if (!state.isGuest && state.needsEmailVerification)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D6D),
                          shape: BoxShape.circle,
                          border: Border.all(color: wood_smoke, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'DiloWorld',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                          color: Colors.black45,
                          offset: Offset(0, 1),
                          blurRadius: 2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CurrencyBadge extends StatelessWidget {
  const _CurrencyBadge();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingCubit, SettingState>(
      buildWhen: (p, c) => p.coin != c.coin || p.fruit != c.fruit,
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: ShapeDecoration(
            color: lightening_yellow,
            shadows: [BoxShadow(color: wood_smoke, offset: Offset(0, 4))],
            shape: RoundedRectangleBorder(
              side: BorderSide(color: wood_smoke, width: 2),
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/objects/gold.png',
                  height: 22, fit: BoxFit.cover),
              const SizedBox(width: 6),
              CustomText('${state.coin}', fontSize: 16, strokeWidth: 0.75),
              const SizedBox(width: 16),
              Image.asset('assets/images/objects/fruit.png',
                  height: 22, fit: BoxFit.cover),
              const SizedBox(width: 6),
              CustomText('${state.fruit}', fontSize: 16, strokeWidth: 0.75),
            ],
          ),
        );
      },
    );
  }
}

class _ExitButton extends StatelessWidget {
  _ExitButton();

  final double height = 65;

  @override
  Widget build(BuildContext context) {
    return PlainShadowButton(
      borderColor: wood_smoke,
      color: lightening_yellow,
      bodyBuilder: (isTapped) {
        return CustomText(
          "Exit",
          fontSize: isTapped ? 16 : 21,
          fontWeight: FontWeight.w800,
          strokeWidth: 1.0,
        );
      },
      height: height,
      size: 200,
      callback: () {
        context.read<SettingCubit>().playButtonSound();
        showDialog(
          context: context,
          builder: (_) {
            double height = MediaQuery.of(context).size.height / 4;
            return CustomDialog(
              height: height,
              showCloseButton: false,
              showSecondaryButton: true,
              showPrimaryButton: true,
              secondaryText: "No",
              primaryText: "Yes",
              secondaryButtonPressed: () => Navigator.pop(context),
              primaryButtonPressed: () => SystemNavigator.pop(),
              bodyMargin: height / 2 - 16,
              bodyWidget: CustomText(
                'Do you want to exit?',
                fontSize: 18,
                strokeWidth: 0.15,
                color: wood_smoke,
                borderColor: white,
              ),
            );
          },
        );
      },
      shadowColor: wood_smoke,
    );
  }
}
