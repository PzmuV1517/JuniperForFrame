import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'hud_element.dart';
import 'elements/time_element.dart';
import 'elements/date_element.dart';
import 'elements/battery_element.dart';
import 'elements/text_element.dart';
import 'elements/status_element.dart';

/// HUD Manager handles all HUD elements and their configuration
class HudManager {
  static const String _storageKey = 'hud_elements';
  List<HudElement> elements = [];

  HudManager() {
    _initializeDefaultElements();
  }

  void _initializeDefaultElements() {
    elements = [
      TimeElement(),
      DateElement(),
    ];
  }

  /// Get all available element types for adding new elements
  List<HudElement> getAvailableElementTypes() {
    return [
      TimeElement(),
      DateElement(),
      BatteryElement(),
      StatusElement(),
      TextElement(),
    ];
  }

  /// Add a new element
  void addElement(HudElement element) {
    elements.add(element.clone());
    saveConfiguration();
  }

  /// Remove an element
  void removeElement(String elementId) {
    elements.removeWhere((element) => element.id == elementId);
    saveConfiguration();
  }

  /// Update an element
  void updateElement(HudElement updatedElement) {
    final index = elements.indexWhere((element) => element.id == updatedElement.id);
    if (index != -1) {
      elements[index] = updatedElement;
      saveConfiguration();
    }
  }

  /// Get visible elements only
  List<HudElement> getVisibleElements() {
    return elements.where((element) => element.isVisible).toList();
  }

  /// Generate HUD text for Frame display
  String generateHudText() {
    final visibleElements = getVisibleElements();
    if (visibleElements.isEmpty) {
      return 'No HUD elements';
    }

    // Sort by Y position, then X position for consistent display
    visibleElements.sort((a, b) {
      if ((a.y - b.y).abs() < 20) { // Same line (within 20px)
        return a.x.compareTo(b.x);
      }
      return a.y.compareTo(b.y);
    });

    return visibleElements.map((element) => element.getText()).join('  ');
  }

  /// Save configuration to shared preferences
  Future<void> saveConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final elementsJson = elements.map((element) => element.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(elementsJson));
    } catch (e) {
      debugPrint('Error saving HUD configuration: $e');
    }
  }

  /// Load configuration from shared preferences
  Future<void> loadConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configString = prefs.getString(_storageKey);
      
      if (configString != null) {
        final configList = jsonDecode(configString) as List;
        elements.clear();
        
        for (final elementData in configList) {
          final elementType = elementData['id'] as String;
          HudElement? element;
          
          if (elementType.startsWith('time')) {
            element = TimeElement();
          } else if (elementType.startsWith('date')) {
            element = DateElement();
          } else if (elementType.startsWith('battery')) {
            element = BatteryElement();
          } else if (elementType.startsWith('status')) {
            element = StatusElement();
          } else if (elementType.startsWith('text_')) {
            element = TextElement();
          }
          
          if (element != null) {
            element.fromJson(elementData);
            elements.add(element);
          }
        }
      } else {
        _initializeDefaultElements();
      }
    } catch (e) {
      debugPrint('Error loading HUD configuration: $e');
      _initializeDefaultElements();
    }
  }

  /// Reset to default configuration
  void resetToDefaults() {
    _initializeDefaultElements();
    saveConfiguration();
  }
}
