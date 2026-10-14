import 'package:equatable/equatable.dart';
import 'package:flip_flop/components/components.dart';

enum MapType {
  unknown,
  graveyard,
  desert,
  spring,
  winter,
}

class MapModel extends Equatable {
  const MapModel({
    required this.sprites,
    required this.type,
    this.mapType = MapType.unknown,
    this.name = "anonymous",
    this.cost = 0,
    this.spriteRatio = 1,
  });

  final List<String> sprites;
  final ItemType type;
  final MapType mapType;
  final String name;
  final int cost;
  final double spriteRatio;

  MapModel.fromJson(Map<String, dynamic> json)
      : sprites = (json['sprites'] as List).map((e) => e.toString()).toList(),
        type = json['type'],
        mapType = json['mapType'],
        name = json['name'],
        cost = json['cost'],
        spriteRatio = json['spriteRatio'];

  Map<String, dynamic> toJson() => {
        'sprites': sprites,
        'type': type,
        'mapType': mapType,
        'name': name,
        'cost': cost,
      };

  @override
  List<Object?> get props => [name];

  static const empty = const MapModel(
    sprites: ['assets/images/background/jungle2.png'],
    mapType: MapType.spring,
    type: ItemType.free,
    name: 'Mysterious Forest',
    cost: 0,
    spriteRatio: 1.0,
  );

  MapModel copyWith({
    List<String>? sprites,
    MapType? mapType,
    ItemType? type,
    String? name,
    int? cost,
  }) {
    return MapModel(
      sprites: sprites ?? this.sprites,
      mapType: mapType ?? this.mapType,
      type: type ?? this.type,
      name: name ?? this.name,
      cost: cost ?? this.cost,
    );
  }

  String get groundImage {
    switch (mapType) {
      case MapType.graveyard:
        return "assets/images/background/ground2.png";
      case MapType.desert:
        return "assets/images/background/ground4.png";
      case MapType.spring:
        return "assets/images/background/ground1.png";
      case MapType.winter:
        return "assets/images/background/ground3.png";
      default:
        return "assets/images/background/ground3.png";
    }
  }

  String get crateImage {
    switch (mapType) {
      case MapType.graveyard:
        return "assets/images/objects/crate3.png";
      case MapType.desert:
        return "assets/images/objects/crate2.png";
      case MapType.spring:
        return "assets/images/objects/crate1.png";
      case MapType.winter:
        return "assets/images/objects/crate4.png";
      default:
        return "";
    }
  }
}
