import 'package:flutter/material.dart';
import '../hud_element.dart';

/// Time display element showing HOUR:MINUTE in 24H format
class TimeElement extends HudElement {
  TimeElement({
    super.x = 10,
    super.y = 10,
    super.fontSize = 18,
    super.color = const Color(0xFFFFFFFF),
  }) : super(
    id: 'time',
    name: 'Time (24H)',
  );

  @override
  String getText() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Size getSize() {
    // Approximate size for "23:59" text
    return Size(fontSize * 2.8, fontSize * 1.2);
  }

  @override
  TimeElement clone() {
    final element = TimeElement(
      x: x,
      y: y,
      fontSize: fontSize,
      color: color,
    );
    element.isVisible = isVisible;
    return element;
  }
}
