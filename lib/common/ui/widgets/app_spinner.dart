import 'package:flutter/material.dart';

class AppSpinner extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color color;

  const AppSpinner({
    super.key,
    required this.icon,
    this.size = 32,
    this.color = Colors.blue,
  });

  @override
  State<AppSpinner> createState() => _AppSpinnerState();
}

class _AppSpinnerState extends State<AppSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _ctrl,
      child: Icon(
        widget.icon,
        size: widget.size,
        color: widget.color,
      ),
    );
  }
}
