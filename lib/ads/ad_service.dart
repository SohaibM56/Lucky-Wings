// ============================================================
// ad_service.dart
//
// Manages all ad lifecycle for Lucky Wings:
//   • Banner        — main menu, game and shop screens
//   • Interstitial  — at the natural break after a game over
//   • Rewarded      — opt-in "watch an ad" buttons
//   • Native        — leaderboard
//   • App Open      — after the splash / after a long absence
//
// Start-up order matters for policy: the consent form (EU/UK/CH users) is
// shown FIRST and no ad is requested until Google says it may be. When to
// show an ad is decided by AdPolicy; this class only holds the state.
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ad_config.dart';
import 'ad_policy.dart';

class AdService {
  static AdService? _instance;
  static AdService get instance => _instance ??= AdService._();
  AdService._();

  static const _kTotalGameOvers = 'ads_total_game_overs';
  static const _kAppOpenLastShown = 'ads_app_open_last_shown';
  static const _kLaunchedBefore = 'ads_launched_before';

  // ─── Cached ads ───────────────────────────────────────────────────────────
  InterstitialAd? _interstitialAd;
  RewardedAd?     _rewardedAd;
  AppOpenAd?      _appOpenAd;

  bool _interstitialReady = false;
  bool _rewardedReady     = false;
  bool _appOpenReady      = false;

  /// True once consent has been resolved and Google allows ad requests.
  /// Widgets listen to this so they only request an ad after consent.
  final ValueNotifier<bool> adsEnabled = ValueNotifier<bool>(false);

  /// Mirrors "a rewarded ad is loaded and can be shown". The "Watch Ad"
  /// buttons follow this live; the ad loads asynchronously, so reading the
  /// flag once at start-up always saw "not ready".
  final ValueNotifier<bool> rewardedReadyNotifier = ValueNotifier<bool>(false);

  // ─── State used by AdPolicy ───────────────────────────────────────────────
  int _gamesSinceLastInterstitial = 0;
  int _totalGameOvers = 0;
  DateTime? _lastInterstitialShown;
  DateTime? _lastAppOpenShown;
  DateTime? _lastFullScreenEnd;
  DateTime? _suppressAppOpenUntil;
  bool _firstLaunchEver = false;
  bool _suppressNextInterstitial = false;
  bool _initStarted = false;

  /// Set by the game screen while it is mounted (running OR paused): no App
  /// Open ad may cover gameplay.
  bool inGameplay = false;

  // ─── Init ─────────────────────────────────────────────────────────────────

  /// Call once, after the first frame (the consent form needs a screen).
  Future<void> initialize() async {
    if (_initStarted) return;
    _initStarted = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _totalGameOvers = prefs.getInt(_kTotalGameOvers) ?? 0;
      final last = prefs.getInt(_kAppOpenLastShown);
      _lastAppOpenShown =
          last == null ? null : DateTime.fromMillisecondsSinceEpoch(last);
      _firstLaunchEver = !(prefs.getBool(_kLaunchedBefore) ?? false);
      await prefs.setBool(_kLaunchedBefore, true);

      if (!AdConfig.useTestAds && !AdConfig.liveIdsConfigured) {
        debugPrint('AdService: live ads requested but IDs are placeholders');
      }
      if (!await _gatherConsent()) {
        debugPrint('AdService: ads not allowed (consent), not loading');
        return;
      }
      await MobileAds.instance.initialize();
      await MobileAds.instance.updateRequestConfiguration(RequestConfiguration(
        maxAdContentRating: AdConfig.maxAdContentRating,
      ));
      adsEnabled.value = true;
      // Pre-load everything in parallel
      await Future.wait([
        _loadInterstitial(),
        _loadRewarded(),
        _loadAppOpen(),
      ]);
    } catch (e) {
      debugPrint('AdService.initialize failed: $e');
    }
  }

  /// Google's User Messaging Platform: shows the consent form where the law
  /// requires it (EEA, UK, Switzerland) and tells us whether ads may be
  /// requested. Never blocks start-up for long: after 15 s we fall back to
  /// whatever consent state is already stored.
  Future<bool> _gatherConsent() async {
    final done = Completer<void>();
    var consentFailed = false;
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
          if (formError != null) {
            debugPrint('Consent form error: ${formError.message}');
          }
          finish();
        });
      },
      (error) {
        debugPrint('Consent info update failed: ${error.message}');
        consentFailed = true;
        finish();
      },
    );
    await done.future.timeout(const Duration(seconds: 15), onTimeout: () {});
    if (await ConsentInformation.instance.canRequestAds()) return true;
    // Google's test ads carry no real user data, so while on test units a
    // consent set-up problem (e.g. no GDPR message created yet in AdMob ->
    // "Publisher misconfiguration") must not stop development builds. Live
    // ads never get this exception: they need the consent message.
    return consentFailed && AdConfig.useTestAds;
  }

  // ─── Banner ads ───────────────────────────────────────────────────────────

  /// Creates a new banner ad widget.
  /// Call this every time you need a banner — banners are not reused.
  BannerAd createBanner({
    AdSize size = AdSize.banner,
    BannerAdListener? listener,
  }) {
    return BannerAd(
      adUnitId: AdConfig.bannerId,
      size: size,
      request: const AdRequest(),
      listener: listener ?? BannerAdListener(
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
  }

  // ─── Native ads ───────────────────────────────────────────────────────────

  /// A native ad rendered with Google's built-in template, which carries the
  /// required "Ad" badge, AdChoices icon, headline, icon and button.
  NativeAd createNative({required NativeAdListener listener}) {
    return NativeAd(
      adUnitId: AdConfig.nativeId,
      request: const AdRequest(),
      listener: listener,
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
      ),
    );
  }

  // ─── Interstitial ads ─────────────────────────────────────────────────────

  Future<void> _loadInterstitial() async {
    _interstitialReady = false;
    await InterstitialAd.load(
      adUnitId: AdConfig.interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              noteFullScreenEnded();
              ad.dispose();
              _interstitialAd = null;
              _interstitialReady = false;
              _loadInterstitial(); // pre-load next one immediately
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              _interstitialReady = false;
              _loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _interstitialReady = false;
          // Retry after 30 seconds
          Future.delayed(const Duration(seconds: 30), _loadInterstitial);
        },
      ),
    );
  }

  /// Returns true if an interstitial is ready AND the policy allows it now.
  bool get canShowInterstitial => AdPolicy.canShowInterstitial(
        adReady: _interstitialReady && _interstitialAd != null,
        totalGameOvers: _totalGameOvers,
        gamesSinceLast: _gamesSinceLastInterstitial,
        lastShown: _lastInterstitialShown,
        now: DateTime.now(),
        suppressedThisRun: _suppressNextInterstitial,
      );

  /// Call on every game over to track frequency. Persisted, so the
  /// "first games are ad-free" rule survives app restarts.
  void recordGameOver() {
    _gamesSinceLastInterstitial++;
    _totalGameOvers++;
    SharedPreferences.getInstance()
        .then((p) => p.setInt(_kTotalGameOvers, _totalGameOvers));
  }

  /// The run that just ended earned a raffle entry: don't follow the
  /// celebration with an ad. Applies to the next showInterstitialIfReady.
  void suppressNextInterstitial() => _suppressNextInterstitial = true;

  /// Show interstitial if ready and the policy allows it. True if shown.
  Future<bool> showInterstitialIfReady({
    VoidCallback? onDismissed,
    VoidCallback? onSkipped,
  }) async {
    final allowed = canShowInterstitial;
    _suppressNextInterstitial = false; // applies to one decision only
    if (!allowed) {
      onSkipped?.call();
      return false;
    }
    _lastInterstitialShown = DateTime.now();
    _gamesSinceLastInterstitial = 0;

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        noteFullScreenEnded();
        ad.dispose();
        _interstitialAd = null;
        _interstitialReady = false;
        _loadInterstitial();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadInterstitial();
        onSkipped?.call();
      },
    );
    await _interstitialAd!.show();
    return true;
  }

  // ─── Rewarded ads ─────────────────────────────────────────────────────────

  Future<void> _loadRewarded() async {
    _rewardedReady = false;
    rewardedReadyNotifier.value = false;
    await RewardedAd.load(
      adUnitId: AdConfig.rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedReady = true;
          rewardedReadyNotifier.value = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              noteFullScreenEnded();
              ad.dispose();
              _rewardedAd = null;
              _rewardedReady = false;
              rewardedReadyNotifier.value = false;
              _loadRewarded();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
              _rewardedReady = false;
              rewardedReadyNotifier.value = false;
              _loadRewarded();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _rewardedReady = false;
          rewardedReadyNotifier.value = false;
          Future.delayed(const Duration(seconds: 30), _loadRewarded);
        },
      ),
    );
  }

  bool get isRewardedReady => _rewardedReady && _rewardedAd != null;

  /// Show rewarded ad. [onRewarded] fires with coin/fruit amounts if earned.
  Future<void> showRewarded({
    required void Function(int coins, int fruit) onRewarded,
    VoidCallback? onNotReady,
    VoidCallback? onDismissed,
  }) async {
    if (!isRewardedReady) {
      onNotReady?.call();
      return;
    }
    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        onRewarded(AdConfig.rewardedCoinAmount, AdConfig.rewardedFruitAmount);
      },
    );
    onDismissed?.call();
  }

  // ─── App Open ads ─────────────────────────────────────────────────────────

  Future<void> _loadAppOpen() async {
    _appOpenReady = false;
    await AppOpenAd.load(
      adUnitId: AdConfig.appOpenId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _appOpenReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              noteFullScreenEnded();
              ad.dispose();
              _appOpenAd = null;
              _appOpenReady = false;
              _loadAppOpen();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _appOpenAd = null;
              _appOpenReady = false;
              _loadAppOpen();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _appOpenReady = false;
        },
      ),
    );
  }

  /// Offer an App Open ad. [awayFor] is null on a cold start. Does nothing
  /// unless AdPolicy allows it right now.
  Future<void> maybeShowAppOpen({Duration? awayFor}) async {
    // Cold start: the ad is usually still loading when the splash ends, so
    // give it a few seconds (the player is on the main menu meanwhile).
    if (awayFor == null) {
      for (var i = 0; i < 12 && !(_appOpenReady && _appOpenAd != null); i++) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
    }
    final ok = AdPolicy.canShowApppOpen(
      adReady: _appOpenReady && _appOpenAd != null,
      now: DateTime.now(),
      lastShown: _lastAppOpenShown,
      firstLaunchEver: _firstLaunchEver,
      inGameplay: inGameplay,
      lastFullScreenEnd: _lastFullScreenEnd,
      suppressUntil: _suppressAppOpenUntil,
      awayFor: awayFor,
    );
    if (!ok) return;
    _lastAppOpenShown = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _kAppOpenLastShown, _lastAppOpenShown!.millisecondsSinceEpoch);
    await _appOpenAd!.show();
  }

  /// A full-screen ad (any type) just closed: App Open stays quiet briefly.
  void noteFullScreenEnded() => _lastFullScreenEnd = DateTime.now();

  /// The player is arriving via a notification tap: don't greet them with
  /// an ad on top of where they are headed.
  void noteNotificationLaunch() => _suppressAppOpenUntil =
      DateTime.now().add(const Duration(seconds: 30));

  // ─── Cleanup ──────────────────────────────────────────────────────────────

  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _appOpenAd?.dispose();
  }
}
