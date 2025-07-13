import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

  @override
  void initState() {
    super.initState();
    // API key will be stored in memory for this session
  }

  Future<void> _loadApiKey() async {
    // For now, API key is stored in memory only
    // In a real app, you'd want persistent storage
  }

  Future<void> _saveApiKey(String key) async {
    // For now, API key is stored in memory only
    // In a real app, you'd want persistent storage
    setState(() {
      _apiKey = key;
    });
  }

  void _showApiKeyDialog() {
    final controller = TextEditingController(text: _apiKey);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gemini API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your Google Gemini API key:'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Your Gemini API Key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
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
            },
            child: const Text('Save'),
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
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'maxOutputTokens': 100,
            'temperature': 0.7,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          return data['candidates'][0]['content']['parts'][0]['text'] ?? 'No response from Juniper.';
        }
      } else {
        debugPrint('Gemini API error: ${response.statusCode} - ${response.body}');
        return 'Sorry, I encountered an error. Please try again.';
      }
    } catch (e) {
      debugPrint('Error calling Gemini API: $e');
      return 'Sorry, I\'m having trouble connecting right now.';
    }

    return 'No response from Juniper.';
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
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Juniper for Frame',
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Juniper for Frame'),
          actions: [
            IconButton(
              icon: const Icon(Icons.key),
              onPressed: _showApiKeyDialog,
              tooltip: 'Set API Key',
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
                        'API Key: ${_apiKey.isEmpty ? 'Not set' : 'Configured'}',
                        style: TextStyle(
                          color: _apiKey.isEmpty ? Colors.red : Colors.green,
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
