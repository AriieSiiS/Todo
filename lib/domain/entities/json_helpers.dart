import 'package:flutter/material.dart';

T enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}

List<String> stringList(Object? value) {
  return (value as List<dynamic>? ?? const <dynamic>[]).cast<String>();
}

IconData iconFromCodePoint(Object? value, IconData fallback) {
  final iconCatalog = <int, IconData>{
    Icons.label_rounded.codePoint: Icons.label_rounded,
    Icons.folder_open_rounded.codePoint: Icons.folder_open_rounded,
    Icons.bathtub_rounded.codePoint: Icons.bathtub_rounded,
    Icons.handyman_rounded.codePoint: Icons.handyman_rounded,
    Icons.self_improvement_rounded.codePoint: Icons.self_improvement_rounded,
    Icons.refresh_rounded.codePoint: Icons.refresh_rounded,
    Icons.calendar_month_rounded.codePoint: Icons.calendar_month_rounded,
    Icons.kitchen_rounded.codePoint: Icons.kitchen_rounded,
    Icons.shopping_cart_rounded.codePoint: Icons.shopping_cart_rounded,
    Icons.fitness_center_rounded.codePoint: Icons.fitness_center_rounded,
    Icons.notifications_active_rounded.codePoint:
        Icons.notifications_active_rounded,
    Icons.spa_outlined.codePoint: Icons.spa_outlined,
    Icons.favorite_border_rounded.codePoint: Icons.favorite_border_rounded,
    Icons.auto_awesome_outlined.codePoint: Icons.auto_awesome_outlined,
    Icons.local_florist_outlined.codePoint: Icons.local_florist_outlined,
    Icons.water_drop_outlined.codePoint: Icons.water_drop_outlined,
    Icons.dark_mode_outlined.codePoint: Icons.dark_mode_outlined,
    Icons.sentiment_satisfied_alt_outlined.codePoint:
        Icons.sentiment_satisfied_alt_outlined,
  };
  if (value is! int) {
    return fallback;
  }
  return iconCatalog[value] ?? fallback;
}
