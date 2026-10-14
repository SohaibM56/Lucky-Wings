import 'package:flutter/material.dart';
import 'package:flip_flop/widgets/widgets.dart';

class UserGuide extends StatefulWidget {
  @override
  State<UserGuide> createState() => _UserGuideState();
}

class _UserGuideState extends State<UserGuide> {
  int _step = 0;

  double get _x1 {
    if (_step == 0) {
      return MediaQuery.of(context).size.width / 4;
    } else if (_step == 1) {
      return 24;
    } else if (_step == 2) {
      return MediaQuery.of(context).size.width - 32;
    }
    return 0;
  }

  double get _y1 {
    if (_step == 0) {
      return MediaQuery.of(context).size.height / 2;
    } else if (_step == 1 || _step == 2) {
      return 28;
    }
    return 0;
  }

  double get _radius => _step > 0 ? 20 : 0;

  String get _instruction {
    if (_step == 0) {
      return 'Click below area to play';
    } else if (_step == 1) {
      return 'Click left area to back to menu';
    }
    return 'Click right area to pause game';
  }

  double get _instructionMarginTop {
    if (_step == 0) {
      return (MediaQuery.of(context).size.height / 2) - 25;
    } else if (_step == 1 || _step == 2) {
      return 24;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        IgnorePointer(
          child: ClipPath(
            clipper: InvertedShapeClipper(
              x1: _x1,
              y1: _y1,
              dx: 220,
              dy: 120,
              radius: _radius,
              isOval: _step > 0,
            ),
            child: Container(
              color: Color.fromRGBO(0, 0, 0, 0.5),
            ),
          ),
        ),
        if (_step == 0)
          Positioned(
            top: 32,
            child: CustomText(
              'So, because this is your first time\njoining our game.\nHere are some guidelines',
              fontWeight: FontWeight.w600,
              strokeWidth: 0.25,
              textAlign: TextAlign.center,
            ),
          ),
        Positioned(
          top: _instructionMarginTop,
          child: CustomText(
            _instruction,
            fontSize: 16.5,
            fontWeight: FontWeight.w600,
            strokeWidth: 1.0,
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: CustomText(
              "Skip",
              fontSize: 18.0,
              fontWeight: FontWeight.w600,
              strokeWidth: 0.25,
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          child: TextButton(
            onPressed: () {
              _step++;
              if (_step > 2) {
                Navigator.pop(context);
              } else {
                setState(() {});
              }
            },
            child: CustomText(
              "Next",
              fontSize: 18.0,
              fontWeight: FontWeight.w600,
              strokeWidth: 0.25,
            ),
          ),
        ),
      ],
    );
  }
}

class InvertedShapeClipper extends CustomClipper<Path> {
  const InvertedShapeClipper({
    required this.x1,
    required this.y1,
    this.dx = 0,
    this.dy = 0,
    this.radius = 0,
    this.isOval = false,
  });

  final double x1;
  final double y1;
  final double dx;
  final double dy;
  final double radius;
  final bool isOval;

  @override
  Path getClip(Size size) {
    final path = Path()
      ..addRect(Rect.fromLTWH(0.0, 0.0, size.width, size.height))
      ..fillType = PathFillType.evenOdd;
    if (isOval) {
      path.addOval(Rect.fromCircle(center: Offset(x1, y1), radius: radius));
    } else {
      path.addRect(Rect.fromPoints(Offset(x1, y1), Offset(x1 + dx, y1 + dy)));
    }
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}
