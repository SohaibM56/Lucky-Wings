import 'package:equatable/equatable.dart';
import 'package:flip_flop/components/components.dart';

class BirdModel extends Equatable {
  const BirdModel({
    required this.sprites,
    required this.type,
    this.name = "anonymous",
    this.cost = 0,
    this.spriteRatio = 1,
  });

  final List<String> sprites;
  final ItemType type;
  final String name;
  final int cost;
  final double spriteRatio;

  BirdModel.fromJson(Map<String, dynamic> json)
      : sprites = (json['sprites'] as List).map((e) => e.toString()).toList(),
        type = json['type'],
        name = json['name'],
        cost = json['cost'],
        spriteRatio = json['spriteRatio'];

  Map<String, dynamic> toJson() => {
        'sprites': sprites,
        'type': type,
        'name': name,
        'cost': cost,
      };

  @override
  List<Object?> get props => [name];

  static const empty = const BirdModel(
    sprites: const [
      'assets/images/birds/char2/frame-1.png',
      'assets/images/birds/char2/frame-2.png',
      'assets/images/birds/char2/frame-3.png',
      'assets/images/birds/char2/frame-4.png',
      'assets/images/birds/char2/frame-5.png',
      'assets/images/birds/char2/frame-6.png',
    ],
    type: ItemType.free,
    name: 'Bogpa',
    cost: 0,
    spriteRatio: 418 / 404,
  );

  BirdModel copyWith({
    List<String>? sprites,
    ItemType? type,
    String? name,
    int? cost,
  }) {
    return BirdModel(
      sprites: sprites ?? this.sprites,
      type: type ?? this.type,
      name: name ?? this.name,
      cost: cost ?? this.cost,
    );
  }
}
