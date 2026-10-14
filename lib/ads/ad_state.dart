part of 'ad_cubit.dart';

enum AdStatus { initial, loading, ready, showing, error }

class AdState extends Equatable {
  const AdState({
    this.status            = AdStatus.initial,
    this.interstitialReady = false,
    this.rewardedReady     = false,
    this.lastRewardCoins   = 0,
    this.lastRewardFruit   = 0,
  });

  final AdStatus status;
  final bool     interstitialReady;
  final bool     rewardedReady;
  final int      lastRewardCoins;
  final int      lastRewardFruit;

  @override
  List<Object?> get props => [
        status, interstitialReady, rewardedReady,
        lastRewardCoins, lastRewardFruit,
      ];

  AdState copyWith({
    AdStatus? status,
    bool?     interstitialReady,
    bool?     rewardedReady,
    int?      lastRewardCoins,
    int?      lastRewardFruit,
  }) {
    return AdState(
      status            : status            ?? this.status,
      interstitialReady : interstitialReady ?? this.interstitialReady,
      rewardedReady     : rewardedReady     ?? this.rewardedReady,
      lastRewardCoins   : lastRewardCoins   ?? this.lastRewardCoins,
      lastRewardFruit   : lastRewardFruit   ?? this.lastRewardFruit,
    );
  }
}
