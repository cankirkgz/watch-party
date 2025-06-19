import 'package:flutter/material.dart';

class StepNumberBadge extends StatelessWidget {
  final int number;

  const StepNumberBadge({super.key, required this.number});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: Color(0xFF7C3AED),
      child: Text(
        number.toString(),
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
