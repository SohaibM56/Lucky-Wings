// import 'package:flip_flop/components/components.dart';
// import 'package:flutter/material.dart';
//
// class Scorer extends CustomPainter {
//   Scorer({required this.sprite});
//
//   int score = 0;
//   Sprite sprite;
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     Offset a = Offset(0, 0);
//     Offset b = Offset(size.width, size.height);
//     paintImage(
//       canvas: canvas,
//       rect: Rect.fromPoints(a, b),
//       image: this.sprite.path.first,
//       fit: BoxFit.fill,
//     );
//     drawScore(canvas, size);
//   }
//
//   @override
//   bool shouldRepaint(Scorer oldScorer) => score > oldScorer.score;
//
//   void drawScore(Canvas canvas, Size size) {
//     final textStyle = TextStyle(
//       fontFamily: 'DiloWorld',
//       fontWeight: FontWeight.bold,
//       fontSize: 26,
//       foreground: Paint()
//         ..style = PaintingStyle.stroke
//         ..strokeWidth = 2
//         ..color = Colors.white,
//     );
//     final textSpan = TextSpan(
//       text: '$score',
//       style: textStyle,
//     );
//     final textPainter = TextPainter(
//       text: textSpan,
//       textDirection: TextDirection.ltr,
//     );
//     textPainter.layout(
//       minWidth: 0,
//       maxWidth: size.width,
//     );
//     final offset = Offset(size.width + 24, (size.height - 26) / 2);
//     textPainter.paint(canvas, offset);
//   }
// }
