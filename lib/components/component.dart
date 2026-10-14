import 'dart:math';
import 'dart:ui' as ui;

import 'package:flip_flop/components/components.dart';
import 'package:flip_flop/game_manager.dart';

abstract class Component {
  Component({
    this.sprite = Sprite.empty,
    this.x = 0,
    this.y = 0,
    this.shouldPaint = true,
  });

  Sprite sprite;

  double x;

  double y;

  bool shouldPaint;

  double get width;

  double get height;

  void draw(ui.Canvas canvas, ui.Size size);

  void update(GameManager gameManager, int frames);

  bool isCollisionRectRect({
    required Component other,
    Vector2 p1Offset = Vector2.zero,
    Vector2 p2Offset = Vector2.zero,
  }) {
    double r1x = this.x + p1Offset.a;
    double r1y = this.y + p1Offset.b;
    double r1w = this.width;
    double r1h = this.height;

    double r2x = other.x + p2Offset.a;
    double r2y = other.y + p2Offset.b;
    double r2w = other.width;
    double r2h = other.height;

    if (r1x + r1w >= r2x &&
        r1x <= r2x + r2w &&
        r1y + r1h >= r2y &&
        r1y <= r2y + r2h) {
      return true;
    }

    return false;
  }

  bool isCollisionCircleRect({
    double radius = 200,
    required Component other,
    Vector2 p1Offset = Vector2.zero,
    Vector2 p2Offset = Vector2.zero,
  }) {
    double cx = this.x + p1Offset.a;
    double cy = this.y + p1Offset.b;

    double rx = other.x + p2Offset.a;
    double ry = other.y + p2Offset.b;
    double rw = other.width;
    double rh = other.height;

    // temporary variables to set edges for testing
    double testX = cx;
    double testY = cy;

    // which edge is closest?
    if (cx < rx)
      testX = rx; // test left edge
    else if (cx > rx + rw) testX = rx + rw; // right edge
    if (cy < ry)
      testY = ry; // top edge
    else if (cy > ry + rh) testY = ry + rh; // bottom edge

    // get distance from closest edges
    double distX = cx - testX;
    double distY = cy - testY;
    double distance = sqrt((distX * distX) + (distY * distY));

    // if the distance is less than the radius, collision!
    if (distance <= radius) {
      return true;
    }
    return false;
  }

}
