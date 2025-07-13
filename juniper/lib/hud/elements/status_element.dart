import 'package:flutter/material.dart';
import '../hud_element.dart';

/// Status indicator element showing connection/recording status
class StatusElement extends HudElement {
  StatusElement({
    super.x = 300,
    super.y = 370,
    super.fontSize = 12,
    super.color = const Color(0xFF00FF00),
  }) : super(
    id: 'status',
    name: 'Status Indicator',
  );

  @override
  String getText() {
    // This would be updated based on app state
    // For now, showing a static indicator
    return '● READY';
  }

  @override
  Size getSize() {
    // Approximate size for "● RECORDING" text
    return Size(fontSize * 6, fontSize * 1.2);
  }

  @override
  StatusElement clone() {
    final element = StatusElement(
      x: x,
      y: y,
      fontSize: fontSize,
      color: color,
    );
    element.isVisible = isVisible;
    return element;
  }
}
