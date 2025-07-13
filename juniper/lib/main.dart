import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  
  // Double-tap detection variables
  Timer? _tapTimer;
  int _tapCount = 0;
  static const Duration _tapTimeout = Duration(milliseconds: 500);

  // Frame microphone variables
  List<int> _microphoneBuffer = [];
  bool _frameMicrophoneActive = false;
  Timer? _microphoneTimeout;

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
    final bool isEditing = _apiKey.isNotEmpty;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.key, color: Colors.blue),
            const SizedBox(width: 8),
            Text(isEditing ? 'Edit API Key' : 'Set API Key'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing 
                  ? 'Update your Google Gemini API key:'
                  : 'Enter your Google Gemini API key:',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: isEditing ? 'Enter new API key...' : 'AIzaSyC...',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.vpn_key),
                  helperText: isEditing ? 'Current key will be replaced' : null,
                ),
                obscureText: !isEditing, // Show text when editing for easier verification
                maxLines: 1,
                autofocus: true,
              ),
              if (!isEditing) ...[
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
                  _statusMessage = isEditing 
                    ? 'API key updated successfully!'
                    : 'API key configured! Connect Frame to start.';
                });
              }
            },
            child: Text(isEditing ? 'Update' : 'Save'),
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

  Future<String> _loadSystemPrompt() async {
    try {
      return await rootBundle.loadString('assets/system_prompt.txt');
    } catch (e) {
      debugPrint('Failed to load system prompt: $e');
      return 'You are Juniper, a helpful AI assistant for Frame smart glasses. Keep responses concise and helpful.';
    }
  }

  Future<String> _callGeminiAPIWithUserInput(String userInput) async {
    if (_apiKey.isEmpty) {
      return 'API key not set. Please configure your Gemini API key.';
    }

    try {
      final systemPrompt = await _loadSystemPrompt();
      
      // Combine system prompt with user input as specified in the prompt format
      final fullPrompt = '$systemPrompt$userInput';
      
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': fullPrompt}
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
    // We'll ignore the taps parameter from Frame and implement our own double-tap detection
    _onSingleTapDetected();
  }

  void _onSingleTapDetected() {
    _tapCount++;
    debugPrint('Tap detected. Total count: $_tapCount');

    // Cancel any existing timer
    _tapTimer?.cancel();

    // Start a new timer
    _tapTimer = Timer(_tapTimeout, () {
      // Timer expired - execute action based on tap count
      if (_tapCount == 1) {
        _executeSingleTapAction();
      } else if (_tapCount >= 2) {
        _executeDoubleTapAction();
      }
      
      // Reset tap count
      _tapCount = 0;
    });
  }

  void _executeSingleTapAction() async {
    debugPrint('Executing single tap action - Show date/time HUD');
    
    setState(() {
      _statusMessage = 'Showing date/time on Frame';
    });
    
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    
    await frame!.sendMessage(TxPlainText(msgCode: 0x0a, text: '$dateStr\n$timeStr'));
    
    // Clear the display after 3 seconds
    Timer(const Duration(seconds: 3), () async {
      await frame!.sendMessage(TxPlainText(msgCode: 0x12, text: ' '));
      if (mounted) {
        setState(() {
          _statusMessage = 'Ready - Tap for time, double-tap for AI';
        });
      }
    });
  }

  Future<void> _updateSystemPromptWithUserInput(String userInput) async {
    try {
      // Read current system prompt
      final currentPrompt = await rootBundle.loadString('assets/system_prompt.txt');
      
      // Log the combination for debugging (actual combination happens in API call)
      debugPrint('User input will be added to system prompt: $userInput');
      debugPrint('Combined prompt preview: ${currentPrompt}$userInput');
    } catch (e) {
      debugPrint('Error updating system prompt: $e');
    }
  }

  Future<void> _startFrameMicrophone() async {
    setState(() {
      _frameMicrophoneActive = true;
      _statusMessage = 'Listening via Frame... Speak now';
      _microphoneBuffer.clear();
    });

    debugPrint('Starting Frame microphone recording');

    // Send microphone start command to Frame (0x11)
    await frame!.sendMessage(TxCode(msgCode: 0x11, value: 1));
    debugPrint('Sent microphone start command to Frame');
    
    // Show listening state on Frame
    await frame!.sendMessage(TxPlainText(msgCode: 0x0a, text: 'Listening...\nSpeak your question'));

    // Set timeout for microphone recording (10 seconds)
    _microphoneTimeout = Timer(const Duration(seconds: 10), () {
      debugPrint('Microphone timeout reached');
      _stopFrameMicrophone();
    });
    
    debugPrint('Microphone timeout set for 10 seconds');
  }

  Future<void> _stopFrameMicrophone() async {
    _microphoneTimeout?.cancel();
    
    debugPrint('Stopping Frame microphone. Buffer size: ${_microphoneBuffer.length} bytes');
    
    // Send microphone stop command to Frame (0x13)
    await frame!.sendMessage(TxCode(msgCode: 0x13, value: 1));
    
    setState(() {
      _frameMicrophoneActive = false;
      _statusMessage = 'Processing audio... (${_microphoneBuffer.length} bytes)';
    });

    // Add a small delay to ensure all data is received
    await Future.delayed(const Duration(milliseconds: 500));

    // Process the collected audio data
    if (_microphoneBuffer.isNotEmpty) {
      debugPrint('Processing ${_microphoneBuffer.length} bytes of audio data');
      await _processFrameAudioData(_microphoneBuffer);
    } else {
      debugPrint('No audio data in buffer');
      setState(() {
        _statusMessage = 'No audio detected. Try again.';
      });
      await frame!.sendMessage(TxPlainText(msgCode: 0x0a, text: 'No audio detected\nDouble-tap to retry'));
      
      // Clear display after delay
      Timer(const Duration(seconds: 3), () async {
        await frame!.sendMessage(TxPlainText(msgCode: 0x12, text: ' '));
        if (mounted) {
          setState(() {
            _statusMessage = 'Ready - Tap for time, double-tap for AI';
          });
        }
      });
    }
  }

  Future<void> _processFrameAudioData(List<int> audioData) async {
    setState(() {
      _statusMessage = 'Converting speech to text...';
    });

    try {
      // Convert audio data to speech text
      // For now, we'll use a placeholder - you would need to integrate with 
      // a speech-to-text service that accepts raw audio data
      final spokenText = await _convertAudioToText(audioData);
      
      if (spokenText.trim().isEmpty) {
        setState(() {
          _statusMessage = 'Could not understand speech. Try again.';
        });
        await frame!.sendMessage(TxPlainText(msgCode: 0x0a, text: 'Speech unclear\nDouble-tap to retry'));
        return;
      }

      await _processSpeechResult(spokenText);
    } catch (e) {
      debugPrint('Error processing audio: $e');
      setState(() {
        _statusMessage = 'Error processing audio. Try again.';
      });
      await frame!.sendMessage(TxPlainText(msgCode: 0x0a, text: 'Processing error\nDouble-tap to retry'));
    }
  }

  Future<String> _convertAudioToText(List<int> audioData) async {
    // TODO: Implement actual speech-to-text conversion
    // This could use Google Speech-to-Text API, Azure Cognitive Services, etc.
    // For now, return a placeholder response
    debugPrint('Received ${audioData.length} bytes of audio data from Frame');
    
    // Simulate speech recognition processing
    await Future.delayed(const Duration(seconds: 2));
    
    // Placeholder response - replace with actual speech-to-text service
    return "What's the weather like today?";
  }

  Future<void> _processSpeechResult(String spokenText) async {
    if (spokenText.trim().isEmpty) {
      setState(() {
        _statusMessage = 'No speech detected. Try again.';
        _frameMicrophoneActive = false;
      });
      await frame!.sendMessage(TxPlainText(msgCode: 0x0a, text: 'No speech detected\nDouble-tap to retry'));
      return;
    }

    setState(() {
      _statusMessage = 'Processing: "$spokenText"';
      _frameMicrophoneActive = false;
    });

    // Update system prompt with user input
    await _updateSystemPromptWithUserInput(spokenText);

    // Show processing state on Frame
    await frame!.sendMessage(TxPlainText(msgCode: 0x0a, text: 'Processing...\n"$spokenText"'));

    // Get AI response
    final response = await _callGeminiAPIWithUserInput(spokenText);
    
    // Send response to Frame
    await frame!.sendMessage(TxPlainText(msgCode: 0x0a, text: response));
    
    setState(() {
      _statusMessage = 'Response sent to Frame';
      _isListening = false;
    });

    // Clear the display after 7 seconds to preserve battery
    Timer(const Duration(seconds: 7), () async {
      await frame!.sendMessage(TxPlainText(msgCode: 0x12, text: ' '));
      if (mounted) {
        setState(() {
          _statusMessage = 'Ready - Tap for time, double-tap for AI';
        });
      }
    });
  }

  void _executeDoubleTapAction() async {
    debugPrint('Executing double tap action - Activate AI');
    
    if (_apiKey.isEmpty) {
      setState(() {
        _statusMessage = 'Please set your Gemini API key first';
      });
      await frame!.sendMessage(TxPlainText(msgCode: 0x0a, text: 'API key required\nSet in app first'));
      return;
    }

    setState(() {
      _statusMessage = 'Activating Juniper AI...';
      _isListening = true;
    });
    
    // Start Frame microphone
    await _startFrameMicrophone();
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
        if (data.isNotEmpty) {
          final msgCode = data[0];
          
          // Look for tap messages (0x09)
          if (msgCode == 0x09) {
            // Each tap message is treated as a single tap for our own double-tap detection
            debugPrint('Raw tap detected from Frame');
            _handleTap(1); // Always pass 1, we'll handle double-tap detection ourselves
          }
          // Look for microphone data messages (0x0b)
          else if (msgCode == 0x0b && _frameMicrophoneActive) {
            // Microphone data received from Frame
            final audioData = data.sublist(1); // Skip the message code byte
            _microphoneBuffer.addAll(audioData);
            debugPrint('Received ${audioData.length} bytes of microphone data from Frame (total: ${_microphoneBuffer.length})');
          }
          else if (msgCode == 0x0b && !_frameMicrophoneActive) {
            debugPrint('Received microphone data but microphone not active, ignoring');
          }
          else {
            debugPrint('Received unknown message code: 0x${msgCode.toRadixString(16).padLeft(2, '0')}');
          }
        }
      });

      // let Frame know to subscribe for taps and send them to us
      await frame!.sendMessage(TxCode(msgCode: 0x10, value: 1));

      await Future.delayed(const Duration(seconds: 1));

      // Initial setup complete
      setState(() {
        _statusMessage = 'Ready - Tap for time, double-tap for AI';
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
    _tapTimer?.cancel();
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
                      if (_frameMicrophoneActive)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Column(
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.mic, color: Colors.red, size: 32),
                                  SizedBox(width: 8),
                                  Text(
                                    'Listening...',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _stopFrameMicrophone,
                                icon: const Icon(Icons.stop),
                                label: Text('Stop Recording (${_microphoneBuffer.length} bytes)'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
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
                      const Text('• Double tap (within 0.5s): Start voice conversation'),
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
