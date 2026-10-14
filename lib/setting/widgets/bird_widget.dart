import 'package:flutter/material.dart';

class BirdWidget extends StatefulWidget {
  const BirdWidget({
    Key? key,
    this.sprites = const [],
    this.startAnimation = true,
  }) : super(key: key);
  final List<String> sprites;
  final bool startAnimation;

  @override
  State<BirdWidget> createState() => _BirdWidgetState();
}

class _BirdWidgetState extends State<BirdWidget>
    with SingleTickerProviderStateMixin {
  late Animation<int> animation;
  late AnimationController controller;

  @override
  void initState() {
    controller = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    animation = IntTween(begin: 0, end: 2).animate(
      CurvedAnimation(
        parent: controller,
        curve: Curves.linear,
      ),
    );
    if (widget.startAnimation) controller.repeat(reverse: true);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) => Image.asset(
        widget.sprites[animation.value],
        fit: BoxFit.cover,
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
