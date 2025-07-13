import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simple_frame_app/simple_frame_app.dart';
import 'package:simple_frame_app/tx/plain_text.dart';
import 'package:simple_frame_app/tx/code.dart';
import 'package:simple_frame_app/text_utils.dart';

// Screen state management for Frame display
enum FrameScreenState {
  idle,           // Ready state - interruptible
  hud,            // Time/date display - interruptible
  recording,      // AI listening/recording - non-interruptible (tap stops recording)
  processing,     // Processing audio - non-interruptible
  aiResponse,     // AI response display - interruptible
}

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
  String _statusMessage = 'Connect Frame - Tap=time, Double-tap=record';
  bool _isListening = false;
  final TextEditingController _apiKeyController = TextEditingController();
  
  // Double-tap detection variables - increased timeout for less sensitivity
  Timer? _tapTimer;
  int _tapCount = 0;
  static const Duration _tapTimeout = Duration(milliseconds: 800);
  
  // Tap debouncing to prevent accidental triggers
  DateTime? _lastTapTime;
  static const Duration _tapDebounce = Duration(milliseconds: 200);

  // Frame microphone variables
  List<int> _microphoneBuffer = [];
  bool _frameMicrophoneActive = false;
  Timer? _microphoneTimeout;

  // Screen state management
  FrameScreenState _screenState = FrameScreenState.idle;
  
  // Flag to prevent duplicate audio processing
  bool _audioBeingProcessed = false;
  
  // Response chunking for display (like CitizenOneX teleprompter)
  final List<String> _responseChunks = [];
  int _currentChunk = 0;

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

  void _handleTap(int taps) async {
    // We'll ignore the taps parameter from Frame and implement our own double-tap detection
    _onSingleTapDetected();
  }

  void _onSingleTapDetected() {
    debugPrint('Tap detected. Current screen state: $_screenState');
    
    // Debounce taps to prevent accidental triggers
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!) < _tapDebounce) {
      debugPrint('Tap ignored - too soon after last tap (${now.difference(_lastTapTime!).inMilliseconds}ms)');
      return;
    }
    _lastTapTime = now;

    // Handle non-interruptible states with special behavior
    if (_screenState == FrameScreenState.recording) {
      // During recording, single tap stops recording (no double-tap detection)
      debugPrint('Single tap during recording - stopping microphone immediately');
      _executeSingleTapAction();
      return;
    }
    
    if (_screenState == FrameScreenState.processing) {
      // During processing, ignore all taps
      debugPrint('Tap ignored - currently processing (non-interruptible)');
      return;
    }

    // For interruptible states (idle, hud, aiResponse), use normal tap detection
    if (_screenState == FrameScreenState.aiResponse) {
      // If showing AI response, tap advances to next chunk or closes if last
      if (_responseChunks.length > 1 && _currentChunk < _responseChunks.length - 1) {
        _currentChunk++;
        _displayCurrentChunk();
        debugPrint('Advanced to chunk ${_currentChunk + 1}/${_responseChunks.length}');
        return; // Don't count this tap for double-tap detection
      } else {
        debugPrint('AI response completed or closed by tap');
        // Close AI response and return to idle
        _screenState = FrameScreenState.idle;
        _audioBeingProcessed = false;
        frame!.sendMessage(TxPlainText(msgCode: 0x12, text: ' '));
        setState(() {
          _statusMessage = 'Ready - Tap for time, double-tap to record';
        });
        return; // Don't count this tap for double-tap detection
      }
    }
    
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
    // If microphone is active (recording), stop it
    if (_frameMicrophoneActive) {
      debugPrint('Single tap during recording - stopping microphone');
      await _stopFrameMicrophone();
      return;
    }
    
    // Otherwise, show date/time HUD (interruptible)
    debugPrint('Executing single tap action - Show date/time HUD');
    
    _screenState = FrameScreenState.hud;
    setState(() {
      _statusMessage = 'Showing date/time on Frame';
    });
    
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    
    await frame!.sendMessage(TxPlainText(msgCode: 0x0a, text: '$dateStr\n$timeStr'));
    
    // Clear the display after 3 seconds (return to idle state)
    Timer(const Duration(seconds: 3), () async {
      if (_screenState == FrameScreenState.hud) { // Only clear if still showing HUD
        await frame!.sendMessage(TxPlainText(msgCode: 0x12, text: ' '));
        _screenState = FrameScreenState.idle;
        if (mounted) {
          setState(() {
            _statusMessage = 'Ready - Tap for time, double-tap to record';
          });
        }
      }
    });
  }

  Future<void> _startFrameMicrophone() async {
    _screenState = FrameScreenState.recording;
    setState(() {
      _frameMicrophoneActive = true;
      _statusMessage = 'Recording... Single tap to stop';
      _microphoneBuffer.clear();
    });

    debugPrint('Starting Frame microphone recording with tap control');

    // Send microphone start command to Frame (0x11)
    await frame!.sendMessage(TxCode(msgCode: 0x11, value: 1));
    debugPrint('Sent microphone start command to Frame');
    
    // Show listening state on Frame
    await frame!.sendMessage(TxPlainText(msgCode: 0x0a, text: 'Recording...\nTap once to stop'));

    // Set a backup timeout (60 seconds) in case user forgets to stop
    _microphoneTimeout = Timer(const Duration(seconds: 60), () {
      debugPrint('Backup microphone timeout reached (60s)');
      _stopFrameMicrophone();
    });
    
    debugPrint('Recording started - tap once to stop, backup timeout: 60s');
  }

  Future<void> _stopFrameMicrophone() async {
    _microphoneTimeout?.cancel();
    
    debugPrint('Stopping Frame microphone. Buffer size: ${_microphoneBuffer.length} bytes');
    
    // Check if microphone is still active to avoid duplicate processing
    if (!_frameMicrophoneActive) {
      debugPrint('Microphone already stopped, skipping duplicate processing');
      return;
    }
    
    // Send microphone stop command to Frame (0x13)
    await frame!.sendMessage(TxCode(msgCode: 0x13, value: 1));
    
    // Set processing state (non-interruptible)
    _screenState = FrameScreenState.processing;
    setState(() {
      _frameMicrophoneActive = false;
      _statusMessage = 'Processing audio... (${_microphoneBuffer.length} bytes)';
    });

    // Show "Processing" on Frame immediately
    await frame!.sendMessage(TxPlainText(msgCode: 0x0a, text: 'Processing...\nPlease wait'));

    // Add a small delay to ensure all data is received
    await Future.delayed(const Duration(milliseconds: 500));

    // Process the collected audio data only if we still have it and haven't processed it yet
    if (_microphoneBuffer.isNotEmpty && _screenState == FrameScreenState.processing && !_audioBeingProcessed) {
      _audioBeingProcessed = true; // Prevent duplicate processing
      debugPrint('Processing ${_microphoneBuffer.length} bytes of audio data via manual stop');
      await _processFrameAudioData(_microphoneBuffer);
      _microphoneBuffer.clear(); // Clear after processing
      _audioBeingProcessed = false; // Reset flag
    } else if (_microphoneBuffer.isEmpty) {
      debugPrint('No audio data in buffer');
      setState(() {
        _statusMessage = 'No audio detected. Try again.';
      });
      await frame!.sendMessage(TxPlainText(msgCode: 0x0a, text: 'No audio detected\nDouble-tap to retry'));
      
      // Clear display after delay and return to idle
      Timer(const Duration(seconds: 3), () async {
        await frame!.sendMessage(TxPlainText(msgCode: 0x12, text: ' '));
        _screenState = FrameScreenState.idle;
        if (mounted) {
          setState(() {
            _statusMessage = 'Ready - Tap for time, double-tap to record';
          });
        }
      });
    }
  }

  Future<void> _processFrameAudioData(List<int> audioData) async {
    setState(() {
      _statusMessage = 'Processing audio with Gemini...';
    });

    try {
      // Send audio directly to Gemini without speech-to-text conversion
      final response = await _sendAudioToGemini(audioData);
      
      if (response.trim().isEmpty) {
        setState(() {
          _statusMessage = 'No response from Gemini. Try again.';
        });
        await frame!.sendMessage(TxPlainText(msgCode: 0x0a, text: 'No response\nDouble-tap to retry'));
        return;
      }

      // Send the response directly to Frame
      await _sendResponseToFrame(response);
      
    } catch (e) {
      debugPrint('Error processing audio with Gemini: $e');
      setState(() {
        _statusMessage = 'Error processing audio. Try again.';
      });
      await frame!.sendMessage(TxPlainText(msgCode: 0x0a, text: 'Processing error\nDouble-tap to retry'));
    }
  }

  Future<String> _sendAudioToGemini(List<int> audioData) async {
    try {
      debugPrint('Sending ${audioData.length} bytes of audio directly to Gemini');
      
      if (audioData.isEmpty) {
        debugPrint('No audio data to send to Gemini');
        return '';
      }

      // Convert audio data to base64 for Gemini API
      final audioBytes = Uint8List.fromList(audioData);
      
      debugPrint('Prepared ${audioBytes.length} bytes for Gemini');

      // Load the system prompt
      final systemPrompt = await _loadSystemPrompt();
      
      // Prepare the request for Gemini API with audio input
      final request = {
        'contents': [
          {
            'parts': [
              {
                'text': systemPrompt + '\n\nThe user has provided an audio message. Please listen to the audio and respond to their question or request.'
              },
              {
                'inline_data': {
                  'mime_type': 'audio/wav',
                  'data': _convertRawAudioToWav(audioBytes)
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 200,
        }
      };

      debugPrint('Sending request to Gemini API with audio...');
      
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request),
      );

      debugPrint('Gemini API response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        debugPrint('Gemini API response: ${result.toString()}');
        
        if (result['candidates'] != null && result['candidates'].isNotEmpty) {
          final content = result['candidates'][0]['content']['parts'][0]['text'];
          debugPrint('Gemini response: "$content"');
          return content.toString().trim();
        } else {
          debugPrint('No response from Gemini');
          return 'Sorry, I could not process your audio request.';
        }
      } else {
        debugPrint('Gemini API error: ${response.statusCode} - ${response.body}');
        if (response.statusCode == 429) {
          return 'Rate limit exceeded. Please try again in a moment.';
        } else if (response.statusCode == 403) {
          return 'API key invalid or quota exceeded. Check your settings.';
        } else {
          return 'API error: ${response.statusCode}. Please try again.';
        }
      }
    } catch (e) {
      debugPrint('Error sending audio to Gemini: $e');
      return 'Sorry, there was an error processing your request.';
    }
  }

  void _executeDoubleTapAction() async {
    // Only allow double-tap in idle state or interruptible states
    if (_screenState == FrameScreenState.recording) {
      debugPrint('Double tap ignored - already recording (use single tap to stop)');
      return;
    }
    
    if (_screenState == FrameScreenState.processing) {
      debugPrint('Double tap ignored - currently processing (non-interruptible)');
      return;
    }
    
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
    
    // Start Frame microphone (will set recording state)
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
          // Look for non-final microphone data messages (0x05)
          else if (msgCode == 0x05 && _frameMicrophoneActive) {
            // Non-final microphone data received from Frame
            final audioData = data.sublist(1); // Skip the message code byte
            _microphoneBuffer.addAll(audioData);
            debugPrint('Received ${audioData.length} bytes of non-final microphone data from Frame (total: ${_microphoneBuffer.length})');
            
            // Analyze the first few bytes to see if we're getting actual audio data
            if (audioData.length >= 4) {
              final sample1 = audioData[0] | (audioData[1] << 8);
              final sample2 = audioData[2] | (audioData[3] << 8);
              debugPrint('Audio samples: $sample1, $sample2 (hex: ${sample1.toRadixString(16)}, ${sample2.toRadixString(16)})');
            }
          }
          // Look for final microphone data messages (0x06) 
          else if (msgCode == 0x06 && _frameMicrophoneActive) {
            // Final microphone data or end-of-stream signal
            debugPrint('Received end-of-stream signal from Frame microphone (total buffer: ${_microphoneBuffer.length} bytes)');
            
            // Set microphone as inactive to prevent further processing
            _frameMicrophoneActive = false;
            _microphoneTimeout?.cancel();
            
            // Only process if we're in recording state and not already being processed
            if (_screenState == FrameScreenState.recording && _microphoneBuffer.isNotEmpty && !_audioBeingProcessed) {
              _audioBeingProcessed = true; // Prevent duplicate processing
              // Set processing state (non-interruptible)
              _screenState = FrameScreenState.processing;
              setState(() {
                _statusMessage = 'Processing audio... (${_microphoneBuffer.length} bytes)';
              });

              // Process the complete audio buffer
              debugPrint('Processing ${_microphoneBuffer.length} bytes of audio data from end-of-stream');
              Future.delayed(Duration.zero, () async {
                // Show "Processing" on Frame
                await frame!.sendMessage(TxPlainText(msgCode: 0x0a, text: 'Processing...\nPlease wait'));
                await _processFrameAudioData(_microphoneBuffer);
                _microphoneBuffer.clear();
                _audioBeingProcessed = false; // Reset flag
              });
            } else {
              debugPrint('Audio already processed or no data - skipping end-of-stream processing (state: $_screenState, being processed: $_audioBeingProcessed)');
            }
          }
          // Look for old format microphone data messages (0x0b) for backward compatibility
          else if (msgCode == 0x0b && _frameMicrophoneActive) {
            // Legacy microphone data received from Frame
            final audioData = data.sublist(1); // Skip the message code byte
            _microphoneBuffer.addAll(audioData);
            debugPrint('Received ${audioData.length} bytes of legacy microphone data from Frame (total: ${_microphoneBuffer.length})');
          }
          else if ((msgCode == 0x05 || msgCode == 0x06 || msgCode == 0x0b) && !_frameMicrophoneActive) {
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
      _screenState = FrameScreenState.idle;
      setState(() {
        _statusMessage = 'Ready - Tap for time, double-tap to record';
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

    _screenState = FrameScreenState.idle;
    currentState = ApplicationState.ready;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _tapTimer?.cancel();
    _microphoneTimeout?.cancel();
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

  String _convertRawAudioToWav(Uint8List rawAudio, {int sampleRate = 8000, int channels = 1, int bitDepth = 16}) {
    // Calculate the total size of the WAV file
    int dataSize = rawAudio.length;
    int headerSize = 44; // Standard WAV header is 44 bytes
    int fileSize = headerSize + dataSize;

    // Create a buffer to hold the header and audio data
    final wavData = BytesBuilder();

    // RIFF header
    wavData.add(Uint8List.fromList('RIFF'.codeUnits)); // ChunkID
    wavData.add(_intToBytes(fileSize - 8, 4));         // ChunkSize
    wavData.add(Uint8List.fromList('WAVE'.codeUnits)); // Format

    // fmt sub-chunk
    wavData.add(Uint8List.fromList('fmt '.codeUnits)); // Subchunk1ID
    wavData.add(_intToBytes(16, 4));                   // Subchunk1Size (PCM)
    wavData.add(_intToBytes(1, 2));                    // AudioFormat (1 for PCM)
    wavData.add(_intToBytes(channels, 2));             // NumChannels
    wavData.add(_intToBytes(sampleRate, 4));           // SampleRate
    wavData.add(_intToBytes(sampleRate * channels * (bitDepth ~/ 8), 4)); // ByteRate
    wavData.add(_intToBytes(channels * (bitDepth ~/ 8), 2));              // BlockAlign
    wavData.add(_intToBytes(bitDepth, 2));             // BitsPerSample

    // data sub-chunk
    wavData.add(Uint8List.fromList('data'.codeUnits)); // Subchunk2ID
    wavData.add(_intToBytes(dataSize, 4));             // Subchunk2Size
    wavData.add(rawAudio);                             // Audio data

    // Return the WAV data as base64
    return base64Encode(wavData.toBytes());
  }

  // Helper function to convert an integer to a byte list of given length
  Uint8List _intToBytes(int value, int length) {
    final result = Uint8List(length);
    for (int i = 0; i < length; i++) {
      result[i] = (value >> (8 * i)) & 0xFF;
    }
    return result;
  }

  Future<void> _sendResponseToFrame(String response) async {
    // Set AI response state (interruptible)
    _screenState = FrameScreenState.aiResponse;
    setState(() {
      _statusMessage = 'Juniper: ${response.length > 50 ? "${response.substring(0, 50)}..." : response}';
      _isListening = false;
    });

    // Use chunk-based display like CitizenOneX teleprompter
    _displayResponse(response);
  }

  // Display response in chunks, maximizing screen space
  void _displayResponse(String response) {
    // Clear previous chunks
    _responseChunks.clear();
    _currentChunk = 0;
    
    // Split the response into words for optimal packing
    List<String> words = response.split(' ');
    String currentChunk = '';
    
    for (String word in words) {
      String testChunk = currentChunk.isEmpty ? word : '$currentChunk $word';
      
      // Test if this would still fit in 4 lines at 640px width
      String wrapped = TextUtils.wrapText(testChunk, 640, 4);
      List<String> lines = wrapped.split('\n');
      
      // If it fits in 4 lines and wrapping didn't truncate content, add the word
      if (lines.length <= 4 && wrapped.replaceAll('\n', ' ').trim() == testChunk.trim()) {
        currentChunk = testChunk;
      } else {
        // Would overflow, save current chunk and start new one
        if (currentChunk.isNotEmpty) {
          _responseChunks.add(TextUtils.wrapText(currentChunk, 640, 4));
        }
        currentChunk = word;
      }
    }
    
    // Add the last chunk
    if (currentChunk.isNotEmpty) {
      _responseChunks.add(TextUtils.wrapText(currentChunk, 640, 4));
    }
    
    // If no chunks were created (shouldn't happen with word splitting), create fallback
    if (_responseChunks.isEmpty) {
      _responseChunks.add(TextUtils.wrapText(response, 640, 4));
    }
    
    debugPrint('Split response into ${_responseChunks.length} chunks for maximum screen usage');
    
    // Display first chunk
    if (_responseChunks.isNotEmpty) {
      _displayCurrentChunk();
    } else {
      // Fallback for empty response
      frame!.sendMessage(TxPlainText(msgCode: 0x0a, text: 'No response received'));
    }
  }
  
  void _displayCurrentChunk() {
    if (_currentChunk < _responseChunks.length) {
      String chunkText = _responseChunks[_currentChunk];
      
      // Just display the content without navigation info
      frame!.sendMessage(TxPlainText(msgCode: 0x0a, text: chunkText));
      debugPrint('Displaying chunk ${_currentChunk + 1}/${_responseChunks.length}');
      
      // Auto-advance to next chunk after longer delay, or return to idle if last chunk
      Timer(const Duration(seconds: 12), () async {
        if (_screenState == FrameScreenState.aiResponse) {
          if (_currentChunk < _responseChunks.length - 1) {
            // More chunks available, advance to next
            _currentChunk++;
            _displayCurrentChunk();
          } else {
            // Last chunk, return to idle
            await frame!.sendMessage(TxPlainText(msgCode: 0x12, text: ' '));
            _screenState = FrameScreenState.idle;
            _audioBeingProcessed = false; // Reset processing flag
            if (mounted) {
              setState(() {
                _statusMessage = 'Ready - Tap for time, double-tap to record';
              });
            }
          }
        }
      });
    }
  }
}
