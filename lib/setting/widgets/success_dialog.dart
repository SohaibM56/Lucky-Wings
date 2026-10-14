import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flip_flop/theme.dart';
import 'package:flip_flop/widgets/widgets.dart';
import 'package:flutter/material.dart';

class SuccessDialog extends StatefulWidget {
  const SuccessDialog({
    Key? key,
    this.title = "",
    this.showTitle = false,
    this.onPressed,
    this.bodyBuilder,
    this.onUse,
  }) : super(key: key);

  final String title;
  final bool showTitle;
  final VoidCallback? onPressed;
  final Function(double width, double height)? bodyBuilder;
  /// When set, the dialog offers a USE button that runs this (equip the
  /// just-unlocked item) next to the plain OK.
  final VoidCallback? onUse;

  @override
  State<SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<SuccessDialog> {
  final confettiController = ConfettiController();

  @override
  void initState() {
    confettiController.play();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width / 1.5;
    double h = MediaQuery.of(context).size.height / 2.3;
    return CustomDialog(
      width: w,
      height: h,
      showCloseButton: false,
      showSecondaryButton: widget.onUse != null,
      secondaryText: "OK",
      showPrimaryButton: true,
      primaryText: widget.onUse != null ? "USE" : "OK",
      title: widget.title,
      showTitle: widget.showTitle,
      // Bound the body between the ribbon and the OK button so the content
      // below can actually be centered in that space (unbounded, it just
      // hugged the top and left a dead gap above the button).
      bodyMargin: 40,
      bodyMarginBottom: 90,
      secondaryButtonPressed: () {
        widget.onPressed?.call();
        Navigator.pop(context);
      },
      primaryButtonPressed: () {
        widget.onPressed?.call();
        Navigator.pop(context);
        widget.onUse?.call();
      },
      bodyWidget: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    Text(
                      "Congratulations",
                      style: TextStyle(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'DiloWorld',
                      ),
                    ),
                    Text("Congratulations", style: buttonDarkStyle)
                  ],
                ),
                if (widget.bodyBuilder != null) ...[
                  const SizedBox(height: 12),
                  widget.bodyBuilder?.call(w, h),
                ],
              ],
            ),
            ConfettiWidget(
              confettiController: confettiController,
              shouldLoop: false,
              blastDirection: -pi / 2,
            ),
            // if (widget.bodyBuilder != null) widget.bodyBuilder?.call(w, h),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    confettiController.dispose();
    super.dispose();
  }
}
