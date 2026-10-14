import 'package:flip_flop/theme.dart';
import 'package:flip_flop/utils/utils.dart';
import 'package:flip_flop/widgets/widgets.dart';
import 'package:flutter/material.dart';

class RibbonShape extends StatelessWidget {
  const RibbonShape({
    this.width = 200,
    this.height = 50,
    required this.color,
    this.showTitle = false,
    this.title = "",
  });

  final double width;
  final double height;
  final Color color;
  final bool showTitle;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Container(
          margin: EdgeInsets.only(bottom: 20.0),
          child: ClipPath(
            clipper: ArcClipper(),
            child: Container(
              width: width,
              height: height,
              color: Colors.yellow,
            ),
          ),
        ),
        Positioned(
          bottom: 0.0,
          child: ClipPath(
            clipper: _TriangleClipper(),
            child: Container(
              width: 18.0,
              height: 20.0,
              color: color,
            ),
          ),
        ),
        Positioned(
          bottom: 20.0,
          child: Container(
            child: Container(
              width: width,
              height: 1.5,
              color: wood_smoke,
            ),
          ),
        ),
        if (showTitle)
          Positioned(
            bottom: 20.0 + height / 2 - 9,
            left: 28,
            child: CustomText(
              title,
              fontWeight: FontWeight.w600,
              fontFamily: fontFamily,
              fontSize: 18,
              strokeWidth: 0.15,
              color: wood_smoke,
              borderColor: white,
            ),
          ),
      ],
    );
  }
}

class ArcClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(15.0, 0.0);

    var firstControlPoint = Offset(7.5, 2.0);
    var firstPoint = Offset(5.0, 5.0);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy,
        firstPoint.dx, firstPoint.dy);

    var secondControlPoint = Offset(2.0, 7.5);
    var secondPoint = Offset(0.0, 15.0);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy,
        secondPoint.dx, secondPoint.dy);

    path.lineTo(0.0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width - 20, size.height / 2);
    path.lineTo(size.width, 0.0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0.0, 0.0);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0.0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
