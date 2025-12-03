import 'package:flutter/material.dart';

class TrackLocationScreen extends StatefulWidget {
  const TrackLocationScreen({super.key});

  @override
  State<TrackLocationScreen> createState() => _TrackLocationScreenState();
}

class _TrackLocationScreenState extends State<TrackLocationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map Background (placeholder - will need google_maps_flutter package for real map)
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map,
                    size: 100,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Map View',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Install google_maps_flutter package\nfor real map integration',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Multiple Location Markers (simulated)
          ...List.generate(10, (index) {
            final positions = [
              const Offset(50, 100),
              const Offset(150, 200),
              const Offset(250, 150),
              const Offset(100, 300),
              const Offset(300, 250),
              const Offset(200, 400),
              const Offset(80, 500),
              const Offset(280, 450),
              const Offset(150, 550),
              const Offset(320, 350),
            ];

            if (index >= positions.length) return const SizedBox.shrink();

            return Positioned(
              left: positions[index].dx,
              top: positions[index].dy,
              child: Icon(
                Icons.location_on,
                color: index == 4
                    ? const Color(0xFF1B9BD8)
                    : const Color(0xFF0D47A1),
                size: index == 4 ? 50 : 40,
              ),
            );
          }),

          // Track Location Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B9BD8),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Text(
                'Track Location',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Bottom Info Card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: const BoxDecoration(
                color: Color(0xFF1B9BD8),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Fulan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Current Location :',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'TW 2 ITS, Sukolilo, Surabaya, Indonesia',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Close Button
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1B9BD8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
