
import 'package:flutter/material.dart';

abstract final class AdventureColors {
  static const neonGreen = Color(0xFF9DFF1E);
  static const neonBlue = Color(0xFF00CFFF);
  static const neonOrange = Color(0xFFFF9D00);
  static const neonPurple = Color(0xFFB58CFF);
  static const neonLime = Color(0xFFD4FF52);

  static Color forType(String type) {
    switch (type.toLowerCase()) {
      case 'trekking':
        return neonGreen;
      case 'hiking':
        return neonLime;
      case 'cycling':
        return neonOrange;
      case 'kayaking':
        return neonBlue;
      case 'camping':
        return neonPurple;
      default:
        return neonGreen;
    }
  }
}
