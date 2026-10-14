import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_service.dart';

/// A native ad in Google's "small" template (headline, icon, call to action,
/// "Ad" badge and AdChoices are supplied by the SDK, as policy requires).
/// Collapses to nothing until an ad has loaded, or if loading fails, so a
/// missing ad never leaves a hole or an empty frame in a list.
class NativeAdWidget extends StatefulWidget {
  final EdgeInsets margin;
  const NativeAdWidget({
    Key? key,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  }) : super(key: key);

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    AdService.instance.adsEnabled.addListener(_maybeLoad);
    _maybeLoad();
  }

  /// Requests the ad only once consent allows ads.
  void _maybeLoad() {
    if (_ad != null || !AdService.instance.adsEnabled.value) return;
    _ad = AdService.instance.createNative(
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _ad = null;
          if (mounted) setState(() => _loaded = false);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    AdService.instance.adsEnabled.removeListener(_maybeLoad);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return Container(
      margin: widget.margin,
      height: 120,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: AdWidget(ad: _ad!),
    );
  }
}
