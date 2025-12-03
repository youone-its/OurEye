import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;
import 'package:oureye/screens/camera_screen.dart';

class AuthenticatedSplashScreen extends StatefulWidget {
  const AuthenticatedSplashScreen({super.key});

  @override
  State<AuthenticatedSplashScreen> createState() =>
      _AuthenticatedSplashScreenState();
}

class _AuthenticatedSplashScreenState extends State<AuthenticatedSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _tts = FlutterTts();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Rotating animation for loading ring
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Pulse animation for logo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Fade animation for text
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Speak first instruction
    _announceInstruction();
  }

  /// 🔊 TTS Normal Instruction
  Future<void> _announceInstruction() async {
    try {
      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(0.9);
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

    // Start rotation animation
    _rotationController.repeat();

    try {
      // TTS: "Menyiapkan aplikasi"
      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(0.9);
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
      await _tts.setSpeechRate(0.9);
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
        MaterialPageRoute(builder: (_) => const CameraScreen(isTrial: false)),
      );
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
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
                // SVG Logo + rotating ring with pulse effect
                SizedBox(
                  width: 300,
                  height: 300,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer glow ring (static)
                      Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.1),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ),

                      // Pulsing Logo
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (_, child) {
                          return Transform.scale(
                            scale: _isLoading ? _pulseAnimation.value : 1.0,
                            child: child,
                          );
                        },
                        child: SvgPicture.asset(
                          'assets/images/ourLogo.svg',
                          width: 140,
                          height: 140,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),

                      // Rotating double ring loading indicator
                      if (_isLoading) ...[
                        // Outer ring
                        AnimatedBuilder(
                          animation: _rotationController,
                          builder: (_, child) {
                            return Transform.rotate(
                              angle: _rotationController.value * 2 * math.pi,
                              child: child,
                            );
                          },
                          child: SizedBox(
                            width: 260,
                            height: 260,
                            child: CircularProgressIndicator(
                              strokeWidth: 4,
                              valueColor: AlwaysStoppedAnimation(
                                Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ),

                        // Inner ring (counter-rotating)
                        AnimatedBuilder(
                          animation: _rotationController,
                          builder: (_, child) {
                            return Transform.rotate(
                              angle: -_rotationController.value * 3 * math.pi,
                              child: child,
                            );
                          },
                          child: SizedBox(
                            width: 220,
                            height: 220,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation(
                                Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 50),

                // Animated text
                AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (_, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: child,
                    );
                  },
                  child: Column(
                    children: [
                      const Text(
                        "AI Visual Assistant",
                        style: TextStyle(
                          fontSize: 18,
                          color: Color.fromRGBO(255, 255, 255, 0.8),
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1.5,
                        ),
                      ),
                      if (_isLoading) ...[
                        const SizedBox(height: 30),
                        const Text(
                          "Menyiapkan aplikasi...",
                          style: TextStyle(
                            fontSize: 14,
                            color: Color.fromRGBO(255, 255, 255, 0.6),
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ],
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
