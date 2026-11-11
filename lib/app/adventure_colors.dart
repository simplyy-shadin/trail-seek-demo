
import 'package:flutter/material.dart';

abstract final class AdventureColors {
  static const Color trekking = Color(0xFF9DFF1E);
  static const Color hiking = Color(0xFFFF9500);
  static const Color cycling = Color(0xFFFF3B30);
  static const Color kayaking = Color(0xFF00CFFF);
  static const Color camping = Color(0xFFB266FF);

  static Color forType(String type) {
    switch (type.toLowerCase()) {
      case 'trekking':
        return trekking;
      case 'hiking':
        return hiking;
      case 'cycling':
        return cycling;
      case 'kayaking':
        return kayaking;
      case 'camping':
        return camping;
      default:
        return trekking;
    }
  }
}
