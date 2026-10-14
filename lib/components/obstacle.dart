import 'dart:ui' as ui;
import 'package:flip_flop/components/components.dart';
import 'package:flip_flop/game_manager.dart';

class Obstacle extends Component {
  Obstacle({
    required Sprite sprite,
  }) : super(sprite: sprite);


  List<Obstacle> obstacles = [];

  @override
  void draw(ui.Canvas canvas, ui.Size size) {
    // TODO: implement draw
  }

  @override
  void update(GameManager gameManager, int frames) {
    // TODO: implement update
  }

  void reset() => this.obstacles.clear();

  bool get isEmpty => this.obstacles.isEmpty;

  bool get isNotEmpty => this.obstacles.isNotEmpty;

  @override
  double get height => throw UnimplementedError();

  @override
  double get width => throw UnimplementedError();
}
