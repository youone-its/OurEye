import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'api_settings_screen.dart';
import 'location_settings_screen.dart';
import 'login_screen.dart';
import 'track_location_screen.dart';
import 'initial_splash_screen.dart';

class CameraScreen extends StatefulWidget {
  final bool isTrial;

  const CameraScreen({super.key, this.isTrial = false});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  // Speech & TTS
  stt.SpeechToText? _speech;
  FlutterTts? _tts;
  bool _isListening = false;
  String _command = '';

  // AI
  String? _apiKey;
  bool _isProcessing = false;

  // Audio
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Trial time
  int _trialMinutes = 1;
  int _trialSeconds = 0;
  Timer? _trialTimer;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    if (widget.isTrial) {
      _startTrialTimer();
    }
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

          // PETUNJUK SUARA SAAT KAMERA SIAP
          await _tts?.speak(
            "Aplikasi siap. Layar sebelah kiri adalah tombol Command untuk perintah suara. Layar sebelah kanan adalah tombol SOS untuk bantuan darurat.",
          );
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _initializeSpeech() async {
    _speech = stt.SpeechToText();
    await _speech?.initialize();
  }

  Future<void> _initializeTTS() async {
    _tts = FlutterTts();
    await _tts?.setLanguage('id-ID');
    await _tts?.setSpeechRate(0.9);
    await _tts?.setVolume(1.0);
  }

  Future<void> _loadGeminiModel() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('gemini_api_key') ?? '';
  }

  void _startTrialTimer() {
    _trialTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_trialSeconds > 0) {
        setState(() {
          _trialSeconds--;
        });
      } else if (_trialMinutes > 0) {
        setState(() {
          _trialMinutes--;
          _trialSeconds = 59;
        });
      } else {
        // Trial expired
        timer.cancel();
        _handleTrialExpired();
      }
    });
  }

  void _handleTrialExpired() {
    _trialTimer?.cancel();
    _cameraController?.dispose();
    _speech?.stop();
    _tts?.stop();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _handleLogout() async {
    // Stop services
    _cameraController?.dispose();
    _speech?.stop();
    _tts?.stop();

    // Clear login session
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    await prefs.remove('user_email');

    if (mounted) {
      // Navigate back to Initial Splash Screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const InitialSplashScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _toggleListening() async {
    if (_speech == null || _tts == null) {
      debugPrint('Speech or TTS not initialized');
      return;
    }

    if (_isListening) {
      await _speech!.stop();
      setState(() => _isListening = false);
      if (_command.isNotEmpty) {
        await _tts!.speak("Perintah tersimpan: $_command");
      } else {
        await _tts!.speak("Tidak ada suara yang terdeteksi.");
      }
    } else {
      setState(() {
        _isListening = true;
        _command = '';
      });
      await _tts!.speak("Sedang mendengarkan. Silakan bicara sekarang.");
      _speech!.listen(
        onResult: (result) {
          setState(() {
            _command = result.recognizedWords;
          });
        },
        localeId: 'id_ID',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 6),
        partialResults: true,
      );
    }
  }

  Future<void> _handleSOS() async {
    if (_tts == null) {
      debugPrint('TTS not initialized');
      return;
    }

    try {
      // Play SOS alarm sound
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('sounds/alarm.wav'));

      // TTS announcement for blind user
      await _tts!.speak("S O S diaktifkan! Mengirim sinyal darurat.");

      // Show SOS dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.red.shade50,
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.red.shade800, size: 32),
                const SizedBox(width: 12),
                Text(
                  'SOS ACTIVATED',
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Emergency signal has been sent!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                const Text('• Location shared with emergency contacts'),
                const Text('• Alert notification sent'),
                const Text('• Help is on the way'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Stay calm. Emergency services have been notified.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await _audioPlayer.stop();
                  await _tts!.speak("S O S dibatalkan.");
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  'CANCEL SOS',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _audioPlayer.stop();
                  await _tts!
                      .speak("Bantuan sedang dalam perjalanan. Tetap tenang.");
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade800,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error in SOS: $e');
      await _tts?.speak("Terjadi kesalahan pada fitur S O S.");
    }
  }

  Future<void> _captureAndSend() async {
    if (_tts == null) {
      debugPrint('TTS not initialized');
      return;
    }

    if (_command.isEmpty) {
      await _tts!.speak("Silakan rekam perintah terlebih dahulu.");
      return;
    }
    if (_apiKey == null || _apiKey!.isEmpty) {
      await _tts!.speak("API Key belum diatur.");
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ApiSettingsScreen()));
      return;
    }

    setState(() => _isProcessing = true);
    await _tts!.speak("Sedang mengirim ke AI, tunggu sebentar.");

    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('sounds/loading.mp3'));

      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=$_apiKey');

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

      await _audioPlayer.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseText = data['candidates'][0]['content']['parts'][0]
                ['text'] ??
            'Tidak ada jawaban dari AI.';

        await _tts!.speak(responseText);

        if (mounted) {
          _showResponseDialog(responseText);
        }
      } else {
        await _tts!.speak("Gagal terhubung ke server AI.");
      }
    } catch (e) {
      await _tts!.speak("Terjadi kesalahan saat mengirim data.");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showResponseDialog(String response) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Jawaban AI"),
        content: SingleChildScrollView(child: Text(response)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("OK")),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _trialTimer?.cancel();
    _cameraController?.dispose();
    _speech?.stop();
    _tts?.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview tunggal sebagai background
          if (_isCameraInitialized)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            ),

          // 2 Tombol Penuh Layar (KIRI & KANAN) dengan overlay
          Row(
            children: [
              // ========== TOMBOL KIRI: COMMAND ==========
              Expanded(
                child: GestureDetector(
                  onTap: _isProcessing ? null : _toggleListening,
                  child: Container(
                    color: Colors.transparent,
                    child: Stack(
                      children: [
                        // Overlay gradient biru untuk Command
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: _isListening
                                    ? [
                                        Colors.red.withOpacity(0.7),
                                        Colors.red.withOpacity(0.5),
                                      ]
                                    : [
                                        Colors.blue.withOpacity(0.6),
                                        Colors.blue.withOpacity(0.3),
                                      ],
                              ),
                            ),
                          ),
                        ),

                        // Icon & Text Command
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isListening ? Icons.stop_circle : Icons.mic,
                                color: Colors.white,
                                size: 100,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _isListening ? "STOP" : "COMMAND",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black,
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Garis pemisah tengah
              Container(
                width: 3,
                color: Colors.white.withOpacity(0.5),
              ),

              // ========== TOMBOL KANAN: SOS ==========
              Expanded(
                child: GestureDetector(
                  onTap: _isProcessing ? null : _handleSOS,
                  child: Container(
                    color: Colors.transparent,
                    child: Stack(
                      children: [
                        // Overlay gradient merah untuk SOS
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                                colors: [
                                  Colors.red.shade800.withOpacity(0.6),
                                  Colors.red.shade600.withOpacity(0.4),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Icon & Text SOS
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 100,
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                "SOS",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black,
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Trial Left Button dan Login Button di atas (hanya untuk mode trial)
          if (widget.isTrial)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Trial Left Button
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Text(
                      'Trial Left : ${_trialMinutes.toString().padLeft(2, '0')}:${_trialSeconds.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Login Button
                  GestureDetector(
                    onTap: () {
                      _trialTimer?.cancel();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B9BD8),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.login,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Login',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // OurEye Wali Button (hanya untuk mode authenticated - setelah login)
          if (!widget.isTrial)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TrackLocationScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Text(
                      'OurEye Wali',
                      style: TextStyle(
                        color: Color(0xFF1B9BD8),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Logout Button (Pojok Kanan Atas - Authenticated Mode)
          if (!widget.isTrial)
            Positioned(
              top: 25,
              right: 20,
              child: GestureDetector(
                onTap: _handleLogout,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.logout,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

          // Status Command di atas
          if (_command.isNotEmpty && !_isListening)
            Positioned(
              top: 50,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _command,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Listening Indicator
          if (_isListening)
            Positioned(
              top: 50,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Mendengarkan...",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Tombol Capture di tengah
          if (_command.isNotEmpty && !_isListening && !_isProcessing)
            Center(
              child: GestureDetector(
                onTap: _captureAndSend,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.black,
                    size: 45,
                  ),
                ),
              ),
            ),

          // Loading Overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 5,
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Memproses...",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Loading Camera
          if (!_isCameraInitialized)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }
}
