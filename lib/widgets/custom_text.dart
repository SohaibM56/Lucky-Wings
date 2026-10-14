import 'package:flutter/material.dart';
import 'package:flip_flop/utils/utils.dart';

class CustomText extends StatelessWidget {
  const CustomText(
    this.text, {
    this.fontSize = 16,
    this.fontWeight = FontWeight.bold,
    this.fontFamily = 'Chainwhacks',
    this.strokeWidth = .75,
    this.color = Colors.white,
    this.borderColor = wood_smoke,
    this.textAlign,
  });

  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final String fontFamily;
  final double strokeWidth;
  final Color color;
  final Color borderColor;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            color: color,
            fontWeight: fontWeight,
            fontFamily: fontFamily,
          ),
          textAlign: textAlign,
        ),
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            fontFamily: fontFamily,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = borderColor,
          ),
          textAlign: textAlign,
        ),
      ],
    );
  }
}
