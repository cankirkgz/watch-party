import 'package:flutter/material.dart';

class MicIconButton extends StatelessWidget {
  final VoidCallback onPressed;

  const MicIconButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    // Yazı yazma alanı ile aynı arka plan rengi
    final Color bgColor =
        const Color(0xFF23272F); // ChatInputField arka planı ile aynı
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bgColor,
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
            padding: const EdgeInsets.all(10),
            minimumSize: const Size(50, 50),
            maximumSize: const Size(50, 50),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Image.asset(
            "assets/icons/mic-icon.png",
            width: 18,
            height: 18,
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }
}
