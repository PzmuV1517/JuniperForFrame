import 'package:flutter/material.dart';
import '../hud/hud_manager.dart';
import '../hud/hud_element.dart';
import '../hud/elements/text_element.dart';

class HudCustomizationPage extends StatefulWidget {
  final HudManager hudManager;

  const HudCustomizationPage({
    super.key,
    required this.hudManager,
  });

  @override
  State<HudCustomizationPage> createState() => _HudCustomizationPageState();
}

class _HudCustomizationPageState extends State<HudCustomizationPage> {
  HudElement? _selectedElement;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HUD Customization'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                widget.hudManager.resetToDefaults();
              });
            },
            tooltip: 'Reset to defaults',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddElementDialog,
            tooltip: 'Add element',
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Row(
        children: [
          // Frame Preview (640x400 scale)
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              child: AspectRatio(
                aspectRatio: 640 / 400,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    color: Colors.grey[900],
                  ),
                  child: Stack(
                    children: _buildFramePreview(),
                  ),
                ),
              ),
            ),
          ),
          // Element List & Properties
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey[850],
              child: Column(
                children: [
                  _buildElementList(),
                  if (_selectedElement != null) _buildElementProperties(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFramePreview() {
    final containerSize = MediaQuery.of(context).size;
    final scale = (containerSize.width * 0.6) / 640; // Approximate scale

    return widget.hudManager.elements.map((element) {
      final isSelected = _selectedElement?.id == element.id;
      
      return Positioned(
        left: element.x * scale,
        top: element.y * scale,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedElement = element;
            });
          },
          onPanUpdate: (details) {
            setState(() {
              element.x = (element.x + details.delta.dx / scale).clamp(0, 640 - element.getSize().width);
              element.y = (element.y + details.delta.dy / scale).clamp(0, 400 - element.getSize().height);
              widget.hudManager.saveConfiguration();
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.transparent,
              border: isSelected ? Border.all(color: Colors.blue, width: 1) : null,
            ),
            child: Text(
              element.isVisible ? element.getText() : '[Hidden] ${element.name}',
              style: TextStyle(
                color: element.isVisible ? element.color : Colors.grey,
                fontSize: element.fontSize * scale,
                decoration: element.isVisible ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildElementList() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'HUD Elements',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: widget.hudManager.elements.length,
                itemBuilder: (context, index) {
                  final element = widget.hudManager.elements[index];
                  final isSelected = _selectedElement?.id == element.id;
                  
                  return Card(
                    color: isSelected ? Colors.blue[700] : Colors.grey[700],
                    child: ListTile(
                      leading: Icon(
                        element.isVisible ? Icons.visibility : Icons.visibility_off,
                        color: element.isVisible ? Colors.green : Colors.grey,
                      ),
                      title: Text(
                        element.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'X: ${element.x.toInt()}, Y: ${element.y.toInt()}',
                        style: TextStyle(color: Colors.grey[300]),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            widget.hudManager.removeElement(element.id);
                            if (_selectedElement?.id == element.id) {
                              _selectedElement = null;
                            }
                          });
                        },
                      ),
                      onTap: () {
                        setState(() {
                          _selectedElement = element;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElementProperties() {
    if (_selectedElement == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        border: const Border(top: BorderSide(color: Colors.grey)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Properties: ${_selectedElement!.name}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Visibility toggle
          SwitchListTile(
            title: const Text('Visible', style: TextStyle(color: Colors.white)),
            value: _selectedElement!.isVisible,
            onChanged: (value) {
              setState(() {
                _selectedElement!.isVisible = value;
                widget.hudManager.saveConfiguration();
              });
            },
          ),
          
          // Position sliders
          _buildSlider(
            'X Position',
            _selectedElement!.x,
            0,
            640,
            (value) {
              setState(() {
                _selectedElement!.x = value;
                widget.hudManager.saveConfiguration();
              });
            },
          ),
          
          _buildSlider(
            'Y Position',
            _selectedElement!.y,
            0,
            400,
            (value) {
              setState(() {
                _selectedElement!.y = value;
                widget.hudManager.saveConfiguration();
              });
            },
          ),
          
          _buildSlider(
            'Font Size',
            _selectedElement!.fontSize,
            8,
            32,
            (value) {
              setState(() {
                _selectedElement!.fontSize = value;
                widget.hudManager.saveConfiguration();
              });
            },
          ),
          
          // Custom text for TextElement
          if (_selectedElement is TextElement)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Custom Text',
                  labelStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(
                  text: (_selectedElement as TextElement).customText,
                ),
                onChanged: (value) {
                  setState(() {
                    (_selectedElement as TextElement).customText = value;
                    widget.hudManager.saveConfiguration();
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ${value.toInt()}',
            style: const TextStyle(color: Colors.white),
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _showAddElementDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text('Add HUD Element', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.hudManager.getAvailableElementTypes().map((elementType) {
              return ListTile(
                title: Text(
                  elementType.name,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  setState(() {
                    widget.hudManager.addElement(elementType);
                  });
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
