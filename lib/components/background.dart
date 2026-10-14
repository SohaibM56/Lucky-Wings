import 'dart:ui' as ui;
import 'package:flip_flop/components/components.dart';
import 'package:flutter/painting.dart';
import 'package:flip_flop/game_manager.dart';

class Background extends Component {
  Background({
    required Sprite sprite,
    double x = 0,
    double y = 0,
    this.frame = 0,
  }) : super(sprite: sprite, x: x, y: y);

  int frame;

  @override
  void draw(ui.Canvas canvas, ui.Size size) {
    this.y = size.height - 500;
    Offset a = Offset(0, 0);
    Offset b = Offset(size.width, size.height);
    paintImage(
      canvas: canvas,
      rect: Rect.fromPoints(a, b),
      image: this.sprite.path[this.frame],
      fit: BoxFit.cover,
    );
  }

  @override
  void update(GameManager gameManager, int frames) {
    switch (gameManager.getGameState()) {
      case GameState.ready:
        this.frame += (frames % 10 == 0) ? 1 : 0;
        break;
      case GameState.play:
        this.frame += (frames % 5 == 0) ? 1 : 0;
        break;
      case GameState.gameOver:
        this.frame = 0;
        break;
      default:
        break;
    }
    this.frame = this.frame % this.sprite.length;
  }

  @override
  double get height => this.sprite.height.toDouble();

  @override
  double get width => this.sprite.width.toDouble();

}
