import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'ad_service.dart';

part 'ad_state.dart';

class AdCubit extends Cubit<AdState> {
  AdCubit() : super(const AdState()) {
    _adService.rewardedReadyNotifier.addListener(_onRewardedReadyChanged);
  }

  final _adService = AdService.instance;

  void _onRewardedReadyChanged() {
    if (isClosed) return;
    emit(state.copyWith(rewardedReady: _adService.rewardedReadyNotifier.value));
  }

  @override
  Future<void> close() {
    _adService.rewardedReadyNotifier.removeListener(_onRewardedReadyChanged);
    return super.close();
  }

  Future<void> initialize() async {
    emit(state.copyWith(status: AdStatus.loading));
    // After the first frame: the consent form needs a screen to show on.
    await WidgetsBinding.instance.endOfFrame;
    await _adService.initialize();
    emit(state.copyWith(
      status: AdStatus.ready,
      interstitialReady: _adService.canShowInterstitial,
      rewardedReady: _adService.isRewardedReady,
    ));
  }

  // ─── Called by game on every game over ────────────────────────────────────

  /// Pass [onContinue] — called after the ad is dismissed (or skipped).
  /// This ensures game flow resumes correctly either way.
  Future<void> onGameOver({
    required void Function() onContinue,
    bool skipInterstitial = false,
  }) async {
    _adService.recordGameOver();
    if (skipInterstitial) _adService.suppressNextInterstitial();
    emit(state.copyWith(interstitialReady: _adService.canShowInterstitial));

    final shown = await _adService.showInterstitialIfReady(
      onDismissed: onContinue,
      onSkipped: onContinue,
    );

    if (!shown) onContinue();
  }

  // ─── Rewarded ad (player taps "Watch Ad" button) ──────────────────────────

  Future<void> showRewardedAd({
    required void Function(int coins, int fruit) onRewarded,
    required void Function() onNotReady,
  }) async {
    if (!_adService.isRewardedReady) {
      emit(state.copyWith(rewardedReady: false));
      onNotReady();
      return;
    }

    emit(state.copyWith(status: AdStatus.showing));
    await _adService.showRewarded(
      onRewarded: (coins, fruit) {
        emit(state.copyWith(
          status: AdStatus.ready,
          lastRewardCoins: coins,
          lastRewardFruit: fruit,
          rewardedReady: false,
        ));
        onRewarded(coins, fruit);
      },
      onDismissed: () {
        emit(state.copyWith(
          status: AdStatus.ready,
          rewardedReady: _adService.isRewardedReady,
        ));
      },
      onNotReady: () {
        emit(state.copyWith(status: AdStatus.ready, rewardedReady: false));
        onNotReady();
      },
    );
  }

  // ─── App open (call when app comes to foreground) ─────────────────────────

  Future<void> onAppResume({Duration? awayFor}) async {
    await _adService.maybeShowAppOpen(awayFor: awayFor);
  }

  void refreshState() {
    emit(state.copyWith(
      interstitialReady: _adService.canShowInterstitial,
      rewardedReady: _adService.isRewardedReady,
    ));
  }
}
