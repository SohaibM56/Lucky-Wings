import 'dart:ui' as ui;

class Sprite {
  const Sprite({this.path = const [], this.delegateFrame = 0});

  final List<ui.Image> path;

  final int delegateFrame;

  int get width => this.path[delegateFrame].width;

  int get height => this.path[delegateFrame].height;

  int get length => this.path.length;

  Sprite copyWith({
    List<ui.Image>? path,
    int? delegateFrame,
  }) {
    return Sprite(
      path: path ?? this.path,
      delegateFrame: delegateFrame ?? this.delegateFrame,
    );
  }

  static const empty = const Sprite(path: [], delegateFrame: 0);
}
