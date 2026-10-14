import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../setting/setting.dart';
import 'ad_cubit.dart';

/// "Watch Ad" button that rewards coins or fruit.
/// Shows a loading indicator while the ad is loading.
/// Greys out if no rewarded ad is available.
///
/// Usage:
///   WatchAdButton(label: 'Get 50 Coins', rewardCoins: true)
///   WatchAdButton(label: 'Get 30 Fruit', rewardCoins: false)
class WatchAdButton extends StatelessWidget {
  final String label;
  final bool rewardCoins; // true = coins, false = fruit

  const WatchAdButton({
    Key? key,
    this.label = 'Watch Ad for Reward',
    this.rewardCoins = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdCubit, AdState>(
      builder: (context, adState) {
        final ready   = adState.rewardedReady;
        final loading = adState.status == AdStatus.showing;

        return GestureDetector(
          // Tappable even while the ad is still loading, so a tap always gets
          // an answer ("not ready yet") instead of silently doing nothing.
          onTap: loading ? null : () => _onTap(context),
          child: AnimatedOpacity(
            opacity: ready ? 1.0 : 0.45,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: ready
                    ? const LinearGradient(
                        colors: [Color(0xFF00D4FF), Color(0xFF0099BB)],
                      )
                    : null,
                color: ready ? null : Colors.white12,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ready
                      ? const Color(0xFF00D4FF)
                      : Colors.white24,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  else
                    const Icon(Icons.play_circle_outline,
                        color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    loading ? 'Loading...' : label,
                    style: const TextStyle(
                      fontFamily: 'DiloWorld',
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _onTap(BuildContext context) {
    context.read<AdCubit>().showRewardedAd(
      onRewarded: (coins, fruit) {
        // Apply the reward to the player's wallet
        context.read<SettingCubit>().getReward(
          value: rewardCoins ? coins : fruit,
          isCoin: rewardCoins,
          onSuccess: () {
            _showRewardSnack(context, coins, fruit);
          },
        );
      },
      onNotReady: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ad not ready yet — try again in a moment!'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }

  void _showRewardSnack(BuildContext context, int coins, int fruit) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF4ECB71),
        content: Row(children: [
          const Icon(Icons.star, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            rewardCoins
                ? '+$coins Coins earned!'
                : '+$fruit Fruit earned!',
            style: const TextStyle(
                fontFamily: 'DiloWorld',
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
        ]),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
