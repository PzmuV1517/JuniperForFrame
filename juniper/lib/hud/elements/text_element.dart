import 'package:flutter/material.dart';
import '../hud_element.dart';

/// Custom text element that users can add
class TextElement extends HudElement {
  String customText;

  TextElement({
    this.customText = 'Custom Text',
    super.x = 100,
    super.y = 100,
    super.fontSize = 16,
    super.color = const Color(0xFFFFFFFF),
  }) : super(
    id: 'text_${DateTime.now().millisecondsSinceEpoch}',
    name: 'Custom Text',
  );

  @override
  String getText() {
    return customText;
  }

  @override
  Size getSize() {
    // Estimate size based on text length
    return Size(fontSize * customText.length * 0.6, fontSize * 1.2);
  }

  @override
  TextElement clone() {
    final element = TextElement(
      customText: customText,
      x: x,
      y: y,
      fontSize: fontSize,
      color: color,
    );
    element.isVisible = isVisible;
    return element;
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['customText'] = customText;
    return json;
  }

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    customText = json['customText'] ?? 'Custom Text';
  }
}
