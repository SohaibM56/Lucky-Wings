import 'dart:ui' as ui;
import 'package:flip_flop/components/components.dart';
import 'package:flip_flop/game_manager.dart';
import 'package:flip_flop/theme.dart';
import 'package:flip_flop/utils/utils.dart';
import 'package:flutter/material.dart';

class GetReady extends Component {
  GetReady({
    required Sprite sprite,
    this.frame = 0,
  }) : super(sprite: sprite);

  int frame;

  String title = "Tap to Play";

  @override
  void draw(ui.Canvas canvas, ui.Size size) {
    drawReadyText(canvas, size);
    double x = (size.width - this.sprite.width) / 2;
    double y = (size.height - this.sprite.height) / 2 - 20;
    Offset a = new Offset(x, y);
    Offset b = new Offset(x + this.sprite.width, y + x + this.sprite.height);
    paintImage(
      canvas: canvas,
      rect: Rect.fromPoints(a, b),
      image: this.sprite.path[this.frame],
      fit: BoxFit.contain,
    );
  }

  @override
  void update(GameManager gameManager, int frames) {
    if (!shouldPaint) return;
    switch (gameManager.getGameState()) {
      case GameState.pause:
      case GameState.ready:
        gameManager.gameReady();
        this.frame += (frames % 10 == 0) ? 1 : 0;
        this.frame = this.frame % this.sprite.length;
        break;
      default:
        break;
    }
  }

  void drawReadyText(ui.Canvas canvas, ui.Size size) {
    final textStyle1 = TextStyle(
      letterSpacing: 2.0,
      fontFamily: fontFamily,
      fontWeight: FontWeight.bold,
      fontSize: 32,
      color: lightening_yellow,
    );
    final textSpan1 = TextSpan(
      text: title,
      style: textStyle1,
    );
    final textPainter1 = TextPainter(
      text: textSpan1,
      textDirection: TextDirection.ltr,
    );
    textPainter1.layout(
      minWidth: 0,
      maxWidth: size.width,
    );

    ///
    final textStyle2 = TextStyle(
      letterSpacing: 2.0,
      fontFamily: fontFamily,
      fontWeight: FontWeight.bold,
      fontSize: 32,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = white,
        // ..color = Color(0xff346434),
    );
    final textSpan2 = TextSpan(
      text: title,
      style: textStyle2,
    );
    final textPainter2 = TextPainter(
      text: textSpan2,
      textDirection: TextDirection.ltr,
    );
    textPainter2.layout(
      minWidth: 0,
      maxWidth: size.width,
    );

    final xCenter = ((size.width - textPainter1.width) / 2);
    final yCenter = (size.height - textPainter1.height) / 2 + 20;
    final offset = Offset(xCenter, yCenter);
    textPainter1.paint(canvas, offset);
    textPainter2.paint(canvas, offset);
  }

  @override
  double get height => this.sprite.height.toDouble();

  @override
  double get width => this.sprite.width.toDouble();
}
