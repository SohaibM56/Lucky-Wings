import 'package:flutter/material.dart';
import 'package:flip_flop/utils/utils.dart';

class PlainShadowButton extends StatefulWidget {
  final Color borderColor;
  final Color shadowColor;
  final Color color;
  final VoidCallback? callback;
  final double? size;
  final double? height;
  final Function(bool isTapped) bodyBuilder;

  const PlainShadowButton({
    required this.borderColor,
    required this.shadowColor,
    required this.color,
    this.size,
    this.height,
    this.callback,
    required this.bodyBuilder,
  });

  @override
  State<PlainShadowButton> createState() => _PlainShadowButtonState();
}

class _PlainShadowButtonState extends State<PlainShadowButton> {
  bool isTapped = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.callback,
      onTapDown: (event) {
        setState(() {
          isTapped = true;
        });
      },
      onTapCancel: () {
        setState(() {
          isTapped = false;
        });
      },
      onTapUp: (event) {
        setState(() {
          isTapped = false;
        });
      },
      child: Container(
        width: widget.size != null
            ? widget.size
            : MediaQuery.of(context).size.width,
        height: widget.height != null ? widget.height : 48,
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Center(child: widget.bodyBuilder.call(isTapped)),
        decoration: ShapeDecoration(
          shadows: [
            BoxShadow(
              color: isTapped ? selago : widget.shadowColor,
              offset: Offset(
                0.0, // Move to right 10  horizontally
                4.0, // Move to bottom 5 Vertically
              ),
            )
          ],
          color: widget.color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(
              color: isTapped ? selago : widget.borderColor,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}
