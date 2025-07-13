import 'package:flutter/material.dart';
import '../hud_element.dart';

/// Date display element showing DAY/MONTH/YY format
class DateElement extends HudElement {
  DateElement({
    super.x = 10,
    super.y = 40,
    super.fontSize = 16,
    super.color = const Color(0xFFFFFFFF),
  }) : super(
    id: 'date',
    name: 'Date (DD/MM/YY)',
  );

  @override
  String getText() {
    final now = DateTime.now();
    final year = now.year.toString().substring(2); // Last 2 digits
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/$year';
  }

  @override
  Size getSize() {
    // Approximate size for "31/12/25" text
    return Size(fontSize * 4.2, fontSize * 1.2);
  }

  @override
  DateElement clone() {
    final element = DateElement(
      x: x,
      y: y,
      fontSize: fontSize,
      color: color,
    );
    element.isVisible = isVisible;
    return element;
  }
}
