import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MainApp());

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => MainAppState();
}

class MainAppState extends State<MainApp> {
  String _apiKey = '';
  String _statusMessage = 'Simplified version - Enter API key and test Gemini integration';
  bool _isListening = false;
  String _lastResponse = '';

  @override
  void initState() {
    super.initState();
    // API key will be stored in memory for this session
  }

  Future<void> _saveApiKey(String key) async {
    // For now, API key is stored in memory only
    // In a real app, you'd want persistent storage
    setState(() {
      _apiKey = key;
      _statusMessage = 'API key saved. Ready to test Gemini integration.';
    });
  }

  Future<void> _testGeminiAPI() async {
    if (_apiKey.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter your Gemini API key first';
      });
      return;
    }

    setState(() {
      _isListening = true;
      _statusMessage = 'Testing Gemini API...';
    });

    try {
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{
            'parts': [{'text': 'Hello, I am Juniper, your AI assistant for Frame glasses. Respond with a brief greeting and confirmation that the API is working.'}]
          }]
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final text = jsonResponse['candidates'][0]['content']['parts'][0]['text'];
        setState(() {
          _lastResponse = text;
          _statusMessage = 'Gemini API test successful!';
        });
      } else {
        debugPrint('Gemini API error: ${response.statusCode} - ${response.body}');
        setState(() {
          _statusMessage = 'API Error: ${response.statusCode}';
        });
      }
    } catch (e) {
      debugPrint('Error calling Gemini API: $e');
      setState(() {
        _statusMessage = 'Network error: $e';
      });
    } finally {
      setState(() {
        _isListening = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('Juniper for Frame (Demo)'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // API Key Input Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gemini API Configuration',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        onChanged: (value) => _apiKey = value,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Enter Gemini API Key',
                          border: OutlineInputBorder(),
                          hintText: 'Your Google AI API key',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _saveApiKey(_apiKey),
                              child: const Text('Save API Key'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _testGeminiAPI,
                              child: const Text('Test API'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          color: _isListening ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Demo Note Card
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Demo Version',
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This is a simplified version without Bluetooth connectivity due to build environment issues. The full version includes:',
                        style: TextStyle(color: Colors.blue.shade800),
                      ),
                      const SizedBox(height: 8),
                      ...const [
                        '• Frame glasses connectivity via Bluetooth',
                        '• Single tap: Show date/time on Frame display',
                        '• Double tap: Activate Juniper AI assistant',
                        '• Battery-preserving idle mode',
                        '• Voice interaction with AI responses on Frame',
                      ].map((text) => Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 4),
                        child: Text(
                          text,
                          style: TextStyle(color: Colors.blue.shade800),
                        ),
                      )),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Response Display
              if (_lastResponse.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Last Gemini Response',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _lastResponse,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Instructions Card  
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'How Juniper for Frame Works',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '1. Enter your Gemini API key above\n'
                        '2. Connect your Frame glasses via Bluetooth\n'
                        '3. Upload the Juniper app to Frame\n'
                        '4. Frame enters idle mode (battery saving)\n'
                        '5. Single tap side button = Date/time display\n'
                        '6. Double tap side button = Activate AI assistant\n'
                        '7. Speak to Juniper, responses appear on Frame',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
