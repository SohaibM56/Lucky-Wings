import 'dart:math';
import 'dart:ui' as ui;
import 'package:flip_flop/components/components.dart';
import 'package:flip_flop/utils/utils.dart';
import 'package:flip_flop/game_manager.dart';

class Bird extends Component with GameSound {
  Bird({
    required List<Sprite> spriteList,
    this.deadSprites = const [],
    double x = 50,
    double y = 100,
    int fat = 0,
    this.rotation = 0,
    this.frame = 0,
    this.speed = 0,
    this.gravity = .125,
    this.thrust = 3.6,
    this.dead = false,
  })  : sprites = spriteList,
        _fat = fat,
        super(
            sprite: spriteList.isEmpty ? Sprite.empty : spriteList[fat],
            x: x,
            y: y);

  int _fat;
  List<Sprite> sprites;
  List<ui.Image> deadSprites;
  int frame;
  double rotation;
  double speed;
  double gravity;
  double thrust;
  bool dead;

  @override
  void draw(ui.Canvas canvas, ui.Size size) {
    double width = this.sprites[_fat].path[this.frame].width.toDouble();
    double height = this.sprites[_fat].path[this.frame].height.toDouble();
    canvas.save();

    /// Add a translation to the current transform,
    /// shifting the coordinate space horizontally by the first argument
    /// and vertically by the second argument.
    canvas.translate(this.x, this.y);

    /// The argument is in radians clockwise.
    canvas.rotate(this.rotation * GameConstant.RAD);

    canvas.drawImage(this.sprites[_fat].path[this.frame],
        ui.Offset(-width / 2, -height / 2), ui.Paint());
    if (dead) {
      double _width = this.deadSprites[this.frame].width.toDouble();
      double _height = this.deadSprites[this.frame].height.toDouble();
      canvas.drawImage(this.deadSprites[this.frame],
          ui.Offset(-_width / 2, -_height / 2), ui.Paint());
    }
    canvas.restore();
  }

  @override
  void update(GameManager gameManager, int frames) {
    double r = this.sprites[_fat].width.toDouble() / 2;
    switch (gameManager.getGameState()) {
      case GameState.ready:
        this.y = 100;
        this.rotation = 0;
        this.frame += (frames % 10 == 0) ? 1 : 0;
        this.y += (frames % 10 == 0) ? sin(frames * GameConstant.RAD) : 0;
        break;
      case GameState.play:
        userSpells(gameManager);
        this.frame += (frames % 5 == 0) ? 1 : 0;
        // bird will be free to fall (inc y)
        this.y = this.y + speed;

        this.setRotation();
        this.speed = this.speed + gravity;
        if (this.y + r >= gameManager.getGround().y ||
            this.isCollision(gameManager, frames)) {
          dead = true;
          gameManager.gameOver();
        }
        break;
      case GameState.gameOver:
        //this.frame = 1;
        this.frame += (frames % 5 == 0) ? 1 : 0;
        // touch pipe and fall down
        if (this.y + r < gameManager.getGround().y) {
          if (!isFlyingInGap(gameManager)) {
            this.y += this.speed;
            this.setRotation();
          }
          this.speed += this.gravity * 2;
        } else {
          // touch ground
          this.speed = 0;
          this.y = gameManager.getGround().y - r;
          this.rotation = 90;
          if (!gameManager.isPlayed()) {
            playSound(path: 'die');
            gameManager.setPlayed(true);
          }
        }
        break;
      default:
        break;
    }
    this.frame = this.frame % this.sprites[_fat].length;
  }

  void flap() {
    if (this.y > 0) {
      this.speed = -this.thrust;
      playSound(path: 'flap');
    }
  }

  void reset() {
    this.speed = 0;
    this.y = 100;
    this.dead = false;
    this._fat = 0;
    this.rotation = 0;
    this.frame = 0;
    this.speed = 0;
    this.gravity = .125;
    this.thrust = 3.6;
    this.spells.clear();
  }

  void setRotation() {
    if (this.speed <= 0) {
      // tap event happen
      // speed_range: [-3.6,0]
      // 0 <= (this.speed / (-this.thrust)) <= 1 ~ -25 - 0 degree
      // = -25 when speed = -3.6, 0 when speed = 0
      this.rotation = max(-25, -25 * this.speed / (-this.thrust));
    } else if (this.speed > 0) {
      // fall
      // speed_range: (0,7.2]
      // 0 < this.speed / (this.thrust * 2) <= 1
      this.rotation = min(90, 90 * this.speed / (this.thrust * 2));
    }
  }

  bool isCollision(GameManager gameManager, int frames) {
    // Pipe pipe = gameManager.getPipes() as Pipe;
    Crate pipe = gameManager.getObstacle() as Crate;

    if (pipe.isEmpty) return false;
    List<Item> items = gameManager.getAvailableItems();
    //final topSprite = pipe.sprites[0];
    final topCrate = pipe.obstacles[0] as Crate;

    // Always hit-test against the base sprite size, even while the
    // BottlePotion "fat" buff is active — it's meant to be a visual
    // novelty, not a way to make the bird easier to hit.
    final bird = this.sprites[0].path.first;

    /// always compare with first pipe because first pipe will be
    /// removed when it is no longer on canvas
    double xPipe = pipe.obstacles[0].x;
    double r = bird.height / 4 + bird.width / 4;

    double topSpiteWidth = topCrate.width;
    if (this.x + r >= xPipe &&
        !(this.x + r < xPipe + topSpiteWidth) &&
        gameManager.isPipeRemoved()) {
      gameManager.writeScore(RewardType.score);
      int score = gameManager.readScore();
      if (score > 0 && score % 10 == 0) {
        playSound(path: 'good');
      } else {
        playSound(path: 'score');
      }
      gameManager.setPipeStatus(false);
    }

    /// collide pipe
    if (this.isCollisionRectRect(
          p1Offset: Vector2(a: -bird.width / 2, b: -bird.height / 2),
          other: topCrate.move(Vector2.zero.copyWith(
              a: 0,
              b: topCrate.crateStatus.hasOffset ? topCrate.threshold : 0)),
        ) ||
        this.isCollisionRectRect(
          p1Offset: Vector2(a: -bird.width / 2, b: -bird.height / 2),
          other: topCrate.move(Vector2.zero.copyWith(
              a: 0,
              b: topCrate.height +
                  pipe.gap -
                  (topCrate.crateStatus.hasOffset ? topCrate.threshold : 0))),
        )) {
      playSound(path: 'metal_hit');
      return true;
    }

    /// collide item
    if (topCrate.ark != null &&
        this.isCollisionRectRect(
            other: topCrate.ark!,
            p1Offset: Vector2(a: -bird.width / 2, b: -bird.height / 2))) {
      if (topCrate.ark is Gold) {
        if (!(topCrate.ark as Gold).isCollected) {
          (topCrate.ark as Gold).setCollect();
          gameManager.writeScore(RewardType.coin);
          playSound(path: 'coin_collect');
        }
      }
      //topCrate.ark = null;
    }

    items.forEach((item) {
      if (this.isCollisionRectRect(
        other: item,
        p1Offset: Vector2(a: -bird.width / 2, b: -bird.height / 2),
      )) {
        if (!item.isCollected) {
          item.setCollect();
          if (item.isFruit) {
            gameManager.writeScore(RewardType.fruit);
            playSound(path: 'eat');
          } else if (item is BottlePotion) {
            playSound(path: 'rank_up');
          }
        }
        if (item.isSpell) addSpell(item);
      }
    });

    // if (this.x + r >= xPipe) {
    //   if (this.x + r < xPipe + topSpiteWidth) {
    //     if (this.y - r <= roof || this.y + r >= floor) {
    //       playSound(path: 'metal_hit.mp3');
    //       return true;
    //     }
    //     // We assume when game start at the first time. There will be a pipe is removed on the left
    //     // The result is when the bird pass to the first pipe, the score will be recorded
    //   } else if (gameManager.isPipeRemoved()) {
    //     gameManager.writeScore();
    //     playSound(path: 'score.wav');
    //     gameManager.setPipeStatus(false);
    //   }
    // }

    return false;
  }

  bool isFlyingInGap(GameManager gameManager) {
    Crate pipe = gameManager.getObstacle() as Crate;
    if (pipe.isEmpty) return false;
    final topSprite = pipe.sprite.path[0];
    double xPipe = pipe.obstacles[0].x;
    double yPipe = pipe.obstacles[0].y;
    double roof = yPipe + topSprite.height;
    double floor = roof + pipe.gap;
    return this.x > xPipe &&
        this.x < xPipe + topSprite.width &&
        this.y > roof &&
        this.y < floor;
  }

  @override
  double get height => this.sprites[_fat].height.toDouble();

  @override
  double get width => this.sprites[_fat].width.toDouble();

  List<Item> spells = [];

  void addSpell(Item item) {
    if (item is Magnet) {
      if (!spells.any((e) => e is Magnet)) {
        spells.add(item);
      } else {
        Item magnet = spells.firstWhere((spell) => spell is Magnet);
        magnet.iat += item.iat;
      }
    } else if (item is BottlePotion) {
      if (!spells.any((e) => e is BottlePotion)) {
        spells.add(item);
      } else {
        Item bottle = spells.firstWhere((spell) => spell is BottlePotion);
        bottle.iat += item.iat;
      }
    }
  }

  void userSpells(GameManager gameManager) {
    spells.removeWhere((spell) => spell.isExpired);
    spells.forEach((spell) {
      if (spell is Magnet) {
        gameManager.getAvailableItems().forEach((item) {
          if (item is Fruit &&
              this.isCollisionCircleRect(
                  other: item, radius: spell.affectRadius) &&
              !item.isCollected) {
            /// add: !item.isCollected
            if (item.x < this.x) {
              item.x += 4;
            } else {
              item.x -= 4;
            }
            if (item.y < this.y) {
              item.y += 4;
            } else {
              item.y -= 4;
            }
          }
        });
      } else if (spell is BottlePotion) {
        spell.iat > 0 ? _fat = 1 : _fat = 0;
      }
      spell.iat--;
    });
  }
}
