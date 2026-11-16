import 'package:flutter/material.dart';

import '../../core/food_style.dart';

class FoodAvatar extends StatelessWidget {
  const FoodAvatar({
    super.key,
    required this.category,
    this.size = 48,
    this.emoji,
  });

  final String category;
  final double size;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(category);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.26 : 0.15),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(
        emoji ?? categoryEmoji(category),
        style: TextStyle(fontSize: size * 0.46),
      ),
    );
  }
}
