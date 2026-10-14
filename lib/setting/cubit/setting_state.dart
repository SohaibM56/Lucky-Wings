part of 'setting_cubit.dart';

enum SettingStatus {
  unknown,
  initSetting,
  initSettingDone,
  initRewardedAdInProgress,
  initRewardedAdSuccess,
  initRewardedAdFailure,
  needMoreCoin,
  needMoreFruit,
}

class SettingState extends Equatable {
  const SettingState({
    this.birds = const [],
    this.myBirds = const [],
    this.currentBird = BirdModel.empty,
    this.maps = const [],
    this.myMaps = const [],
    this.currentMap = MapModel.empty,
    this.components = const [],
    this.status = SettingStatus.unknown,
    this.coin = 25,
    this.fruit = 0,
  });

  /// Bird
  final List<BirdModel> birds;
  final List<BirdModel> myBirds;
  final BirdModel currentBird;

  /// Map
  final List<MapModel> maps;
  final List<MapModel> myMaps;
  final MapModel currentMap;

  final List<Component> components;
  final SettingStatus status;
  final int coin;
  final int fruit;

  @override
  List<Object?> get props => [
        birds,
        myBirds,
        currentBird,
        maps,
        myMaps,
        currentMap,
        components,
        status,
        coin,
        fruit,
      ];

  SettingState copyWith({
    List<BirdModel>? birds,
    List<BirdModel>? myBirds,
    BirdModel? currentBird,
    List<MapModel>? maps,
    List<MapModel>? myMaps,
    MapModel? currentMap,
    List<Component>? components,
    SettingStatus? status,
    int? coin,
    int? fruit,
  }) {
    return SettingState(
      birds: birds ?? this.birds,
      myBirds: myBirds ?? this.myBirds,
      currentBird: currentBird ?? this.currentBird,
      maps: maps ?? this.maps,
      myMaps: myMaps ?? this.myMaps,
      currentMap: currentMap ?? this.currentMap,
      components: components ?? this.components,
      status: status ?? this.status,
      coin: coin ?? this.coin,
      fruit: fruit ?? this.fruit,
    );
  }
}
