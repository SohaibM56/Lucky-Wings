import 'package:flip_flop/ads/ad_config.dart';
import 'package:flip_flop/ads/ad_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 14, 12);

  bool interstitial({
    bool ready = true,
    int total = 10,
    int since = 3,
    DateTime? last,
    bool suppressed = false,
  }) =>
      AdPolicy.canShowInterstitial(
        adReady: ready,
        totalGameOvers: total,
        gamesSinceLast: since,
        lastShown: last,
        now: now,
        suppressedThisRun: suppressed,
      );

  group('interstitial', () {
    test('allowed at a natural break once all limits are met', () {
      expect(interstitial(), isTrue);
    });
    test('never without a loaded ad', () {
      expect(interstitial(ready: false), isFalse);
    });
    test('first games are ad-free, even across app restarts', () {
      expect(interstitial(total: 1, since: 3), isFalse);
      expect(interstitial(total: AdConfig.interstitialFirstGamesFree,
          since: 3), isFalse);
      expect(interstitial(total: AdConfig.interstitialFirstGamesFree + 1,
          since: 3), isTrue);
    });
    test('only every N games', () {
      expect(interstitial(since: AdConfig.interstitialEveryNGames - 1),
          isFalse);
    });
    test('cooldown between two interstitials', () {
      expect(interstitial(last: now.subtract(const Duration(seconds: 30))),
          isFalse);
      expect(
          interstitial(
              last: now.subtract(Duration(
                  seconds: AdConfig.interstitialCooldownSeconds + 1))),
          isTrue);
    });
    test('not right after the run that earned a raffle entry', () {
      expect(interstitial(suppressed: true), isFalse);
    });
  });

  group('app open', () {
    bool appOpen({
      bool ready = true,
      DateTime? lastShown,
      bool first = false,
      bool inGame = false,
      DateTime? lastFullScreen,
      DateTime? suppressUntil,
      Duration? away,
    }) =>
        AdPolicy.canShowApppOpen(
          adReady: ready,
          now: now,
          lastShown: lastShown,
          firstLaunchEver: first,
          inGameplay: inGame,
          lastFullScreenEnd: lastFullScreen,
          suppressUntil: suppressUntil,
          awayFor: away,
        );

    test('cold start is allowed when nothing blocks it', () {
      expect(appOpen(), isTrue);
    });
    test('never on the very first launch', () {
      expect(appOpen(first: true), isFalse);
    });
    test('never over gameplay (running or paused)', () {
      expect(appOpen(inGame: true), isFalse);
    });
    test('never without a loaded ad', () {
      expect(appOpen(ready: false), isFalse);
    });
    test('on resume only after a long absence', () {
      expect(appOpen(away: const Duration(minutes: 20)), isFalse);
      expect(appOpen(away: const Duration(hours: 5)), isTrue);
    });
    test('quiet right after another full-screen ad', () {
      expect(appOpen(lastFullScreen: now.subtract(const Duration(seconds: 5))),
          isFalse);
      expect(
          appOpen(lastFullScreen: now.subtract(const Duration(minutes: 5))),
          isTrue);
    });
    test('quiet after a notification tap', () {
      expect(appOpen(suppressUntil: now.add(const Duration(seconds: 20))),
          isFalse);
      expect(appOpen(suppressUntil: now.subtract(const Duration(seconds: 1))),
          isTrue);
    });
    test('at most once every few hours', () {
      expect(appOpen(lastShown: now.subtract(const Duration(hours: 1))),
          isFalse);
      expect(appOpen(lastShown: now.subtract(const Duration(hours: 5))),
          isTrue);
    });
  });

  group('config', () {
    test('placeholder production IDs force test ads (never ship XXXX)', () {
      expect(AdConfig.liveIdsConfigured, isFalse);
      expect(AdConfig.useTestAds, isTrue);
    });
    test('content rating is family-friendly', () {
      expect(['G', 'PG'], contains(AdConfig.maxAdContentRating));
    });
  });
}
