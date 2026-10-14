import 'package:flutter/material.dart';

enum TriangleShape {
  upperHalfSquare,
  bottomHalfSquare,
}

class TriangleClipper extends CustomClipper<Path> {
  const TriangleClipper({required this.path});

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(TriangleClipper oldClipper) {
    return false;
  }
}

extension ExtensionTriangleType on TriangleShape {
  Path path(double width, double height) {
    switch (this) {
      case TriangleShape.upperHalfSquare:
        return Path()
          ..moveTo(0, 0)
          ..lineTo(width, 0)
          ..lineTo(width, height);

      case TriangleShape.bottomHalfSquare:
        return Path()
          ..moveTo(0, 0)
          ..lineTo(0, height)
          ..lineTo(width, height);
    }
  }
}
