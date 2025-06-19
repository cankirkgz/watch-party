import 'package:flutter/material.dart';

class SendIconButton extends StatelessWidget {
  final VoidCallback onPressed;

  const SendIconButton({super.key, required this.onPressed});

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
        padding: const EdgeInsets.symmetric(vertical: 0),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.all(10), // ✅ içte 10 padding (simetrik)
            minimumSize: const Size(50, 50), // ✅ dış boyut
            maximumSize: const Size(50, 50),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Image.asset(
            "assets/icons/send-icon.png",
            width: 18,
            height: 18,
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }
}
