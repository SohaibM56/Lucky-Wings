import 'dart:math';
import 'dart:ui' as ui;
import 'package:flip_flop/components/components.dart';
import 'package:flip_flop/game_manager.dart';
import 'package:flutter/painting.dart';

class Pipe extends Obstacle {
  Pipe({
    required Sprite sprite,
    this.gap = 115,
  }) : super(sprite: sprite);

  /// space between 2 pipes
  int gap;

  double _dx = 2;

  @override
  void draw(ui.Canvas canvas, ui.Size size) {
    for (int i = 0; i < obstacles.length; i++) {
      final p = this.obstacles[i];
      ui.Image topSprite = this.sprite.path[0];
      ui.Image botSprite = this.sprite.path[1];

      double xTop = p.x;
      double yTop = p.y;

      /// draw top pipe
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(
          xTop,
          yTop,
          topSprite.width.toDouble(),
          topSprite.height.toDouble(),
        ),
        image: topSprite,
        fit: BoxFit.fill,
      );

      double xBot = p.x;
      double yBot = (p.y + topSprite.height) + this.gap;

      /// draw bot pipe
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(
          xBot,
          yBot,
          topSprite.width.toDouble(),
          topSprite.height.toDouble(),
        ),
        image: botSprite,
        fit: BoxFit.fill,
      );
    }
  }

  @override
  void update(GameManager gameManager, int frames) {

    if (gameManager.getGameState() != GameState.play) return;
    if (frames % 100 == 0) {
      double _x = gameManager.getScreenSize().width;
      double _y = -150 * min(Random().nextDouble() + 1, 1.8);
      this.obstacles.add(Pipe(sprite: sprite, gap: gap)
        ..x = _x
        ..y = _y);
    }
    this.obstacles.forEach((p) => p.x -= _dx);
    if (this.obstacles.isNotEmpty &&
        this.obstacles[0].x < -this.sprite.width) {
      this.obstacles.removeAt(0);
      gameManager.setPipeStatus(true);
    }
  }
}
