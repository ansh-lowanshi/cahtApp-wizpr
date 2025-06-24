import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class JumpingDots extends StatefulWidget {
  final int dotCount;
  final Color color;
  /// The maximum vertical offset (in logical pixels) for the jump.
  final double jumpHeight;
  /// Duration of a full cycle (all dots jump once sequence).
  final Duration duration;
  /// Size of each dot (width and height).
  final double dotSize;
  const JumpingDots({
    Key? key,
    this.dotCount = 5,
    required this.color,
    this.jumpHeight = 10.0,
    this.duration = const Duration(milliseconds: 800),
    this.dotSize = 10.0,
  }) : super(key: key);

  @override
  State<JumpingDots> createState() => _JumpingDotsState();
}

class _JumpingDotsState extends State<JumpingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Using AnimatedBuilder to rebuild each frame
    return SizedBox(
      height: widget.jumpHeight + widget.dotSize,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          List<Widget> dots = [];
          // Phase shift between dots: spread evenly over [0, 1)
          for (int i = 0; i < widget.dotCount; i++) {
            double phase = i / widget.dotCount;
            // Compute a value between 0..1 from controller.value, then add phase, wrap around
            double t = (_controller.value + phase) % 1.0;
            // Use sin curve: abs(sin(2π t)) goes 0->1->0 smoothly
            double offsetFactor = sin(2 * pi * t).abs(); 
            // Vertical offset: negative to move up
            double offsetY = -offsetFactor * widget.jumpHeight;
            dots.add(
              Transform.translate(
                offset: Offset(0, offsetY),
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }
          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: dots,
          );
        },
      ),
    );
  }
}
