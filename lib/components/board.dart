import 'dart:math';
import 'dart:ui' as ui;
import 'package:flip_flop/components/components.dart';
import 'package:flip_flop/game_manager.dart';
import 'package:flutter/material.dart';

class Board extends Component {
  Board({
    Sprite sprite = Sprite.empty,
    double x = 0,
    double y = 0,
  }) : super(sprite: sprite, x: x, y: y);

  int score = 0;

  List<Item> items = [];

  GameState gameState = GameState.ready;

  @override
  void draw(ui.Canvas canvas, ui.Size size) {
    // draw frame
    final paint = Paint()
      ..strokeWidth = 2
      ..style = ui.PaintingStyle.stroke
      ..color = Colors.black;
    canvas.drawRect(
        Rect.fromPoints(Offset(0, 0), Offset(size.width, size.height)), paint);
    // draw score
    switch (gameState) {
      case GameState.play:
        items.forEach((item) => item.draw(canvas, size));
        break;
      default:
        break;
    }
  }

  @override
  void update(GameManager gameManager, int frames) {
    gameState = gameManager.getGameState();
    if (gameState == GameState.gameOver || gameState == GameState.ready) return;
    score = gameManager.readScore();
    items.removeWhere((item) => !item.shouldPaint);
    items.forEach((item) => item.update(gameManager, frames));

    if (frames % 180 == 0 && frames % 120 != 0) {
      int _itemsPerFrame = Random().nextInt(5) + 1;
      int _itemType = _itemsPerFrame == 1
          ? Random().nextInt(2) + ItemName.magnet.index
          : Random().nextInt(ItemName.watermelon.index + 1);

      if (_itemsPerFrame == 1) {
        Item item = GameManager.gameItems[_itemType].copyWith();
        item.x = gameManager.getScreenSize().width + item.width / 2;
        item.y = gameManager.getScreenSize().height / 2 - 100;
        this.items.add(item);
      } else {
        double _x = gameManager.getScreenSize().width;
        double _y = gameManager.getScreenSize().height / 3;
        for (int i = 0; i < _itemsPerFrame; i++) {
          Item item = GameManager.gameItems[_itemType].copyWith();
          item.x = _x + item.width / 2;
          item.y = _y + (item.height + GameManager.itemPaddingSmall) * i;
          this.items.add(item);
        }
      }
    }

    for (int i = 0; i < this.items.length; i++) {
      Item item = items[i];
      item.x -= GameManager.gameSpeed;
    }
    if (this.items.isNotEmpty && this.items[0].x < -50) {
      this.items.removeAt(0);
    }

  }

  void drawItems(ui.Canvas canvas, ui.Size size) {}

  @override
  double get height => this.sprite.height.toDouble();

  @override
  double get width => this.sprite.width.toDouble();

  void reset() => this.items.clear();

}
