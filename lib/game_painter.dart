import 'package:flip_flop/components/component.dart';
import 'package:flutter/material.dart';

class GamePainter extends CustomPainter {
  GamePainter({
    this.components = const [],
    required ValueNotifier<int> valueNotifier,
  }) : super(repaint: valueNotifier);

  final List<Component> components;

  @override
  void paint(Canvas canvas, Size size) =>
      components.forEach((component){
        if(component.shouldPaint) component.draw(canvas, size);
      });

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
