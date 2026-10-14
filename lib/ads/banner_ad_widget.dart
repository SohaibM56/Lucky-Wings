import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_service.dart';

/// A self-managing banner ad widget.
/// Creates and loads its own BannerAd, disposes on unmount.
/// Shows a slim placeholder while the ad loads.
///
/// Usage:
///   BannerAdWidget()                    // standard 320x50
///   BannerAdWidget(size: AdSize.leaderboard)  // 728x90
class BannerAdWidget extends StatefulWidget {
  final AdSize size;
  final EdgeInsets margin;

  const BannerAdWidget({
    Key? key,
    this.size   = AdSize.banner,
    this.margin = EdgeInsets.zero,
  }) : super(key: key);

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    AdService.instance.adsEnabled.addListener(_maybeLoad);
    _maybeLoad();
  }

  /// Requests the banner only once consent allows ads.
  void _maybeLoad() {
    if (_ad != null || !AdService.instance.adsEnabled.value) return;
    _ad = AdService.instance.createBanner(
      size: widget.size,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _loaded = false);
        },
      ),
    );
    _ad!.load();
  }

  @override
  void dispose() {
    AdService.instance.adsEnabled.removeListener(_maybeLoad);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) {
      // Slim placeholder so layout doesn't jump when ad loads
      return SizedBox(
        height: widget.size.height.toDouble(),
        child: Container(color: Colors.black12),
      );
    }
    return Container(
      margin: widget.margin,
      alignment: Alignment.center,
      width:  _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}

/// Adaptive banner that fills the full screen width.
/// Recommended over fixed-size banners for modern AdMob policies.
class AdaptiveBannerWidget extends StatefulWidget {
  const AdaptiveBannerWidget({Key? key}) : super(key: key);

  @override
  State<AdaptiveBannerWidget> createState() => _AdaptiveBannerWidgetState();
}

class _AdaptiveBannerWidgetState extends State<AdaptiveBannerWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ad == null) _loadAd();
  }

  Future<void> _loadAd() async {
    final width = MediaQuery.of(context).size.width.truncate();
    final adSize = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (adSize == null || !mounted) return;

    _ad = BannerAd(
      adUnitId: AdService.instance.createBanner().adUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) { if (mounted) setState(() => _loaded = true); },
        onAdFailedToLoad: (ad, _) { ad.dispose(); },
      ),
    );
    await _ad!.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox(height: 50);
    return SizedBox(
      width:  _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
