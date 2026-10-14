import 'dart:math';

import 'package:flip_flop/ads/ad_config.dart';
import 'package:flip_flop/components/components.dart';

enum AdUnits {
  banner,
  interstitial,
  interstitialVideo,
  rewarded,
  rewardedInterstitial,
}

class GameConstant {
  static const double RAD = pi / 180;

  static const String isFirstTime = 'IS_FIRST_TIME';

  static const String bestScore = 'BEST_SCORE';

  static const String personalBest = 'PERSONAL_BEST';

  static const String fruit = 'FRUIT';

  static const String coin = 'COIN';

  static const String myBirds = 'MY_BIRDS';

  static const String currentBird = 'CURRENT_BIRD';

  static const String myMaps = 'MY_MAPS';

  static const String currentMap = 'CURRENT_MAPS';

  static const double explodeRatio = 497 / 445;

  static const Map<int, dynamic> birdSource = {
    1: {
      'sprites': [
        'assets/images/birds/char1/frame-1.png',
        'assets/images/birds/char1/frame-2.png',
        'assets/images/birds/char1/frame-3.png',
        'assets/images/birds/char1/frame-4.png',
        'assets/images/birds/char1/frame-5.png',
        'assets/images/birds/char1/frame-6.png',
      ],
      'type': ItemType.needWatchAd,
      'name': 'Bashford',
      'cost': 0,
      'spriteRatio': 395 / 373,
    },
    2: {
      'sprites': [
        'assets/images/birds/char2/frame-1.png',
        'assets/images/birds/char2/frame-2.png',
        'assets/images/birds/char2/frame-3.png',
        'assets/images/birds/char2/frame-4.png',
        'assets/images/birds/char2/frame-5.png',
        'assets/images/birds/char2/frame-6.png',
      ],
      'type': ItemType.free,
      'name': 'Bogpa',
      'cost': 0,
      'spriteRatio': 418 / 404,
    },
    3: {
      'sprites': [
        'assets/images/birds/char3/frame-1.png',
        'assets/images/birds/char3/frame-2.png',
        'assets/images/birds/char3/frame-3.png',
        'assets/images/birds/char3/frame-4.png',
        'assets/images/birds/char3/frame-5.png',
        'assets/images/birds/char3/frame-6.png',
      ],
      'type': ItemType.needShareSocial,
      'name': 'Beymar',
      'cost': 0,
      'spriteRatio': 427 / 387,
    },
    4: {
      'sprites': [
        'assets/images/birds/char4/frame-1.png',
        'assets/images/birds/char4/frame-2.png',
        'assets/images/birds/char4/frame-3.png',
        'assets/images/birds/char4/frame-4.png',
        'assets/images/birds/char4/frame-5.png',
        'assets/images/birds/char4/frame-6.png',
      ],
      'type': ItemType.needBuyByFruit,
      'name': 'Barshin',
      'cost': 100,
      'spriteRatio': 449 / 410,
    },
    5: {
      'sprites': [
        'assets/images/birds/char5/frame-1.png',
        'assets/images/birds/char5/frame-2.png',
        'assets/images/birds/char5/frame-3.png',
        'assets/images/birds/char5/frame-4.png',
        'assets/images/birds/char5/frame-5.png',
        'assets/images/birds/char5/frame-6.png',
      ],
      'type': ItemType.needBuyByCoin,
      'name': 'Babel',
      'cost': 35,
      'spriteRatio': 417 / 420,
    },
    6: {
      'sprites': [
        'assets/images/birds/char6/frame-1.png',
        'assets/images/birds/char6/frame-2.png',
        'assets/images/birds/char6/frame-3.png',
        'assets/images/birds/char6/frame-4.png',
        'assets/images/birds/char6/frame-5.png',
        'assets/images/birds/char6/frame-6.png',
      ],
      'type': ItemType.needBuyByCoin,
      'name': 'Bihanna',
      'cost': 35,
      'spriteRatio': 448 / 408,
    },
    7: {
      'sprites': [
        'assets/images/birds/char7/frame-1.png',
        'assets/images/birds/char7/frame-2.png',
        'assets/images/birds/char7/frame-3.png',
        'assets/images/birds/char7/frame-4.png',
      ],
      'type': ItemType.needBuyByCoin,
      'name': 'Bimaria',
      'cost': 50,
      'spriteRatio': 437 / 369,
    },
    8: {
      'sprites': [
        'assets/images/birds/char8/frame-1.png',
        'assets/images/birds/char8/frame-2.png',
        'assets/images/birds/char8/frame-3.png',
        'assets/images/birds/char8/frame-4.png',
      ],
      'type': ItemType.needBuyByCoin,
      'name': 'Bubameyang',
      'cost': 120,
      'spriteRatio': 437 / 400,
    },
    9: {
      'sprites': [
        'assets/images/birds/char9/frame-1.png',
        'assets/images/birds/char9/frame-2.png',
        'assets/images/birds/char9/frame-3.png',
        'assets/images/birds/char9/frame-4.png',
        'assets/images/birds/char9/frame-5.png',
        'assets/images/birds/char9/frame-6.png',
      ],
      'type': ItemType.needBuyByCoin,
      'name': 'Barius',
      'cost': 35,
      'spriteRatio': 481 / 349,
    },
    10: {
      'sprites': [
        'assets/images/birds/char10/frame-1.png',
        'assets/images/birds/char10/frame-2.png',
        'assets/images/birds/char10/frame-3.png',
        'assets/images/birds/char10/frame-4.png',
      ],
      'type': ItemType.needBuyByCoin,
      'name': 'Bidanze',
      'cost': 65,
      'spriteRatio': 439 / 384,
    },
    11: {
      'sprites': [
        'assets/images/birds/char11/frame-1.png',
        'assets/images/birds/char11/frame-2.png',
        'assets/images/birds/char11/frame-3.png',
        'assets/images/birds/char11/frame-4.png',
        'assets/images/birds/char11/frame-5.png',
        'assets/images/birds/char11/frame-6.png',
      ],
      'type': ItemType.needWatchAd,
      'name': 'Katy Berry',
      'cost': 25,
      'spriteRatio': 427 / 432,
    },
    12: {
      'sprites': [
        'assets/images/birds/char12/frame-1.png',
        'assets/images/birds/char12/frame-2.png',
        'assets/images/birds/char12/frame-3.png',
        'assets/images/birds/char12/frame-4.png',
      ],
      'type': ItemType.needBuyByFruit,
      'name': 'Jhonny Beep',
      'cost': 100,
      'spriteRatio': 442 / 366,
    },
    13: {
      'sprites': [
        'assets/images/birds/char13/frame-1.png',
        'assets/images/birds/char13/frame-2.png',
        'assets/images/birds/char13/frame-3.png',
        'assets/images/birds/char13/frame-4.png',
      ],
      'type': ItemType.needBuyByCoin,
      'name': 'Bellish',
      'cost': 50,
      'spriteRatio': 449 / 366,
    },
    14: {
      'sprites': [
        'assets/images/birds/char14/frame-1.png',
        'assets/images/birds/char14/frame-2.png',
        'assets/images/birds/char14/frame-3.png',
        'assets/images/birds/char14/frame-4.png',
        'assets/images/birds/char14/frame-5.png',
        'assets/images/birds/char14/frame-6.png',
      ],
      'type': ItemType.needBuyByFruit,
      'name': 'Richalison',
      'cost': 80,
      'spriteRatio': 495 / 392,
    },
    15: {
      'sprites': [
        'assets/images/birds/char15/frame-1.png',
        'assets/images/birds/char15/frame-2.png',
        'assets/images/birds/char15/frame-3.png',
        'assets/images/birds/char15/frame-4.png',
        'assets/images/birds/char15/frame-5.png',
        'assets/images/birds/char15/frame-6.png',
      ],
      'type': ItemType.needBuyByFruit,
      'name': 'Balotelli',
      'cost': 80,
      'spriteRatio': 424 / 331,
    },
    16: {
      'sprites': [
        'assets/images/birds/char16/frame-1.png',
        'assets/images/birds/char16/frame-2.png',
        'assets/images/birds/char16/frame-3.png',
        'assets/images/birds/char16/frame-4.png',
        'assets/images/birds/char16/frame-5.png',
        'assets/images/birds/char16/frame-6.png',
      ],
      'type': ItemType.needBuyByCoin,
      'name': 'Bidal',
      'cost': 40,
      'spriteRatio': 423 / 343,
    },
    17: {
      'sprites': [
        'assets/images/birds/char17/frame-1.png',
        'assets/images/birds/char17/frame-2.png',
        'assets/images/birds/char17/frame-3.png',
        'assets/images/birds/char17/frame-4.png',
        'assets/images/birds/char17/frame-5.png',
        'assets/images/birds/char17/frame-6.png',
      ],
      'type': ItemType.needBuyByFruit,
      'name': 'Bonster',
      'cost': 110,
      'spriteRatio': 480 / 402,
    },
    18: {
      'sprites': [
        'assets/images/birds/char18/frame-1.png',
        'assets/images/birds/char18/frame-2.png',
        'assets/images/birds/char18/frame-3.png',
        'assets/images/birds/char18/frame-4.png',
        'assets/images/birds/char18/frame-5.png',
        'assets/images/birds/char18/frame-6.png',
      ],
      'type': ItemType.needBuyByCoin,
      'name': 'Bibery',
      'cost': 150,
      'spriteRatio': 548 / 354,
    },
    19: {
      'sprites': [
        'assets/images/birds/char19/frame-1.png',
        'assets/images/birds/char19/frame-2.png',
        'assets/images/birds/char19/frame-3.png',
        'assets/images/birds/char19/frame-4.png',
      ],
      'type': ItemType.needBuyByCoin,
      'name': 'Bhicharito',
      'cost': 50,
      'spriteRatio': 560 / 425,
    },
    20: {
      'sprites': [
        'assets/images/birds/char20/frame-1.png',
        'assets/images/birds/char20/frame-2.png',
        'assets/images/birds/char20/frame-3.png',
        'assets/images/birds/char20/frame-4.png',
      ],
      'type': ItemType.needBuyByCoin,
      'name': 'Bulk',
      'cost': 55,
      'spriteRatio': 512 / 384,
    },
    21: {
      'sprites': [
        'assets/images/birds/char21/frame-1.png',
        'assets/images/birds/char21/frame-2.png',
        'assets/images/birds/char21/frame-3.png',
        'assets/images/birds/char21/frame-4.png',
        'assets/images/birds/char21/frame-5.png',
        'assets/images/birds/char21/frame-6.png',
      ],
      'type': ItemType.needBuyByFruit,
      'name': 'Birlo',
      'cost': 100,
      'spriteRatio': 477 / 384,
    },
    22: {
      'sprites': [
        'assets/images/birds/char22/frame-1.png',
        'assets/images/birds/char22/frame-2.png',
        'assets/images/birds/char22/frame-3.png',
        'assets/images/birds/char22/frame-4.png',
      ],
      'type': ItemType.needBuyByFruit,
      'name': 'Betr Chech',
      'cost': 100,
      'spriteRatio': 474 / 376,
    },
    23: {
      'sprites': [
        'assets/images/birds/char23/frame-1.png',
        'assets/images/birds/char23/frame-2.png',
        'assets/images/birds/char23/frame-3.png',
        'assets/images/birds/char23/frame-4.png',
        'assets/images/birds/char23/frame-5.png',
        'assets/images/birds/char23/frame-6.png',
      ],
      'type': ItemType.needBuyByFruit,
      'name': 'Berry',
      'cost': 100,
      'spriteRatio': 449 / 339,
    },
    24: {
      'sprites': [
        'assets/images/birds/char24/frame-1.png',
        'assets/images/birds/char24/frame-2.png',
        'assets/images/birds/char24/frame-3.png',
        'assets/images/birds/char24/frame-4.png',
      ],
      'type': ItemType.needBuyByFruit,
      'name': 'Bavens',
      'cost': 110,
      'spriteRatio': 644 / 421,
    },
    25: {
      'sprites': [
        'assets/images/birds/char25/frame-1.png',
        'assets/images/birds/char25/frame-2.png',
        'assets/images/birds/char25/frame-3.png',
        'assets/images/birds/char25/frame-4.png',
        'assets/images/birds/char25/frame-5.png',
        'assets/images/birds/char25/frame-6.png',
      ],
      'type': ItemType.needBuyByCoin,
      'name': 'Bruno',
      'cost': 50,
      'spriteRatio': 481 / 345,
    },
    26: {
      'sprites': [
        'assets/images/birds/char26/frame-1.png',
        'assets/images/birds/char26/frame-2.png',
        'assets/images/birds/char26/frame-3.png',
        'assets/images/birds/char26/frame-4.png',
      ],
      'type': ItemType.needBuyByCoin,
      'name': 'Bozil',
      'cost': 50,
      'spriteRatio': 449 / 362,
    },
    27: {
      'sprites': [
        'assets/images/birds/char27/frame-1.png',
        'assets/images/birds/char27/frame-2.png',
        'assets/images/birds/char27/frame-3.png',
        'assets/images/birds/char27/frame-4.png',
      ],
      'type': ItemType.needBuyByCoin,
      'name': 'Baguero',
      'cost': 55,
      'spriteRatio': 489 / 395,
    },
    28: {
      'sprites': [
        'assets/images/birds/char28/frame-1.png',
        'assets/images/birds/char28/frame-2.png',
        'assets/images/birds/char28/frame-3.png',
        'assets/images/birds/char28/frame-4.png',
      ],
      'type': ItemType.needBuyByFruit,
      'name': 'Maxi Bopez',
      'cost': 90,
      'spriteRatio': 450 / 359,
    },
    29: {
      'sprites': [
        'assets/images/birds/char29/frame-1.png',
        'assets/images/birds/char29/frame-2.png',
        'assets/images/birds/char29/frame-3.png',
        'assets/images/birds/char29/frame-4.png',
      ],
      'type': ItemType.needBuyByFruit,
      'name': 'Baka',
      'spriteRatio': 455 / 415,
      'cost': 120,
    },
    30: {
      'sprites': [
        'assets/images/birds/char30/frame-1.png',
        'assets/images/birds/char30/frame-2.png',
        'assets/images/birds/char30/frame-3.png',
        'assets/images/birds/char30/frame-4.png',
      ],
      'type': ItemType.needBuyByFruit,
      'name': 'Bessi',
      'cost': 200,
      'spriteRatio': 532 / 382,
    },
    31: {
      'sprites': [
        'assets/images/birds/char31/frame-1.png',
        'assets/images/birds/char31/frame-2.png',
        'assets/images/birds/char31/frame-3.png',
        'assets/images/birds/char31/frame-4.png',
      ],
      'type': ItemType.needBuyByCoin,
      'name': 'Blopp',
      'cost': 75,
      'spriteRatio': 550 / 410,
    },
    32: {
      'sprites': [
        'assets/images/birds/char32/frame-1.png',
        'assets/images/birds/char32/frame-2.png',
        'assets/images/birds/char32/frame-3.png',
        'assets/images/birds/char32/frame-4.png',
      ],
      'type': ItemType.needBuyByCoin,
      'name': 'Bella',
      'cost': 40,
      'spriteRatio': 550 / 360,
    },
    33: {
      'sprites': [
        'assets/images/birds/char33/frame-1.png',
        'assets/images/birds/char33/frame-2.png',
        'assets/images/birds/char33/frame-3.png',
        'assets/images/birds/char33/frame-4.png',
        'assets/images/birds/char33/frame-5.png',
        'assets/images/birds/char33/frame-6.png',
      ],
      'type': ItemType.needBuyByCoin,
      'name': 'Banchez',
      'cost': 40,
      'spriteRatio': 535 / 349,
    },
    34: {
      'sprites': [
        'assets/images/birds/char34/frame-1.png',
        'assets/images/birds/char34/frame-2.png',
        'assets/images/birds/char34/frame-3.png',
        'assets/images/birds/char34/frame-4.png',
      ],
      'type': ItemType.needBuyByFruit,
      'name': 'Van Bersi',
      'cost': 110,
      'spriteRatio': 455 / 369,
    },
    35: {
      'sprites': [
        'assets/images/birds/char35/frame-1.png',
        'assets/images/birds/char35/frame-2.png',
        'assets/images/birds/char35/frame-3.png',
        'assets/images/birds/char35/frame-4.png',
        'assets/images/birds/char35/frame-5.png',
        'assets/images/birds/char35/frame-6.png',
      ],
      'type': ItemType.needBuyByCoin,
      'name': 'Buardiola',
      'cost': 100,
      'spriteRatio': 559 / 345,
    },
    36: {
      'sprites': [
        'assets/images/birds/char36/frame-1.png',
        'assets/images/birds/char36/frame-2.png',
        'assets/images/birds/char36/frame-3.png',
        'assets/images/birds/char36/frame-4.png',
        'assets/images/birds/char36/frame-5.png',
        'assets/images/birds/char36/frame-6.png',
      ],
      'type': ItemType.needBuyByFruit,
      'name': 'Bolando Lima',
      'cost': 200,
      'spriteRatio': 497 / 445,
    },
  };

  static const Map<int, dynamic> mapSource = {
    1: {
      'sprites': [
        'assets/images/background/desertBg.png',
      ],
      'mapType': MapType.desert,
      'type': ItemType.needBuyByFruit,
      'name': 'Quatar Desert',
      'cost': 250,
      'spriteRatio': 1.0,
    },
    2: {
      'sprites': [
        'assets/images/background/graveyardBg.png',
      ],
      'mapType': MapType.graveyard,
      'type': ItemType.needBuyByCoin,
      'name': 'Graveyard',
      'cost': 200,
      'spriteRatio': 1.0,
    },
    3: {
      'sprites': [
        'assets/images/background/jungle1.png',
      ],
      'mapType': MapType.spring,
      'type': ItemType.needBuyByFruit,
      'name': 'Wild Forest',
      'cost': 150,
      'spriteRatio': 1.0,
    },
    4: {
      'sprites': [
        'assets/images/background/jungle2.png',
      ],
      'mapType': MapType.spring,
      'type': ItemType.free,
      'name': 'Mysterious Forest',
      'cost': 0,
      'spriteRatio': 1.0,
    },
    5: {
      'sprites': [
        'assets/images/background/desertSimple.png',
      ],
      'mapType': MapType.desert,
      'type': ItemType.needBuyByCoin,
      'name': 'The Giza',
      'cost': 50,
      'spriteRatio': 1.0,
    },
    6: {
      'sprites': ['assets/images/background/springBg.png'],
      'mapType': MapType.spring,
      'type': ItemType.needBuyByFruit,
      'name': 'Spring',
      'cost': 250,
      'spriteRatio': 1.0,
    },
    7: {
      'sprites': [
        'assets/images/background/winterBg.png',
      ],
      'mapType': MapType.winter,
      'type': ItemType.needBuyByCoin,
      'name': 'Winter',
      'cost': 200,
      'spriteRatio': 1.0,
    },
    8: {
      'sprites': [
        'assets/images/background/xmasNight.png',
      ],
      'mapType': MapType.winter,
      'type': ItemType.needBuyByFruit,
      'name': 'Xmas Dark',
      'cost': 150,
      'spriteRatio': 1.0,
    },
  };

  static Map<AdUnits, String> get adUnits => {
        AdUnits.banner: AdConfig.bannerId,
        AdUnits.interstitial: AdConfig.interstitialId,
        AdUnits.interstitialVideo: AdConfig.interstitialId,
        AdUnits.rewarded: AdConfig.rewardedId,
        AdUnits.rewardedInterstitial: AdConfig.rewardedId,
      };
}
