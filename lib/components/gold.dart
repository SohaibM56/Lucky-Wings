import 'dart:ui';

import 'package:flip_flop/components/components.dart';
import 'package:flip_flop/game_manager.dart';

class Gold extends Item {
  Gold({
    required Sprite sprite,
    required List<Image> effect,
    double x = 0,
    double y = 0,
    this.frame = 0,
  }) : super(sprite: sprite, effect: effect, x: x, y: y);

  int frame;

  @override
  void draw(Canvas canvas, Size size) {
    if (!shouldPaint) return;
    if (!isCollected) {
      canvas.drawImage(this.sprite.path[this.frame], Offset(x, y), Paint());
    } else {
      canvas.drawImage(this.effect[this.frame], Offset(x, y), Paint());
      if (this.frame == this.effect.length - 1) shouldPaint = false;
    }
  }

  @override
  void update(GameManager gameManager, int frames) {
    if (!shouldPaint) return;
    switch (gameManager.getGameState()) {
      case GameState.play:
        this.frame += (frames % 5 == 0) ? 1 : 0;
        break;
      case GameState.gameOver:
        this.shouldPaint = false;
        break;
      default:
        break;
    }

    if (isCollected) {
      this.frame = this.frame % this.effect.length;
    } else {
      this.frame = this.frame % this.sprite.path.length;
    }
  }

  @override
  Gold copyWith({
    Sprite? sprite,
    List<Item>? items,
    List<Image>? effect,
    double? x,
    double? y,
    int? iat = 0,
    int? netWorth = 0,
    bool? isCollected,
  }) {
    return Gold(
      sprite: sprite ?? this.sprite,
      effect: effect ?? this.effect,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }

  @override
  double get height => this.sprite.height.toDouble();

  @override
  double get width => this.sprite.width.toDouble();

  @override
  void setCollect() {
    this.frame = 0;
    this.isCollected = true;
  }
}
