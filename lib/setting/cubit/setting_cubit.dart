import 'package:flip_flop/ads/ad_service.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:equatable/equatable.dart';
import 'package:flip_flop/components/components.dart';
import 'package:flip_flop/utils/utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flip_flop/game_manager.dart';

part 'setting_state.dart';

class SettingCubit extends Cubit<SettingState> with GameSound {
  SettingCubit() : super(const SettingState());

  late RewardedAd _rewardedAd;

  // Namespaces every SharedPreferences key by the current uid so each
  // account's coins/birds/maps stay isolated on a shared device, including
  // between different guest sessions.
  String? _uid;
  String _k(String base) => _uid == null ? base : '${_uid}_$base';

  /// Called once AuthCubit resolves to a real uid (sign-in, guest sign-in,
  /// or account linking) so this account's own data loads instead of
  /// whichever account last used the device.
  Future<void> setUser(String uid) async {
    if (_uid == uid) return;
    _uid = uid;
    await _migrateLegacyData();
    // initSetting() may still be loading birds/maps/components (it awaits
    // asset loads); if so, let its own trailing _loadUserData() call pick up
    // this uid once that finishes, rather than reloading against empty data.
    if (state.birds.isEmpty || state.maps.isEmpty) return;
    await _loadUserData();
  }

  /// The first time a uid is attached on this device, carry over any
  /// progress saved under the old un-scoped keys (from before per-account
  /// data existed, or from the brief window before auth resolves) instead
  /// of silently orphaning it behind a fresh, empty per-account keyspace.
  Future<void> _migrateLegacyData() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_k(GameConstant.coin))) return; // already migrated
    for (final key in [
      GameConstant.myBirds,
      GameConstant.myMaps,
      GameConstant.currentBird,
      GameConstant.currentMap,
      GameConstant.coin,
      GameConstant.fruit,
    ]) {
      final legacy = prefs.getInt(key);
      if (legacy != null) {
        await prefs.setInt(_k(key), legacy);
        // Consume it: left in place, every later account on this device
        // (e.g. a brand-new guest) would be handed the first player's
        // coins, birds and maps by this same copy.
        await prefs.remove(key);
      }
    }
  }

  void initSetting() async {
    emit(state.copyWith(status: SettingStatus.initSetting));

    List<Component> components = await GameManager.initComponents();
    List<BirdModel> birds = GameConstant.birdSource.values
        .map((json) => BirdModel.fromJson(json))
        .toList();
    List<MapModel> maps = GameConstant.mapSource.values
        .map((json) => MapModel.fromJson(json))
        .toList();

    emit(state.copyWith(components: components, birds: birds, maps: maps));
    await _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    /// Config bird
    List<BirdModel> myBirds = [];
    String myBirdsBinary =
        (prefs.getInt(_k(GameConstant.myBirds)) ?? 0).toRadixString(2);

    for (int i = myBirdsBinary.length - 1; i >= 0; i--) {
      if (myBirdsBinary[i] == '1') {
        myBirds.add(state.birds[myBirdsBinary.length - 1 - i]);
      }
    }

    int curBird = prefs.getInt(_k(GameConstant.currentBird)) ?? -1;
    BirdModel currentBird = curBird == -1
        ? BirdModel.empty
        : BirdModel.fromJson(GameConstant.birdSource[curBird + 1]);
    // The starter bird is always owned. This used to check for "Bashford"
    // (a watch-ad bird), so unlocking it silently dropped the starter bird
    // from the owned list and it reappeared as a "0 fruit" purchase.
    if (!myBirds.any((element) => element.name == BirdModel.empty.name)) {
      myBirds.add(BirdModel.empty);
    }
    await updateBirdSprites(currentBird, state.components);

    /// Config map
    List<MapModel> myMaps = [];
    String myMapsBinary =
        (prefs.getInt(_k(GameConstant.myMaps)) ?? 0).toRadixString(2);

    for (int i = myMapsBinary.length - 1; i >= 0; i--) {
      if (myMapsBinary[i] == '1') {
        myMaps.add(state.maps[myMapsBinary.length - 1 - i]);
      }
    }

    int curMap = prefs.getInt(_k(GameConstant.currentMap)) ?? -1;
    MapModel currentMap = curMap == -1
        ? MapModel.empty
        : MapModel.fromJson(GameConstant.mapSource[curMap + 1]);
    if (!myMaps.any((element) => element.name == MapModel.empty.name)) {
      myMaps.add(MapModel.empty);
    }

    await updateMapSprites(currentMap, state.components);

    // Resolve to this account's real balance (or the default for a brand
    // new account) rather than letting copyWith's null-check fall back to
    // whichever account's balance was in state before this load.
    int coin = prefs.getInt(_k(GameConstant.coin)) ?? const SettingState().coin;
    int fruit =
        prefs.getInt(_k(GameConstant.fruit)) ?? const SettingState().fruit;

    emit(
      state.copyWith(
        myBirds: myBirds,
        myMaps: myMaps,
        currentBird: currentBird,
        currentMap: currentMap,
        coin: coin,
        fruit: fruit,
        status: SettingStatus.initSettingDone,
      ),
    );
  }

  void showRewardedAd({
    Function(RewardedAd rewardedAd)? onCompleted,
    Function? onError,
  }) {
    if (state.status == SettingStatus.initRewardedAdInProgress) return;
    // Not before consent / when ads aren't allowed: behave like "no ad".
    if (!AdService.instance.adsEnabled.value) {
      onError?.call();
      return;
    }
    emit(state.copyWith(status: SettingStatus.initRewardedAdInProgress));
    String adUnitId = GameConstant.adUnits[AdUnits.rewarded]!;
    RewardedAd.load(
      adUnitId: adUnitId,
      request: AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          this._rewardedAd = ad;
          _rewardedAd.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (RewardedAd ad) {
              GameUtils.fullScreenAdShown();
            },
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              ad.dispose();
              GameUtils.fullScreenAdDismissed();
            },
            onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
              ad.dispose();
              GameUtils.fullScreenAdDismissed();
              onError?.call();
            },
          );
          emit(state.copyWith(status: SettingStatus.initRewardedAdSuccess));
          onCompleted?.call(_rewardedAd);
        },
        onAdFailedToLoad: (LoadAdError error) {
          emit(state.copyWith(status: SettingStatus.initRewardedAdFailure));
          onError?.call();
        },
      ),
    );
  }

  Future<void> updateBirdSprites(
      BirdModel bird, List<Component> components) async {
    int bWN = 34;
    int bHN = bWN ~/ bird.spriteRatio;
    List<ui.Image> _normalBird = [];

    int bWS = 20;
    int bHS = bWS ~/ bird.spriteRatio;
    List<ui.Image> _smallBird = [];
    for (String sprite in bird.sprites) {
      _normalBird.add(await GameUtils.loadImageFitSize(sprite, bWN, bHN));
      _smallBird.add(await GameUtils.loadImageFitSize(sprite, bWS, bHS));
    }
    (components[4] as Bird).sprites = [
      Sprite(path: _normalBird),
      Sprite(path: _smallBird),
    ];
  }

  Future<void> updateMapSprites(
      MapModel map, List<Component> components) async {
    ui.Image bgSprite = await GameUtils.loadImage(map.sprites.first);
    (components[0] as Background).sprite = Sprite(path: [bgSprite]);
    ui.Image crateSprite = await GameUtils.loadImage(map.crateImage);
    (components[1] as Crate).sprite = Sprite(path: [crateSprite]);
    ui.Image gndSprite = await GameUtils.loadImage(map.groundImage);
    (components[2] as Ground).sprite = Sprite(path: [gndSprite]);
  }

  Future<void> birdChanged({
    required BirdModel bird,
    required int index,
    Function? onSuccess,
    Function(SettingStatus status)? onFailure,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (state.myBirds.contains(bird)) {
      updateBirdSprites(bird, state.components);
      await prefs.setInt(_k(GameConstant.currentBird), index);
      emit(state.copyWith(currentBird: bird));
      playSound(path: 'bird_collect');
    } else if (bird.type == ItemType.needBuyByCoin && state.coin >= bird.cost) {
      int _myBirdsMemory = prefs.getInt(_k(GameConstant.myBirds)) ?? 0;
      _myBirdsMemory += pow(2, index).toInt();
      await prefs.setInt(_k(GameConstant.myBirds), _myBirdsMemory);
      await prefs.setInt(_k(GameConstant.coin), state.coin - bird.cost);
      List<BirdModel> myBirds = []..addAll(state.myBirds);
      myBirds.add(bird);
      emit(state.copyWith(coin: state.coin - bird.cost, myBirds: myBirds));
      playSound(path: 'unlock');
      onSuccess?.call();
    } else if (bird.type == ItemType.needBuyByCoin && state.coin < bird.cost) {
      onFailure?.call(SettingStatus.needMoreCoin);
    } else if (bird.type == ItemType.needBuyByFruit &&
        state.fruit >= bird.cost) {
      int _myBirdsMemory = prefs.getInt(_k(GameConstant.myBirds)) ?? 0;
      _myBirdsMemory += pow(2, index).toInt();
      await prefs.setInt(_k(GameConstant.myBirds), _myBirdsMemory);
      await prefs.setInt(_k(GameConstant.fruit), state.fruit - bird.cost);
      List<BirdModel> myBirds = []..addAll(state.myBirds);
      myBirds.add(bird);
      emit(state.copyWith(fruit: state.fruit - bird.cost, myBirds: myBirds));
      playSound(path: 'unlock');
      onSuccess?.call();
    } else if (bird.type == ItemType.needBuyByFruit &&
        state.fruit < bird.cost) {
      onFailure?.call(SettingStatus.needMoreFruit);
    } else {
      onFailure?.call(SettingStatus.unknown);
    }
  }

  Future<void> unlockBird({
    required BirdModel bird,
    required int index,
    Function? onSuccess,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    int _myBirdsMemory = prefs.getInt(_k(GameConstant.myBirds)) ?? 0;
    _myBirdsMemory += pow(2, index).toInt();
    await prefs.setInt(_k(GameConstant.myBirds), _myBirdsMemory);
    List<BirdModel> myBirds = []..addAll(state.myBirds);
    myBirds.add(bird);
    emit(state.copyWith(myBirds: myBirds));
    playSound(path: 'unlock');
    onSuccess?.call();
  }

  Future<void> getReward({
    Function? onSuccess,
    int value = 20,
    bool isCoin = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    // Start from the in-memory balance: the prefs key stays unset until the
    // first spend, so reading it here dropped the 25 starter coins.
    int _availableValue = isCoin ? state.coin : state.fruit;
    await prefs.setInt(isCoin ? _k(GameConstant.coin) : _k(GameConstant.fruit),
        _availableValue + value);
    if (isCoin) {
      emit(state.copyWith(coin: _availableValue + value));
    } else {
      emit(state.copyWith(fruit: _availableValue + value));
    }
    playSound(path: 'unlock');
    onSuccess?.call();
  }

  Future<void> mapChanged({
    required MapModel map,
    required int index,
    Function? onSuccess,
    Function(SettingStatus status)? onFailure,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (state.myMaps.contains(map)) {
      updateMapSprites(map, state.components);
      await prefs.setInt(_k(GameConstant.currentMap), index);
      emit(state.copyWith(currentMap: map));
      playSound(path: 'bird_collect');
    } else if (map.type == ItemType.needBuyByCoin && state.coin >= map.cost) {
      int _myMapsMemory = prefs.getInt(_k(GameConstant.myMaps)) ?? 0;
      _myMapsMemory += pow(2, index).toInt();
      await prefs.setInt(_k(GameConstant.myMaps), _myMapsMemory);
      await prefs.setInt(_k(GameConstant.coin), state.coin - map.cost);
      List<MapModel> myMaps = []..addAll(state.myMaps);
      myMaps.add(map);
      emit(state.copyWith(coin: state.coin - map.cost, myMaps: myMaps));
      playSound(path: 'unlock');
      onSuccess?.call();
    } else if (map.type == ItemType.needBuyByCoin && state.coin < map.cost) {
      onFailure?.call(SettingStatus.needMoreCoin);
    } else if (map.type == ItemType.needBuyByFruit && state.fruit >= map.cost) {
      int _myMapsMemory = prefs.getInt(_k(GameConstant.myMaps)) ?? 0;
      _myMapsMemory += pow(2, index).toInt();
      await prefs.setInt(_k(GameConstant.myMaps), _myMapsMemory);
      await prefs.setInt(_k(GameConstant.fruit), state.fruit - map.cost);
      List<MapModel> myMaps = []..addAll(state.myMaps);
      myMaps.add(map);
      emit(state.copyWith(fruit: state.fruit - map.cost, myMaps: myMaps));
      playSound(path: 'unlock');
      onSuccess?.call();
    } else if (map.type == ItemType.needBuyByFruit && state.fruit < map.cost) {
      onFailure?.call(SettingStatus.needMoreFruit);
    } else {
      onFailure?.call(SettingStatus.unknown);
    }
  }

  Future<void> unlockMap({
    required MapModel map,
    required int index,
    Function? onSuccess,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    int _myMapsMemory = prefs.getInt(_k(GameConstant.myMaps)) ?? 0;
    _myMapsMemory += pow(2, index).toInt();
    await prefs.setInt(_k(GameConstant.myMaps), _myMapsMemory);
    List<MapModel> myMaps = []..addAll(state.myMaps);
    myMaps.add(map);
    emit(state.copyWith(myMaps: myMaps));
    playSound(path: 'unlock');
    onSuccess?.call();
  }

  void playButtonSound() => playSound(path: 'select');

  Future<void> updateCoinAndFruit({int coin = 0, int fruit = 0}) async {
    if (coin + fruit == 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_k(GameConstant.coin), state.coin + coin);
    await prefs.setInt(_k(GameConstant.fruit), state.fruit + fruit);
    emit(state.copyWith(coin: state.coin + coin, fruit: state.fruit + fruit));
  }
}
