import 'package:flutter/material.dart';

/// Base class for all HUD elements
abstract class HudElement {
  String id;
  String name;
  bool isVisible;
  double x; // X position (0-640)
  double y; // Y position (0-400)
  double fontSize;
  Color color;

  HudElement({
    required this.id,
    required this.name,
    this.isVisible = true,
    this.x = 0,
    this.y = 0,
    this.fontSize = 16,
    this.color = Colors.white,
  });

  /// Generate the text content for this element
  String getText();

  /// Get the display bounds for positioning
  Size getSize();

  /// Convert to JSON for saving
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isVisible': isVisible,
      'x': x,
      'y': y,
      'fontSize': fontSize,
      'color': color.value,
    };
  }

  /// Create from JSON
  void fromJson(Map<String, dynamic> json) {
    isVisible = json['isVisible'] ?? true;
    x = (json['x'] ?? 0).toDouble();
    y = (json['y'] ?? 0).toDouble();
    fontSize = (json['fontSize'] ?? 16).toDouble();
    color = Color(json['color'] ?? Colors.white.value);
  }

  /// Create a copy of this element
  HudElement clone();
}
