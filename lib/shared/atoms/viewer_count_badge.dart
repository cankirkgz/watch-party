import 'package:flutter/material.dart';

class ViewerCountBadge extends StatelessWidget {
  final int viewerCount;
  const ViewerCountBadge({super.key, required this.viewerCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Color(0xFF22C55E),
            shape: BoxShape.circle,
          ),
        ),
        Text(
          "$viewerCount",
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF9CA3AF),
            fontWeight: FontWeight.normal,
          ),
        )
      ],
    );
  }
}
