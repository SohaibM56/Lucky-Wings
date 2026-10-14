import 'package:flip_flop/auth/auth_page.dart';
import 'package:flip_flop/auth/account_page.dart';
import 'package:flip_flop/game_page.dart';
import 'package:flip_flop/leaderboard/leaderboard_page.dart';
import 'package:flip_flop/raffle/dashboard_page.dart';
import 'package:flip_flop/setting/setting.dart';
import 'package:flip_flop/splash_screen.dart';
import 'package:flutter/material.dart';

typedef CustomWidgetBuilder = Widget Function(BuildContext context, dynamic value);

final gameRoutes = <String, CustomWidgetBuilder>{
  SplashScreen.routeName       : (_, __) => SplashScreen(),
  SettingPage.routeName        : (_, args) => SettingPage(components: args),
  GamePage.routeName           : (_, args) => GamePage(components: args),
  DashboardPage.routeName      : (_, __) => const DashboardPage(),
  LeaderboardPage.routeName    : (_, __) => const LeaderboardPage(),
  AuthPage.routeName           : (_, __) => const AuthPage(),
  AccountPage.routeName        : (_, __) => const AccountPage(),
  BirdShop.routeName           : (_, __) => BirdShop(),
  MapShop.routeName            : (_, __) => MapShop(),
  ShopPage.routeName           : (_, __) => ShopPage(),
};
