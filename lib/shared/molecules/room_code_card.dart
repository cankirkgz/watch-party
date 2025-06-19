import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RoomCodeCard extends StatefulWidget {
  final String roomCode;
  const RoomCodeCard({super.key, required this.roomCode});

  @override
  State<RoomCodeCard> createState() => _RoomCodeCardState();
}

class _RoomCodeCardState extends State<RoomCodeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shadowOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _shadowOpacityAnimation = Tween<double>(begin: 0.137, end: 0.475)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color getShadowColor(double opacity) {
    return const Color(0xFF8B5CF6).withOpacity(opacity);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _shadowOpacityAnimation,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: 230,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF8B5CF6),
              ),
              boxShadow: [
                BoxShadow(
                  color: getShadowColor(_shadowOpacityAnimation.value),
                  blurRadius:
                      lerpDouble(23.71, 33.71, _shadowOpacityAnimation.value)!,
                  offset: Offset.zero,
                ),
              ],
            ),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Room Code',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                Text(
                  widget.roomCode,
                  style: const TextStyle(
                    fontSize: 48,
                    color: Color(0xFFA78BFA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                CopyCodeButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.roomCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Room code copied!')),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class CopyCodeButton extends StatelessWidget {
  final Color iconColor;
  final VoidCallback? onPressed;
  const CopyCodeButton(
      {super.key, this.iconColor = const Color(0xFFA78BFA), this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0x338B5CF6), // %20 opacity
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0x4D8B5CF6), // %30 opacity
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icons/copy-icon.png',
              width: 20,
              height: 20,
              color: iconColor,
            ),
            const SizedBox(width: 8),
            const Text(
              'Copy Code',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFA78BFA),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
