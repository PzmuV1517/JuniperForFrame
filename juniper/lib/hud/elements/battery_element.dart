import 'package:flutter/material.dart';
import '../hud_element.dart';

/// Battery level display element
class BatteryElement extends HudElement {
  BatteryElement({
    super.x = 540,
    super.y = 10,
    super.fontSize = 14,
    super.color = const Color(0xFFFFFFFF),
  }) : super(
    id: 'battery',
    name: 'Battery %',
  );

  @override
  String getText() {
    // Placeholder - would integrate with Frame battery API
    return '85%';
  }

  @override
  Size getSize() {
    // Approximate size for "100%" text
    return Size(fontSize * 2.5, fontSize * 1.2);
  }

  @override
  BatteryElement clone() {
    final element = BatteryElement(
      x: x,
      y: y,
      fontSize: fontSize,
      color: color,
    );
    element.isVisible = isVisible;
    return element;
  }
}
