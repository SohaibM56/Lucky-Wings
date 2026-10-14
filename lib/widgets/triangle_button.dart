import 'package:flip_flop/utils/utils.dart';
import 'package:flutter/material.dart';

class TriangleButton extends StatelessWidget {
  TriangleButton({
    Key? key,
    this.onTap,
    required this.child,
    required this.path,
  }) : super(key: key);

  final Function? onTap;
  final Widget child;
  final Path path;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      child: GestureDetector(
        onTap: () => onTap?.call(),
        // child: triangle,
        child: child,
      ),
      clipper: TriangleClipper(path: path),
    );
  }
}
