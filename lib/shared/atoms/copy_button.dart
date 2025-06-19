import 'package:flutter/material.dart';

class CopyButton extends StatelessWidget {
  final VoidCallback onPressed;

  const CopyButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final List<Color> gradientColors = [
      const Color(0xFF8B5CF6),
      const Color(0xFF7C3AED),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: Size(0, 34),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                "assets/icons/copy-icon.png",
                width: 18,
                height: 18,
              ),
              SizedBox(width: 6),
              Text(
                "Copy",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
