import 'package:flutter/material.dart';

class ColorUtils {
  static const List<Color> popularColors = [
    // --- ROW 1: Essentials ---
    Color(0xFF007AFF), Color(0xFF34C759), Color(0xFFFF2D55), Color(0xFFAF52DE),
    Color(0xFFFF9500), Color(0xFF5AC8FA), Color(0xFFFF3B30), Color(0xFF5856D6),
    // --- ROW 2: Vibrant ---
    Color(0xFF00C7BE), Color(0xFFFFCC00), Color(0xFF8E8E93), Color(0xFFE91E63),
    Color(0xFF9C27B0), Color(0xFF673AB7), Color(0xFF3F51B5), Color(0xFF2196F3),
    // --- ROW 3: Nature ---
    Color(0xFF03A9F4), Color(0xFF00BCD4), Color(0xFF009688), Color(0xFF4CAF50),
    Color(0xFF8BC34A), Color(0xFFCDDC39), Color(0xFFFFEB3B), Color(0xFFFFC107),
    // --- ROW 4: Earth & Deep ---
    Color(0xFFFF9800), Color(0xFFFF5722), Color(0xFF795548), Color(0xFF607D8B),
    Color(0xFFD32F2F), Color(0xFFC2185B), Color(0xFF7B1FA2), Color(0xFF512DA8),
    // --- ROW 5: Professional ---
    Color(0xFF303F9F), Color(0xFF1976D2), Color(0xFF0288D1), Color(0xFF0097A7),
    Color(0xFF00796B), Color(0xFF388E3C), Color(0xFF689F38), Color(0xFFAFB42B),
    // --- ROW 6: Brights ---
    Color(0xFFFBC02D), Color(0xFFFFA000), Color(0xFFF57C00), Color(0xFFE64A19),
    Color(0xFF5D4037), Color(0xFF455A64), Color(0xFF1A237E), Color(0xFF0D47A1),
    // --- ROW 7: Exotic ---
    Color(0xFF01579B), Color(0xFF006064), Color(0xFF004D40), Color(0xFF1B5E20),
    Color(0xFF33691E), Color(0xFF827717), Color(0xFFF57F17), Color(0xFFFF6F00),
    // --- ROW 8: Deep Pastel ---
    Color(0xFFE65100), Color(0xFFBF360C), Color(0xFF3E2723), Color(0xFF263238),
    Color(0xFFAD1457), Color(0xFF6A1B9A), Color(0xFF4527A0), Color(0xFF283593),
  ];

  static String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  static Color getNextUniqueColor(List<String> existingHexColors) {
    for (Color color in popularColors) {
      String hex = colorToHex(color);
      if (!existingHexColors.contains(hex.toUpperCase())) {
        return color;
      }
    }
    return popularColors[existingHexColors.length % popularColors.length];
  }
}