import 'dart:ui' as ui;
import 'package:flip_flop/components/components.dart';
import 'package:flip_flop/utils/utils.dart';

enum GameState { firstTime, ready, play, pause, gameOver }

enum RewardType { score, fruit, coin }

enum ItemName {
  durian,
  kiwi,
  orange,
  papaya,
  pineapple,
  watermelon,
  gold,
  magnet,
  bottle,
}

abstract class GameManager {
  static final moveDx = 2;

  static final moveDy = 2;

  static final itemPaddingSmall = 2;

  static final itemPaddingMedium = 4;

  static final gameSpeed = 2;

  static List<Item> gameItems = [];

  int readScore();

  void writeScore(RewardType rewardType);

  void gameReady();

  void gameOver();

  void setPipeStatus(bool status);

  void setPlayed(bool status);

  bool isPipeRemoved();

  bool isPlayed();

  ui.Size getScreenSize();

  GameState getGameState();

  Component getGround();

  Component getObstacle();

  List<Item> getAvailableItems();

  static Future<List<Component>> initComponents() async {
    ui.Image gndImg =
        await GameUtils.loadImage("assets/images/background/ground2.png");

    int bWN = 40;
    ui.Image explodeImg0 = await GameUtils.loadImageFitSize(
        "assets/images/birds/explode/frame-1.png",
        bWN,
        bWN ~/ GameConstant.explodeRatio);
    ui.Image explodeImg1 = await GameUtils.loadImageFitSize(
        "assets/images/birds/explode/frame-2.png",
        bWN,
        bWN ~/ GameConstant.explodeRatio);
    ui.Image explodeImg2 = await GameUtils.loadImageFitSize(
        "assets/images/birds/explode/frame-3.png",
        bWN,
        bWN ~/ GameConstant.explodeRatio);
    ui.Image explodeImg3 = await GameUtils.loadImageFitSize(
        "assets/images/birds/explode/frame-4.png",
        bWN,
        bWN ~/ GameConstant.explodeRatio);
    ui.Image explodeImg4 = await GameUtils.loadImageFitSize(
        "assets/images/birds/explode/frame-1.png",
        bWN,
        bWN ~/ GameConstant.explodeRatio);
    ui.Image explodeImg5 = await GameUtils.loadImageFitSize(
        "assets/images/birds/explode/frame-2.png",
        bWN,
        bWN ~/ GameConstant.explodeRatio);

    ui.Image getReadyImg1 =
        await GameUtils.loadImage("assets/images/click.png");
    ui.Image getReadyImg2 =
        await GameUtils.loadImage("assets/images/unclick.png");

    ui.Image crate =
        await GameUtils.loadImage("assets/images/objects/crate3.png");
    List<Component> components = [];
    // Background will be draw first
    components.add(Background(sprite: Sprite(path: [])));

    components.add(Crate(sprite: Sprite(path: [crate])));

    // Ground will be draw on background and pipes
    components.add(Ground(sprite: Sprite(path: [gndImg])));
    components.add(Board());
    components.add(Bird(
      spriteList: [],
      deadSprites: [
        explodeImg0,
        explodeImg1,
        explodeImg2,
        explodeImg3,
        explodeImg4,
        explodeImg5,
      ],
    ));
    components
        .add(GetReady(sprite: Sprite(path: [getReadyImg1, getReadyImg2])));
    return components;
  }

  static Future<List<Item>> getGameItems() async {
    /// Fog effect
    List<ui.Image> fogEffect = [];
    for (int i = 0; i < 4; i++) {
      ui.Image fog = await GameUtils.loadImageFitSize(
          "assets/images/objects/fog${i + 1}.png", 30, 30);
      fogEffect.add(fog);
    }
    List<Item> items = [];

    /// Fruit
    for (final item in ItemName.values) {
      String imagePath = item.imagePath;
      if (imagePath.contains("fruit")) {
        List<ui.Image> fruits = [];
        ui.Image f = await GameUtils.loadImageFitSize(imagePath, 30, 30);
        fruits.add(f);
        items.add(Fruit(sprite: Sprite(path: fruits), effect: fogEffect));
      }
    }

    /// Gold item
    List<ui.Image> goldItem = [];
    List<ui.Image> goldCollectedEffect = [];
    for (int i = 0; i < 16; i++) {
      ui.Image item = await GameUtils.loadImageFitSize(
          "assets/images/objects/coin${i + 1}.png", 50, 50);
      goldItem.add(item);
      if (i < 7) {
        ui.Image d = await GameUtils.loadImageFitSize(
            "assets/images/objects/coin_e${i + 1}.png", 50, 50);
        goldCollectedEffect.add(d);
      }
    }
    items
        .add(Gold(sprite: Sprite(path: goldItem), effect: goldCollectedEffect));

    /// Magnet item
    ui.Image magnet =
        await GameUtils.loadImageFitSize(ItemName.magnet.imagePath, 30, 30);
    items.add(Magnet(sprite: Sprite(path: [magnet]), effect: []));

    /// Magnet item
    ui.Image bottle =
        await GameUtils.loadImageFitSize(ItemName.bottle.imagePath, 30, 30);
    items.add(BottlePotion(sprite: Sprite(path: [bottle]), effect: []));
    return items;
  }
}

extension on ItemName {
  String get imagePath {
    switch (this) {
      case ItemName.gold:
        return "";
      case ItemName.durian:
        return "assets/images/objects/fruitDurian.png";
      case ItemName.kiwi:
        return "assets/images/objects/fruitKiwi.png";
      case ItemName.orange:
        return "assets/images/objects/fruitOrange.png";
      case ItemName.papaya:
        return "assets/images/objects/fruitPapaya.png";
      case ItemName.pineapple:
        return "assets/images/objects/fruitPineapple.png";
      case ItemName.watermelon:
        return "assets/images/objects/fruitWatermelon.png";
      case ItemName.magnet:
        return "assets/images/objects/magnet.png";
      case ItemName.bottle:
        return "assets/images/bottle.png";
    }
  }
}
