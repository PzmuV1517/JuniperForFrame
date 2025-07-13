import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simple_frame_app/simple_frame_app.dart';
import 'package:simple_frame_app/tx/plain_text.dart';
import 'package:simple_frame_app/tx/code.dart';

void main() => runApp(const MainApp());

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => MainAppState();
}

/// SimpleFrameAppState mixin helps to manage the lifecycle of the Frame connection outside of this file
class MainAppState extends State<MainApp> with SimpleFrameAppState {
  StreamSubscription<List<int>>? _tapSubs;
  String _apiKey = '';
  String _statusMessage = 'Connect Frame and set API key to start';
  bool _isListening = false;
  final TextEditingController _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString('gemini_api_key') ?? '';
      setState(() {
        _apiKey = savedKey;
        if (_apiKey.isNotEmpty) {
          _statusMessage = 'API key loaded. Connect Frame to start.';
        }
      });
    } catch (e) {
      debugPrint('Error loading API key: $e');
    }
  }

  Future<void> _saveApiKey(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gemini_api_key', key);
      setState(() {
        _apiKey = key;
      });
    } catch (e) {
      debugPrint('Error saving API key: $e');
      // Fallback to in-memory storage
      setState(() {
        _apiKey = key;
      });
    }
  }

  void _showApiKeyDialog() {
    final controller = TextEditingController(text: _apiKey);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.key, color: Colors.blue),
            SizedBox(width: 8),
            Text('Gemini API Key'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your Google Gemini API key:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'AIzaSyC...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key),
                ),
                obscureText: true,
                maxLines: 1,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Free Tier Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 15 requests per minute\n'
                      '• 1,500 requests per day\n'
                      '• 1 million tokens per day\n'
                      '• Perfect for Frame usage!',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  // This would open the API key creation page
                },
                child: Text(
                  'Get your free API key at ai.google.dev',
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    decoration: TextDecoration.underline,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _saveApiKey(controller.text);
              Navigator.pop(context);
              if (controller.text.isNotEmpty) {
                setState(() {
                  _statusMessage = 'API key configured! Connect Frame to start.';
                });
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeApiKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove API Key'),
        content: const Text('Are you sure you want to remove your API key? You will need to enter it again to use Juniper.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('gemini_api_key');
        setState(() {
          _apiKey = '';
          _statusMessage = 'API key removed. Enter your key below to continue.';
        });
      } catch (e) {
        debugPrint('Error removing API key: $e');
        setState(() {
          _apiKey = '';
          _statusMessage = 'API key removed from memory.';
        });
      }
    }
  }

  void _showApiInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Free Tier Information'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Gemini API Free Tier includes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('✓ 15 requests per minute'),
              const Text('✓ 1,500 requests per day'),
              const Text('✓ 1 million tokens per day'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Perfect for Frame!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The free tier is more than enough for typical Frame usage. Juniper is optimized to use minimal tokens per response.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  // This would open the API key creation page
                },
                child: Text(
                  'Get your free API key at ai.google.dev',
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    decoration: TextDecoration.underline,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<String> _callGeminiAPI(String prompt) async {
    if (_apiKey.isEmpty) {
      return 'API key not set. Please configure your Gemini API key.';
    }

    try {
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'You are Juniper, an AI assistant for Frame smart glasses. Keep responses concise (under 100 words) and helpful. Format for display on small screen. User: $prompt'}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 150, // Keep responses short for free tier
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['candidates'] != null && jsonResponse['candidates'].isNotEmpty) {
          return jsonResponse['candidates'][0]['content']['parts'][0]['text'];
        } else {
          return 'No response generated. Try rephrasing your question.';
        }
      } else if (response.statusCode == 429) {
        return 'Rate limit exceeded. Free tier: 15 requests/min. Please wait a moment.';
      } else if (response.statusCode == 403) {
        return 'API key invalid or quota exceeded. Check your API key settings.';
      } else {
        debugPrint('Gemini API error: ${response.statusCode} - ${response.body}');
        return 'API error: ${response.statusCode}. Please try again.';
      }
    } catch (e) {
      debugPrint('Error calling Gemini API: $e');
      return 'Network error. Check your internet connection.';
    }
  }

  void _handleTap(int taps) async {
    debugPrint('Detected $taps tap(s)');
    
    if (taps == 1) {
      // Single tap: Show HUD with date/time
      setState(() {
        _statusMessage = 'Showing date/time on Frame';
      });
      
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      
      await frame!.sendMessage(TxPlainText(msgCode: 0x0a, text: '$dateStr\n$timeStr'));
      
    } else if (taps == 2) {
      // Double tap: AI interaction
      setState(() {
        _statusMessage = 'Juniper is listening...';
        _isListening = true;
      });
      
      // Greet the user and show listening state
      await frame!.sendMessage(TxPlainText(msgCode: 0x0a, text: 'Hello! I\'m Juniper.\nHow can I help?'));
      
      // For now, we'll simulate a voice interaction with a predefined prompt
      // In a real implementation, you would integrate with speech recognition
      await Future.delayed(const Duration(seconds: 2));
      
      setState(() {
        _statusMessage = 'Processing your request...';
      });
      
      // Simulate getting a user query (in real app, this would come from speech recognition)
      const userQuery = "What's the weather like today?";
      
      final response = await _callGeminiAPI(userQuery);
      
      // Send response to Frame
      await frame!.sendMessage(TxPlainText(msgCode: 0x0a, text: response));
      
      setState(() {
        _statusMessage = 'Response sent to Frame';
        _isListening = false;
      });
    }
  }

  @override
  Future<void> run() async {
    if (_apiKey.isEmpty) {
      setState(() {
        _statusMessage = 'Please set your Gemini API key first';
      });
      return;
    }

    currentState = ApplicationState.running;
    if (mounted) setState(() {});

    try {
      _tapSubs?.cancel();
      _tapSubs = frame!.dataResponse.listen((data) {
        // Look for tap messages (0x09)
        if (data.isNotEmpty && data[0] == 0x09) {
          // Tap detected - send the number of taps (usually 1 or 2)
          int taps = data.length > 1 ? data[1] : 1;
          _handleTap(taps);
        }
      });

      // let Frame know to subscribe for taps and send them to us
      await frame!.sendMessage(TxCode(msgCode: 0x10, value: 1));

      await Future.delayed(const Duration(seconds: 1));

      // Initial setup complete
      setState(() {
        _statusMessage = 'Juniper ready! Tap Frame to interact.';
      });

    } catch (e) {
      debugPrint('Error executing application logic: $e');
      currentState = ApplicationState.ready;
      if (mounted) setState(() {});
    }
  }

  @override
  Future<void> cancel() async {
    // let Frame know to cancel subscription for taps
    await frame!.sendMessage(TxCode(msgCode: 0x10, value: 0));

    // clear
    await frame!.sendMessage(TxPlainText(msgCode: 0x12, text: ' '));

    currentState = ApplicationState.ready;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Juniper for Frame',
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Juniper for Frame'),
          actions: [
            if (_apiKey.isNotEmpty)
              PopupMenuButton<String>(
                icon: const Icon(Icons.key),
                tooltip: 'API Key Options',
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _showApiKeyDialog();
                      break;
                    case 'remove':
                      _removeApiKey();
                      break;
                    case 'info':
                      _showApiInfoDialog();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Edit API Key'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'info',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline),
                        SizedBox(width: 8),
                        Text('Free Tier Info'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Remove Key', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            getBatteryWidget(),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.assistant, size: 64, color: Colors.blue),
                      const SizedBox(height: 16),
                      const Text(
                        'Juniper AI Assistant',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusMessage,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      if (_isListening)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Simple API Key Setup (only show if no key is set)
              if (_apiKey.isEmpty) ...[
                Card(
                  elevation: 4,
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Setup Required',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Enter your free Gemini API key to start using Juniper:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _apiKeyController,
                          decoration: InputDecoration(
                            hintText: 'AIzaSyC... (paste your API key here)',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.vpn_key),
                            filled: true,
                            fillColor: Colors.white,
                            suffixIcon: _apiKeyController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _apiKeyController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                          obscureText: false, // Show the key while typing for easier verification
                          onChanged: (value) {
                            setState(() {}); // Update UI when text changes
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _apiKeyController.text.trim().isNotEmpty
                                    ? () {
                                        _saveApiKey(_apiKeyController.text.trim());
                                        _apiKeyController.clear();
                                      }
                                    : null,
                                icon: const Icon(Icons.save),
                                label: const Text('Set API Key'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: _showApiInfoDialog,
                              icon: const Icon(Icons.help_outline),
                              label: const Text('Free Tier'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            // This would open the API key creation page
                          },
                          child: Text(
                            '👆 Get your free API key at ai.google.dev',
                            style: TextStyle(
                              color: Colors.blue.shade600,
                              decoration: TextDecoration.underline,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              // Success message when API key is configured
              if (_apiKey.isNotEmpty) ...[
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'API Key Configured ✓',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              Text(
                                'Use the key icon in the top right to modify',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'How to use:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('• Single tap: Show date/time HUD'),
                      const Text('• Double tap: Talk to Juniper AI'),
                      const SizedBox(height: 12),
                      Text(
                        'Status: ${currentState.name}',
                        style: TextStyle(
                          color: currentState == ApplicationState.running ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: getFloatingActionButtonWidget(
          const Icon(Icons.play_arrow), 
          const Icon(Icons.stop)
        ),
        persistentFooterButtons: getFooterButtonsWidget(),
      ),
    );
  }
}
