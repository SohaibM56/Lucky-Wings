import 'package:flip_flop/ads/ads.dart';
import 'package:flip_flop/notifications/notification_service.dart';
import 'package:flip_flop/auth/auth.dart';
import 'package:flip_flop/setting/setting.dart';
import 'package:flip_flop/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SplashScreen extends StatefulWidget {
  static const routeName = "app/splash";

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _animationDone = false;
  bool _guestSignInAttempted = false;

  @override
  void initState() {
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 6),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.slowMiddle,
      ),
    );
    _animationController.addListener(() {
      if (_animationController.isCompleted) {
        _animationDone = true;
        _navigateWhenReady();
      }
    });
    _animationController.forward();
    super.initState();
  }

  // Waits for both the splash animation and AuthCubit's checkAuth() to
  // finish before deciding where to go. A fresh install (or a signed-out
  // session) drops straight into the game as a guest instead of gating
  // gameplay behind a login screen — login stays available, just optional.
  void _navigateWhenReady() {
    if (!_animationDone) return;
    final authCubit = context.read<AuthCubit>();
    final authState = authCubit.state;
    if (authState.status == AuthStatus.initial ||
        authState.status == AuthStatus.loading) {
      return;
    }
    if (authState.isAuthenticated) {
      final components = context.read<SettingCubit>().state.components;
      Navigator.pushNamedAndRemoveUntil(
        context,
        SettingPage.routeName,
        (route) => false,
        arguments: components,
      );
      // A terminated-app push tap queued a dashboard route during startup.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationService.instance.consumePendingRoute();
        // Cold-start App Open ad, once we're on the main menu (AdPolicy
        // decides: not on the very first launch, not after a notification
        // tap, at most once per 4 hours).
        context.read<AdCubit>().onAppResume();
      });
    } else if (!_guestSignInAttempted) {
      _guestSignInAttempted = true;
      authCubit.continueAsGuest();
    } else {
      // Guest sign-in failed — fall back to manual login instead of
      // retrying forever.
      Navigator.pushNamedAndRemoveUntil(
          context, AuthPage.routeName, (route) => false);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String get loadingText {
    if (_animation.value <= 2.5 / 6) {
      return "Welcome to Lucky Wings!";
    } else if (_animation.value <= 3.5 / 6) {
      return "Play 5 minutes daily to earn raffle entries";
    } else if (_animation.value <= 5 / 6) {
      return "Missed a day? Catch up anytime this month!";
    }
    return "Let's fly...";
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: transparentStatusBarLight,
      child: BlocListener<AuthCubit, AuthState>(
        listenWhen: (p, c) => p.status != c.status,
        listener: (context, state) => _navigateWhenReady(),
        child: Scaffold(
          backgroundColor: const Color(0xFF0F1428),
          body: SafeArea(
            child: Center(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, _) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),

                      // ── Logo ──────────────────────────────────────────────────
                      AnimatedOpacity(
                        opacity: (_animation.value * 3).clamp(0.0, 1.0),
                        duration: const Duration(milliseconds: 300),
                        child: AnimatedScale(
                          scale:
                              0.85 + (_animation.value * 0.15).clamp(0.0, 0.15),
                          duration: const Duration(milliseconds: 300),
                          child: Image.asset(
                            'assets/images/logo/lucky_wings_logo.png',
                            width: 220,
                            height: 220,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── App Name ─────────────────────────────────────────────
                      AnimatedOpacity(
                        opacity: (_animation.value * 4).clamp(0.0, 1.0),
                        duration: const Duration(milliseconds: 300),
                        child: Column(children: [
                          const Text(
                            'LUCKY WINGS',
                            style: TextStyle(
                              fontFamily: 'DiloWorld',
                              fontSize: 36,
                              color: Color(0xFFFFD700),
                              letterSpacing: 4,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'PLAY • QUALIFY • WIN',
                            style: TextStyle(
                              fontFamily: 'DiloWorld',
                              fontSize: 12,
                              color: Color(0xFFF5A623),
                              letterSpacing: 4,
                            ),
                          ),
                        ]),
                      ),

                      const Spacer(),

                      // ── Progress bar + loading text ───────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(children: [
                          Text(
                            loadingText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'DiloWorld',
                              fontSize: 13,
                              color: Color(0xFFF5A623),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _animation.value,
                              minHeight: 6,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFFD700)),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ]),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
