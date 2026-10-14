import 'package:flutter/material.dart';

class CustomButton extends StatefulWidget {
  const CustomButton({
    this.height = 60,
    this.onPressed,
    this.clickImagePath = 'assets/images/buttons/click_btn.png',
    this.normalImagePath = 'assets/images/buttons/normal_btn.png',
    this.builder,
  });

  final double height;
  final VoidCallback? onPressed;
  final String clickImagePath;
  final String normalImagePath;
  final Function(bool isTap)? builder;

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool isTapped = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onPressed?.call(),
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            isTapped ? widget.clickImagePath : widget.normalImagePath,
            fit: BoxFit.cover,
            height: widget.height,
          ),
          widget.builder?.call(isTapped) ?? SizedBox(height: 0),
        ],
      ),
    );
  }
}
