import 'package:flip_flop/ads/ad_service.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flip_flop/setting/setting.dart';
import 'package:flip_flop/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as im;
import 'package:flutter/services.dart' show rootBundle, SystemUiOverlayStyle;

const primary_color = const Color(0xff92e010);
const white = Color(0xFFFFFFFF);
const athens_gray = Color(0xFFF4F5F7);
const lightening_yellow = Color(0xFFFFBD12);
const flamingo = Color(0xFFF95A2C);
const black = Color(0xFF000000);
const wood_smoke = Color(0xFF18191F);
const selago = Color(0xFFE9E7FC);

// Transparent status bar so it blends with whatever's behind it — pick the
// variant whose icon color contrasts with that screen's background.
const transparentStatusBarLight = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

const transparentStatusBarDark = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
);

class GameUtils {
  static Future<ui.Image> loadImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final list = Uint8List.view(data.buffer);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(list, completer.complete);
    return completer.future;
  }

  static Future<ui.Image> loadImageFitSize(
      String imageAssetPath, int width, int height) async {
    final ByteData assetImageByteData = await rootBundle.load(imageAssetPath);
    im.Image? baseSizeImage =
        im.decodeImage(assetImageByteData.buffer.asUint8List());
    im.Image resizeImage =
        im.copyResize(baseSizeImage!, width: width, height: height);
    ui.Codec codec = await ui
        .instantiateImageCodec(Uint8List.fromList(im.encodePng(resizeImage)));
    ui.FrameInfo frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }

  // A full-screen ad covers the whole app, so a success dialog shown while
  // one is up auto-hides behind it (it only lives a few seconds) and the
  // player never sees it — rewards are granted at the moment the ad's reward
  // fires, which is before the ad is closed. Dialogs requested during an ad
  // are held and shown as soon as it's dismissed.
  static bool _fullScreenAdShowing = false;
  static VoidCallback? _pendingAfterAd;

  static void fullScreenAdShown() => _fullScreenAdShowing = true;

  static void fullScreenAdDismissed() {
    _fullScreenAdShowing = false;
    AdService.instance.noteFullScreenEnded();
    final pending = _pendingAfterAd;
    _pendingAfterAd = null;
    pending?.call();
  }

  static void showSuccessDialog(
    BuildContext context, {
    bool showTitle = false,
    String title = "Congratulations",
    Duration? autoHide,
    Function(double width, double height)? bodyBuilder,
    VoidCallback? onUse,
  }) {
    if (_fullScreenAdShowing) {
      _pendingAfterAd = () => showSuccessDialog(
            context,
            showTitle: showTitle,
            title: title,
            autoHide: autoHide,
            bodyBuilder: bodyBuilder,
            onUse: onUse,
          );
      return;
    }
    late Timer _timer;
    showDialog(
      context: context,
      builder: (_) {
        // A dialog with a USE choice waits for the player instead of
        // vanishing after 2.5 s.
        _timer = Timer(
            autoHide ??
                (onUse != null
                    ? const Duration(minutes: 5)
                    : const Duration(milliseconds: 2500)),
            () => Navigator.of(context).pop());
        return SuccessDialog(
          showTitle: showTitle,
          title: title,
          bodyBuilder: bodyBuilder,
          onUse: onUse,
          onPressed: () {
            if (_timer.isActive) {
              _timer.cancel();
            }
          },
        );
      },
    ).then((val) {
      if (_timer.isActive) {
        _timer.cancel();
      }
    });
  }

  static void showSnackBar(BuildContext context,
      {Duration? autoHide,
      String content = "    Please check your internet connection"}) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          content: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                width: MediaQuery.of(context).size.width,
                height: 75,
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.all(24),
                decoration: ShapeDecoration(
                  shadows: [
                    BoxShadow(color: wood_smoke, offset: Offset(0, 6)),
                  ],
                  shape: RoundedRectangleBorder(
                    side: BorderSide(width: 2, color: wood_smoke),
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  color: white,
                ),
              ),
              CustomText(
                content,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
          duration: autoHide ?? const Duration(seconds: 1),
        ),
      );
  }
}
