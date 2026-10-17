// ============================================================
// ad_config.dart
//
// Central location for ALL ad unit IDs.
//
// HOW TO GO LIVE:
//   1. Create your AdMob account at admob.google.com
//   2. Create an App for iOS and Android and 5 ad units per platform
//   3. Paste the real IDs into the _android*Prod / _ios*Prod constants below
//      (and the iOS app id into ios/Runner/Info.plist -> GADApplicationIdentifier)
//   4. Build a release: `flutter build appbundle`. That's it — there is no
//      flag to flip. Live ads switch on automatically in release builds once
//      every ID for the platform is filled in.
//
// WHEN TEST ADS ARE USED (Google's official test units, always safe):
//   - every debug / profile build,
//   - any build made with --dart-define=TEST_ADS=true (e.g. a QA release),
//   - any build where a production ID is still the XXXX placeholder, so a
//     release can never go out asking AdMob for ads with a placeholder ID.
//
// NEVER click live ads yourself and never ask players to — that is invalid
// traffic and can get the AdMob account suspended.
// ============================================================

import 'dart:io';
import 'package:flutter/foundation.dart';

class AdConfig {
  // ─── Test / live switch ───────────────────────────────────────────────────
  static const bool _forceTestAds = bool.fromEnvironment('TEST_ADS');

  /// True when the Android/iOS production IDs for the current platform have
  /// all been filled in.
  static bool get liveIdsConfigured => [
        if (Platform.isIOS) ...[
          _iosBannerProd, _iosInterstitialProd, _iosRewardedProd,
          _iosNativeProd, _iosAppOpenProd,
        ] else ...[
          _androidBannerProd, _androidInterstitialProd, _androidRewardedProd,
          _androidNativeProd, _androidAppOpenProd,
        ]
      ].every((id) => !id.contains('XXXX'));

  static bool get useTestAds =>
      kDebugMode || _forceTestAds || !liveIdsConfigured;

  // ─── Test Ad Unit IDs (Google official test IDs — safe to use) ───────────
  // Google publishes separate sample units per platform.
  static String get _testBanner => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/2934735716'
      : 'ca-app-pub-3940256099942544/6300978111';
  static String get _testInterstitial => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/4411468910'
      : 'ca-app-pub-3940256099942544/1033173712';
  static String get _testRewarded => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/1712485313'
      : 'ca-app-pub-3940256099942544/5224354917';
  static String get _testNative => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/3986624511'
      : 'ca-app-pub-3940256099942544/2247696110';
  static String get _testAppOpen => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/5575463023'
      : 'ca-app-pub-3940256099942544/9257395921';

  // ─── Your Production Ad Unit IDs ─────────────────────────────────────────
  // iOS — paste from admob.google.com → Apps → Ad units
  static const _iosBannerProd       = 'ca-app-pub-1191678511602281/7974914623';
  static const _iosInterstitialProd = 'ca-app-pub-1191678511602281/2739819685';
  static const _iosRewardedProd     = 'ca-app-pub-1191678511602281/1426738014';
  static const _iosNativeProd       = 'ca-app-pub-1191678511602281/3057629868';
  static const _iosAppOpenProd      = 'ca-app-pub-1191678511602281/9431466528';

  // Android — paste from admob.google.com → Apps → Ad units
  static const _androidBannerProd       = 'ca-app-pub-1191678511602281/4785644508';
  static const _androidInterstitialProd = 'ca-app-pub-1191678511602281/1346846961';
  static const _androidRewardedProd     = 'ca-app-pub-1191678511602281/8047986688';
  static const _androidNativeProd       = 'ca-app-pub-1191678511602281/8717150650';
  static const _androidAppOpenProd      = 'ca-app-pub-1191678511602281/9328533907';

  // ─── Getters (auto-select test vs prod by platform) ───────────────────────
  static String get bannerId {
    if (useTestAds) return _testBanner;
    return Platform.isIOS ? _iosBannerProd : _androidBannerProd;
  }

  static String get interstitialId {
    if (useTestAds) return _testInterstitial;
    return Platform.isIOS ? _iosInterstitialProd : _androidInterstitialProd;
  }

  static String get rewardedId {
    if (useTestAds) return _testRewarded;
    return Platform.isIOS ? _iosRewardedProd : _androidRewardedProd;
  }

  static String get nativeId {
    if (useTestAds) return _testNative;
    return Platform.isIOS ? _iosNativeProd : _androidNativeProd;
  }

  static String get appOpenId {
    if (useTestAds) return _testAppOpen;
    return Platform.isIOS ? _iosAppOpenProd : _androidAppOpenProd;
  }

  // ─── Frequency caps ───────────────────────────────────────────────────────
  /// Show interstitial every N game overs (not every single one)
  static const int interstitialEveryNGames = 3;

  /// Minimum seconds between two interstitials
  static const int interstitialCooldownSeconds = 60;

  /// Reward coins given for watching a rewarded ad
  static const int rewardedCoinAmount = 50;

  /// Reward fruit given for watching a rewarded ad
  static const int rewardedFruitAmount = 30;

  /// No interstitial in a player's first N game overs (first impressions).
  static const int interstitialFirstGamesFree = 2;

  // ─── App Open ─────────────────────────────────────────────────────────────
  /// Minimum hours between two App Open ads.
  static const int appOpenMinGapHours = 4;

  /// On resume, only show after being away at least this long.
  static const int appOpenMinAwayHours = 4;

  /// Stay quiet this long after any other full-screen ad.
  static const int appOpenQuietAfterFullScreenSeconds = 20;

  // ─── Audience / content ───────────────────────────────────────────────────
  /// Highest ad content rating we accept (G, PG, T, MA). The app has a prize
  /// raffle and a general audience, so keep it family-friendly.
  static const String maxAdContentRating = 'PG';

  /// Show a native ad after every N leaderboard rows.
  static const int nativeEveryNRows = 8;
}
