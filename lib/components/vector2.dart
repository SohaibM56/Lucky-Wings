import 'dart:math';

class Vector2 {
  const Vector2({this.a = 0, this.b = 0});

  final double a;
  final double b;

  Vector2 copyWith({double? a, double? b}) {
    return Vector2(a: a ?? this.a, b: b ?? this.b);
  }

  static const zero = const Vector2(a: 0, b: 0);

  double get value => sqrt(a * a + b * b);

  Vector2 move(Vector2 v) => this + v;

  Vector2 operator +(Vector2 other) {
    return Vector2(a: this.a + other.a, b: this.b + other.b);
  }

  Vector2 operator -(Vector2 other) {
    return Vector2(a: this.a - other.a, b: this.b - other.b);
  }
}
