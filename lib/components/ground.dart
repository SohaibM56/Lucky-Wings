import 'dart:ui' as ui;
import 'package:flip_flop/components/components.dart';
import 'package:flip_flop/game_manager.dart';
import 'package:flutter/painting.dart';

class Ground extends Component {
  Ground({
    required Sprite sprite,
    double x = 0,
    double y = 0,
    this.frame = 0,
  }) : super(sprite: sprite, x: x, y: y);

  int frame;

  @override
  void draw(ui.Canvas canvas, ui.Size size) {
    this.y = size.height - this.height;
    canvas.drawImage(this.sprite.path.first, Offset(x, y), Paint());
  }

  @override
  void update(GameManager gameManager, int frames) {
    if (gameManager.getGameState() != GameState.play) return;
    this.x -= 2; // -2,-3,..
    this.x = this.x < -(this.width ~/ 2) ? 0 : this.x;
  }

  @override
  double get height => this.sprite.height.toDouble();

  @override
  double get width => this.sprite.width.toDouble();
}
