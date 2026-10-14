// ============================================================
// ad_policy.dart
//
// The rules for WHEN an ad may be shown, as pure functions (no SDK, no
// clock of their own) so they can be unit-tested. AdService feeds them the
// current state. Keeping the rules here also keeps them in one reviewable
// place: they encode AdMob's placement policies and the player-experience
// decisions agreed with the client.
// ============================================================

import 'ad_config.dart';

class AdPolicy {
  AdPolicy._();

  /// Interstitials: only at a natural break (the caller guarantees that — we
  /// show them when the player taps Try Again, never mid-game), and never
  ///  - in a player's first [AdConfig.interstitialFirstGamesFree] games,
  ///  - right after the run that earned a raffle entry (the celebration
  ///    should not be followed by an ad),
  ///  - more often than every [AdConfig.interstitialEveryNGames] games or
  ///    [AdConfig.interstitialCooldownSeconds] seconds.
  static bool canShowInterstitial({
    required bool adReady,
    required int totalGameOvers,
    required int gamesSinceLast,
    required DateTime? lastShown,
    required DateTime now,
    bool suppressedThisRun = false,
  }) {
    if (!adReady || suppressedThisRun) return false;
    if (totalGameOvers <= AdConfig.interstitialFirstGamesFree) return false;
    if (gamesSinceLast < AdConfig.interstitialEveryNGames) return false;
    if (lastShown != null &&
        now.difference(lastShown).inSeconds <
            AdConfig.interstitialCooldownSeconds) {
      return false;
    }
    return true;
  }

  /// App Open ads: on a cold start (after the splash) or when returning
  /// after a long absence, never
  ///  - on the player's first ever launch,
  ///  - over gameplay (running or paused),
  ///  - straight after another full-screen ad, or after a notification tap
  ///    (the player is heading somewhere specific),
  ///  - more often than every [AdConfig.appOpenMinGapHours] hours.
  /// [awayFor] is null for a cold start.
  static bool canShowApppOpen({
    required bool adReady,
    required DateTime now,
    required DateTime? lastShown,
    required bool firstLaunchEver,
    required bool inGameplay,
    required DateTime? lastFullScreenEnd,
    required DateTime? suppressUntil,
    Duration? awayFor,
  }) {
    if (!adReady || firstLaunchEver || inGameplay) return false;
    if (awayFor != null &&
        awayFor < const Duration(hours: AdConfig.appOpenMinAwayHours)) {
      return false;
    }
    if (suppressUntil != null && now.isBefore(suppressUntil)) return false;
    if (lastFullScreenEnd != null &&
        now.difference(lastFullScreenEnd).inSeconds <
            AdConfig.appOpenQuietAfterFullScreenSeconds) {
      return false;
    }
    if (lastShown != null &&
        now.difference(lastShown) <
            const Duration(hours: AdConfig.appOpenMinGapHours)) {
      return false;
    }
    return true;
  }
}
