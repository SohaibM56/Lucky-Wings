import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flip_flop/ads/ads.dart';
import 'package:flip_flop/auth/auth_cubit.dart';
import 'package:flip_flop/leaderboard/leaderboard_page.dart';
import 'package:flip_flop/my_game/my_game.dart';
import 'package:flip_flop/components/components.dart';
import 'package:flip_flop/game_page.dart';
import 'package:flip_flop/notifications/notification_service.dart';
import 'package:flip_flop/raffle/raffle_cubit.dart';
import 'package:flip_flop/setting/setting.dart';
import 'package:flip_flop/splash_screen.dart';
import 'package:flip_flop/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:ui' as ui;
import 'game_manager.dart';
import 'firebase_options.dart';

late ui.Image fruitImg;
int gameTurn = 0;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The whole UI (game canvas math, fixed-position dialogs) assumes portrait.
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  // Ads start after the first frame (AdCubit.initialize): the consent form
  // needs a screen, and no ad may be requested before consent anyway.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Explicit rather than relying on the SDK default, so offline writes
  // (qualifier progress, session logs) reliably queue on-device and sync
  // once connectivity returns.
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);
  await NotificationService.instance.initialize();

  fruitImg = await GameUtils.loadImage("assets/images/objects/fruit.png");
  GameManager.gameItems = await GameManager.getGameItems();
  runApp(App());
}

class App extends StatelessWidget {
  App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SettingCubit>(
          lazy: false,
          create: (_) => SettingCubit()..initSetting(),
        ),
        BlocProvider<MyGameCubit>(
          lazy: false,
          create: (_) => MyGameCubit()..init(),
        ),
        BlocProvider<AuthCubit>(
          lazy: false,
          create: (_) => AuthCubit()..checkAuth(),
        ),
        BlocProvider<RaffleCubit>(
          lazy: false,
          create: (ctx) {
            final userId = ctx.read<AuthCubit>().state.user?.uid;
            return RaffleCubit()..init(userId: userId);
          },
        ),
        BlocProvider<LeaderboardCubit>(
          lazy: true,
          create: (ctx) => LeaderboardCubit(),
        ),
        BlocProvider<AdCubit>(
          lazy: false,
          create: (_) => AdCubit()..initialize(),
        ),
      ],
      child: FlipFlop(),
    );
  }
}

class FlipFlop extends StatefulWidget {
  FlipFlop({Key? key}) : super(key: key);

  @override
  State<FlipFlop> createState() => _FlipFlopState();
}

class _FlipFlopState extends State<FlipFlop> with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // App Open ad on returning after a long absence. AdPolicy decides (not over
  // gameplay, not right after another ad or a notification tap, 4 h gap).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      _backgroundedAt = null;
      if (since == null) return;
      final away = DateTime.now().difference(since);
      // Short pause so a notification tap that caused this resume has
      // registered itself (noteNotificationLaunch) before we decide.
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) context.read<AdCubit>().onAppResume(awayFor: away);
      });
    }
  }

  // Note: app-lifecycle pause/resume of the raffle session is owned by
  // GamePage's own WidgetsBindingObserver (it's the only screen with a live
  // session, and it deliberately requires an explicit tap-to-resume +
  // countdown rather than silently resuming on foreground — a global
  // auto-resume here used to race that and restart the qualifier timer
  // behind the still-showing pause overlay).

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      // AuthCubit.checkAuth() resolves after RaffleCubit is created, so it
      // doesn't have a uid yet — push it in as soon as auth settles.
      listenWhen: (p, c) => p.user?.uid != c.user?.uid,
      listener: (context, state) {
        final uid = state.user?.uid;
        if (uid == null) return;
        context.read<RaffleCubit>().setUser(uid);
        context.read<SettingCubit>().setUser(uid);
        context.read<MyGameCubit>().setUser(uid);
        NotificationService.instance.syncFcmToken(uid);
      },
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Lucky Wings',
        theme: ThemeData(
          primarySwatch: Colors.orange,
          scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        ),
        debugShowCheckedModeBanner: false,
        initialRoute: SplashScreen.routeName,
        onGenerateRoute: (settings) => PageRouteBuilder(
          pageBuilder: (context, _, __) {
            if (settings.name == SettingPage.routeName ||
                settings.name == GamePage.routeName) {
              final args = settings.arguments as List<Component>;
              return gameRoutes[settings.name]!(context, args);
            }
            return gameRoutes[settings.name]!(context, null);
          },
          settings: settings,
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ),
    );
  }
}
