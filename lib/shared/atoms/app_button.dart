import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final String? assetIconPath;
  final bool isDisabled;
  final bool isLoading;
  final double height;
  final double borderRadius;
  final List<Color>? gradientColors;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.assetIconPath,
    this.isDisabled = false,
    this.isLoading = false,
    this.height = 60,
    this.borderRadius = 16,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final isButtonDisabled = isDisabled || isLoading;

    final List<Color> effectiveGradientColors = gradientColors ??
        [
          const Color(0xFF8B5CF6),
          const Color(0xFF7C3AED),
        ];
    final List<Color> disabledGradientColors = gradientColors != null
        ? gradientColors!.map((c) => c.withOpacity(0.4)).toList()
        : [
            const Color(0xFF8B5CF6).withOpacity(0.4),
            const Color(0xFF7C3AED).withOpacity(0.4),
          ];

    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: isButtonDisabled
                  ? disabledGradientColors
                  : effectiveGradientColors),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: ElevatedButton(
          onPressed: isButtonDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (assetIconPath != null) ...[
                      Image.asset(
                        assetIconPath!,
                        height: 16,
                        width: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
