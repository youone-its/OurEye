import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;
import 'package:oureye/screens/camera_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _tts = FlutterTts();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Rotating animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Speak first instruction
    _announceInstruction();
  }

  /// 🔊 TTS Normal Instruction
  Future<void> _announceInstruction() async {
    try {
      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(1.0);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);

      await Future.delayed(const Duration(milliseconds: 400));
      await _tts.speak("Silakan tekan layar");
    } catch (e) {
      debugPrint("Error initial TTS: $e");
    }
  }

  /// 🚀 Start App Loading
  Future<void> _startApp() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // TTS: "Menyiapkan aplikasi"
      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(1.0);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.speak("Menyiapkan aplikasi");
      await _tts.awaitSpeakCompletion(true);
    } catch (e) {
      debugPrint("Error TTS: $e");
    }

    // Play loading sound
    try {
      await _audioPlayer.play(AssetSource('sounds/loading.mp3'));
    } catch (e) {
      debugPrint("Audio error: $e");
    }

    // Simulate processing
    await Future.delayed(const Duration(seconds: 3));

    // Stop sound → speak "Aplikasi siap"
    try {
      await _audioPlayer.stop();

      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(1.0);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.speak("Aplikasi siap");
      await _tts.awaitSpeakCompletion(true);
    } catch (e) {
      debugPrint("Final TTS error: $e");
    }

    // Navigate
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: !_isLoading ? _startApp : null,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0284C7),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // SVG Logo + rotating ring
                SizedBox(
                  width: 250,
                  height: 250,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Logo SVG
                      SvgPicture.asset(
                        'assets/images/ourLogo.svg',
                        width: 150,
                        height: 150,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),

                      // Rotating loading indicator
                      if (_isLoading)
                        AnimatedBuilder(
                          animation: _controller,
                          builder: (_, child) {
                            return Transform.rotate(
                              angle: _controller.value * 2 * math.pi,
                              child: child,
                            );
                          },
                          child: const SizedBox(
                            width: 240,
                            height: 240,
                            child: CircularProgressIndicator(
                              strokeWidth: 5,
                              valueColor: AlwaysStoppedAnimation(
                                Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                const SizedBox(height: 12),

                const Text(
                  "AI Visual Assistant",
                  style: TextStyle(
                    fontSize: 20,
                    color: Color.fromRGBO(255, 255, 255, 0.7),
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
