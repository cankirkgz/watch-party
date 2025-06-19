import 'package:flutter/material.dart';

class FeatureItem extends StatelessWidget {
  final String iconAssetPath;
  final String text;

  const FeatureItem({
    super.key,
    required this.iconAssetPath,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              iconAssetPath,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
