# HUD Customization System

## Overview
The HUD (Heads-Up Display) customization system allows users to fully customize what appears on the Frame's 640x400 RGB display when they single-tap.

## Features

### Available HUD Elements
- **Time Element**: Shows current time in 24H format (HH:MM)
- **Date Element**: Shows current date (DD/MM/YY)
- **Battery Element**: Shows battery percentage (placeholder)
- **Status Element**: Shows connection/recording status
- **Text Element**: Custom user-defined text

### Customization Options
- **Position**: Drag elements anywhere on the 640x400 display
- **Visibility**: Show/hide individual elements
- **Font Size**: Adjust size from 8-32px
- **Custom Text**: Edit text for custom elements
- **Add/Remove**: Add new elements or remove existing ones

### How to Use

1. **Access Customization**: Tap the dashboard icon in the app bar
2. **Visual Preview**: See a scaled preview of the Frame display (640x400)
3. **Element Management**: 
   - Tap elements in preview to select them
   - Drag elements to reposition them
   - Use the element list on the right to manage properties
4. **Add Elements**: Tap the + button to add new element types
5. **Properties Panel**: When an element is selected, adjust:
   - Visibility toggle
   - X/Y position sliders
   - Font size slider
   - Custom text (for text elements)

### File Structure
```
lib/
├── hud/
│   ├── hud_element.dart          # Base class for all elements
│   ├── hud_manager.dart          # Manages all elements and persistence
│   └── elements/
│       ├── time_element.dart     # Time display (HH:MM)
│       ├── date_element.dart     # Date display (DD/MM/YY)
│       ├── battery_element.dart  # Battery percentage
│       ├── status_element.dart   # Status indicator
│       └── text_element.dart     # Custom text element
└── pages/
    └── hud_customization_page.dart # UI for customization
```

### Adding New Element Types

1. Create a new file in `lib/hud/elements/`
2. Extend `HudElement` base class
3. Implement required methods:
   - `getText()`: Return the text to display
   - `getSize()`: Return approximate size for positioning
   - `clone()`: Create a copy of the element
4. Add to `HudManager.getAvailableElementTypes()`
5. Add loading logic in `HudManager.loadConfiguration()`

### Persistence
- Settings are automatically saved to SharedPreferences
- Configuration persists between app restarts
- Reset to defaults option available

### Integration
The HUD system integrates with the main Frame app:
- Single tap shows the customized HUD
- HUD displays for 3 seconds then returns to idle
- All elements update in real-time (time, date, etc.)
