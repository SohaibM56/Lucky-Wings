import 'dart:math';
import 'dart:ui' as ui;
import 'package:flip_flop/components/components.dart';
import 'package:flutter/painting.dart';

import '../game_manager.dart';

enum CrateStatus {
  idle,
  movingUp,
  movingDown,
  openClose,
}

class Crate extends Obstacle {
  Crate({
    required Sprite sprite,
    this.quantity = 0,
    this.gap = 130.0,
  }) : super(sprite: sprite);

  int quantity;
  double gap;
  double _dx = 2;
  double _dy = 1;
  double _do = 1;
  Item? ark;

  @override
  void draw(ui.Canvas canvas, ui.Size size) {
    for (int i = 0; i < obstacles.length; i++) {
      Crate topCrate = this.obstacles[i] as Crate;
      double offset = topCrate.crateStatus.hasOffset ? topCrate.threshold : 0;

      /// draw top crates
      drawCrates(canvas, size, topCrate, offset);

      /// draw ark
      if (topCrate.ark != null) {
        topCrate.ark!.draw(canvas, size);
      }

      /// draw bottom crates
      double xBot = topCrate.x;
      double yBot = (topCrate.y + topCrate.height) + topCrate.gap;
      Crate botCrate = Crate(
        sprite: sprite,
        quantity: topCrate.quantity,
      )
        ..x = xBot
        ..y = yBot;
      drawCrates(
        canvas,
        size,
        botCrate,
        -offset,
      );
    }
  }

  @override
  void update(GameManager gameManager, int frames) {
    if (gameManager.getGameState() != GameState.play) return;
    if (frames % 120 == 0) {
      CrateStatus _crateStatus = CrateStatus.idle;
      int _score = gameManager.readScore();
      if (_score > 60) {
        _crateStatus = frames % 480 == 0
            ? CrateStatus.values[Random().nextInt(3) + 1]
            : CrateStatus.idle;
      } else if (_score > 20) {
        _crateStatus = frames % 480 == 0
            ? CrateStatus.values[Random().nextInt(2) + 1]
            : CrateStatus.idle;
      }
      int _maxBox = 6;
      double _x = gameManager.getScreenSize().width;
      double _y = -150 * min(Random().nextDouble() + 1, 1.8);
      Crate _newCrate = Crate(
        sprite: sprite,
        gap: gap,
        quantity: _maxBox,
      )
        ..x = _x
        ..y = _y
        ..crateStatus = _crateStatus;
      if (_crateStatus == CrateStatus.idle) {
        Item ark = GameManager.gameItems[ItemName.gold.index].copyWith();
        ark.x = _newCrate.x + (_newCrate.width - ark.sprite.width) / 2;
        ark.y = _y + _newCrate.height + (gap - ark.sprite.height) / 2;
        _newCrate.ark = ark;
      }
      this.obstacles.add(_newCrate);
    }
    for (int i = 0; i < this.obstacles.length; i++) {
      Crate obstacle = obstacles[i] as Crate;
      obstacle.x -= _dx;
      obstacle.ark?.x -= _dx;
      obstacle.attackByMove();
      obstacle.attackBySqueeze();
      obstacle.ark?.update(gameManager, frames);
    }

    if (this.obstacles.isNotEmpty && this.obstacles[0].x < -this.sprite.width) {
      this.obstacles.removeAt(0);
      gameManager.setPipeStatus(true);
    }
  }

  void drawCrates(ui.Canvas canvas, ui.Size size, Crate crate,
      [double offset = 0]) {
    ui.Image crateSprite = this.sprite.path[0];
    paintImage(
      canvas: canvas,
      rect: Rect.fromPoints(
        Offset(crate.x, crate.y + offset),
        Offset(
          crate.x + crate.width,
          crate.y + offset + crate.height,
        ),
      ),
      alignment: Alignment.topCenter,
      image: crateSprite,
      fit: BoxFit.scaleDown,
      repeat: ImageRepeat.repeatY,
    );
  }

  @override
  double get width => this.sprite.width.toDouble();

  @override
  double get height => this.sprite.height.toDouble() * quantity;

  CrateStatus crateStatus = CrateStatus.idle;

  double threshold = 0;

  void attackByMove() {
    if (this.crateStatus == CrateStatus.idle ||
        this.crateStatus == CrateStatus.openClose) return;
    if (this.crateStatus == CrateStatus.movingDown) {
      if (this.threshold == 150) {
        this.crateStatus = CrateStatus.movingUp;
      } else {
        this.threshold++;
        this.y += _dy;
      }
    }
    if (this.crateStatus == CrateStatus.movingUp) {
      if (this.threshold == 0) {
        this.crateStatus = CrateStatus.movingDown;
      } else {
        this.threshold--;
        this.y -= _dy;
      }
    }
  }

  int vector = -1;

  void attackBySqueeze() {
    if (this.crateStatus != CrateStatus.openClose) return;
    if (threshold <= -50 || (this.threshold - 1 >= this.gap ~/ 2)) {
      vector = -vector;
    }
    vector > 0 ? threshold += _do : threshold -= (_do * 2);
  }
}

extension ExtensionCrate on Crate {
  Crate move(Vector2 v) {
    return Crate(
      sprite: this.sprite,
      quantity: this.quantity,
      gap: this.gap,
    )
      ..x = this.x + v.a
      ..y = this.y + v.b;
  }
}

extension ExtensionCrateStatus on CrateStatus {
  bool get hasOffset {
    switch (this) {
      case CrateStatus.idle:
        return false;
      case CrateStatus.movingUp:
      case CrateStatus.movingDown:
        return false;
      case CrateStatus.openClose:
        return true;
    }
  }
}
