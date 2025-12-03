import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'camera_screen.dart';

class InitialSplashScreen extends StatefulWidget {
  const InitialSplashScreen({super.key});

  @override
  State<InitialSplashScreen> createState() => _InitialSplashScreenState();
}

class _InitialSplashScreenState extends State<InitialSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

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

    // Auto navigate after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CameraScreen(isTrial: true)),
        );
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const CameraScreen(isTrial: true)),
          );
        },
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0284C7),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // SVG Logo with pulse effect
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
                            scale: _pulseAnimation.value,
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
                  child: const Column(
                    children: [
                      Text(
                        "AI Visual Assistant",
                        style: TextStyle(
                          fontSize: 18,
                          color: Color.fromRGBO(255, 255, 255, 0.8),
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        "Trial Mode",
                        style: TextStyle(
                          fontSize: 16,
                          color: Color.fromRGBO(255, 255, 255, 0.6),
                          fontWeight: FontWeight.w500,
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
    );
  }
}
