import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'dart:typed_data';
import 'api_settings_screen.dart';
import 'location_settings_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  
  // Speech & TTS
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  bool _isListening = false;
  String _command = '';
  
  // AI
  String? _apiKey;
  bool _isProcessing = false;
  
  // Audio
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _requestPermissions();
    await _initializeCamera();
    await _initializeSpeech();
    await _initializeTTS();
    await _loadGeminiModel();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
      Permission.location,
    ].request();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() => _isCameraInitialized = true);
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _initializeSpeech() async {
    _speech = stt.SpeechToText();
    bool available = await _speech.initialize(
      onError: (error) => debugPrint('STT Init Error: ${error.errorMsg}'),
      onStatus: (status) => debugPrint('STT Init Status: $status'),
    );
    
    if (!available) {
      debugPrint('Speech recognition tidak tersedia di device ini');
    } else {
      debugPrint('Speech recognition siap!');
    }
  }

  Future<void> _initializeTTS() async {
    _tts = FlutterTts();
    await _tts.setLanguage('id-ID');
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _loadGeminiModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _apiKey = prefs.getString('gemini_api_key') ?? '';
      
      if (_apiKey != null && _apiKey!.isNotEmpty) {
        debugPrint('Gemini API key loaded');
      }
    } catch (e) {
      debugPrint('Error loading Gemini API key: $e');
    }
  }

  Future<void> _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onError: (error) {
          debugPrint('STT Error: ${error.errorMsg}');
          setState(() => _isListening = false);
        },
        onStatus: (status) {
          debugPrint('STT Status: $status');
          if (status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
      );
      
      if (available) {
        setState(() {
          _isListening = true;
          _command = ''; // Reset command
        });
        
        await _speech.listen(
          onResult: (result) {
            debugPrint('STT Result: ${result.recognizedWords}');
            if (result.recognizedWords.isNotEmpty) {
              setState(() {
                _command = result.recognizedWords;
              });
            }
          },
          localeId: 'id_ID',
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          onSoundLevelChange: (level) {
            // Optional: show sound level indicator
          },
        );
      } else {
        _showSnackBar('Speech recognition tidak tersedia');
      }
    }
  }

  Future<void> _stopListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      
      // Show command if captured
      if (_command.isNotEmpty) {
        _showSnackBar('Command tersimpan: $_command');
      } else {
        _showSnackBar('Tidak ada suara terdeteksi');
      }
    }
  }

  Future<void> _captureAndSend() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showSnackBar('Kamera belum siap');
      return;
    }

    if (_apiKey == null || _apiKey!.isEmpty) {
      _showSnackBar('API Key Gemini belum diatur');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ApiSettingsScreen()),
      );
      return;
    }

    if (_command.isEmpty) {
      _showSnackBar('Rekam command terlebih dahulu');
      return;
    }

    try {
      setState(() => _isProcessing = true);
      
      // Capture image
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // Send to Gemini REST API - using Flash Lite (most generous free tier)
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=$_apiKey'
      );
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': _command},
                {
                  'inline_data': {
                    'mime_type': 'image/jpeg',
                    'data': base64Image
                  }
                }
              ]
            }
          ]
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseText = data['candidates'][0]['content']['parts'][0]['text'] ?? 'Tidak ada response';
        
        // Stop loading sound
        await _audioPlayer.stop();
        
        // Speak response
        await _tts.speak(responseText);
        
        // Show response
        if (mounted) {
          _showResponseDialog(responseText);
        }
      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
      
    } catch (e) {
      debugPrint('Error: $e');
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showResponseDialog(String response) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Response AI'),
        content: SingleChildScrollView(
          child: Text(response),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _speech.stop();
    _tts.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final sectionHeight = size.height / 5;

    return Scaffold(
      body: Stack(
        children: [
          // Camera Preview (Full Screen)
          if (_isCameraInitialized)
            SizedBox(
              width: size.width,
              height: size.height,
              child: CameraPreview(_cameraController!),
            )
          else
            const Center(child: CircularProgressIndicator()),
          
          // Overlay Sections
          Column(
            children: [
              // Top Row (2/5 height)
              SizedBox(
                height: sectionHeight * 2,
                child: Row(
                  children: [
                    // API Settings Button
                    _buildButton(
                      flex: 1,
                      icon: Icons.settings,
                      label: 'API',
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ApiSettingsScreen(),
                          ),
                        );
                        _loadGeminiModel();
                      },
                    ),
                    // Location Settings Button
                    _buildButton(
                      flex: 1,
                      icon: Icons.location_on,
                      label: 'Lokasi',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LocationSettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              
              // Middle Row (1/5 height) - Capture Button
              SizedBox(
                height: sectionHeight,
                child: Center(
                  child: _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : GestureDetector(
                          onTap: _captureAndSend,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.3),
                              border: Border.all(
                                color: Colors.white,
                                width: 4,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                ),
              ),
              
              // Bottom Row (2/5 height)
              SizedBox(
                height: sectionHeight * 2,
                child: Row(
                  children: [
                    // Voice Command Button
                    _buildButton(
                      flex: 1,
                      icon: _isListening ? Icons.mic : Icons.mic_none,
                      label: _isListening ? 'Stop' : 'Command',
                      color: _isListening ? Colors.red : Colors.blue,
                      onTap: () {
                        if (_isListening) {
                          _stopListening();
                        } else {
                          _startListening();
                        }
                      },
                    ),
                    // SOS Button
                    _buildButton(
                      flex: 1,
                      icon: Icons.warning,
                      label: 'SOS',
                      color: Colors.red,
                      onTap: () {
                        _showSnackBar('SOS Feature - Coming Soon');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Command Display & Status
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Column(
              children: [
                // Listening Indicator
                if (_isListening)
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Mendengarkan...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Command Display
                if (_command.isNotEmpty && !_isListening)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Command:',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _command,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required int flex,
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (color ?? Colors.blue).withOpacity(0.3),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: color ?? Colors.white,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 40),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}