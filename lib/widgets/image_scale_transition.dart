import 'package:flutter/material.dart';

class ImageScaleTransition extends StatefulWidget {
  ImageScaleTransition({
    Key? key,
    this.aspectRatio = 1,
    required this.backgroundImage,
    this.fit = BoxFit.cover,
    this.duration = const Duration(milliseconds: 600),
    this.begin = 0.8,
    this.end = 1.0,
    required this.width,
  }) : super(key: key);

  final double aspectRatio;
  final String backgroundImage;
  final BoxFit fit;
  final Duration duration;
  final double begin;
  final double end;
  final double width;

  @override
  _ImageScaleTransitionState createState() => _ImageScaleTransitionState();
}

class _ImageScaleTransitionState extends State<ImageScaleTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<double>(begin: widget.begin, end: widget.end).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
    _controller.repeat(reverse: true);
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: SizedBox(
        width: widget.width,
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: Image.asset(
            widget.backgroundImage,
            fit: widget.fit,
          ),
        ),
      ),
    );
  }
}