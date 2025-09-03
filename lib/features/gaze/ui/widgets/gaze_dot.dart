import 'package:flutter/material.dart';

class GazeDot extends StatelessWidget {
  final Offset offset;
  final bool ok;
  const GazeDot({super.key, required this.offset, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: offset.dx - 5,
      top: offset.dy - 5,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: ok ? Colors.green : Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
