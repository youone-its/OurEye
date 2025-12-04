import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../services/socket_service.dart';
import 'initial_splash_screen.dart';
import 'select_user_screen.dart';
import 'manage_users_screen.dart';

class WaliDashboardScreen extends StatefulWidget {
  const WaliDashboardScreen({super.key});

  @override
  State<WaliDashboardScreen> createState() => _WaliDashboardScreenState();
}

class _WaliDashboardScreenState extends State<WaliDashboardScreen> {
  String _username = '';
  final SocketService _socketService = SocketService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _guardianId;
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initializeSOSMonitoring();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? 'Wali';
      _guardianId = prefs.getInt('user_id');
    });
  }

  Future<void> _initializeSOSMonitoring() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _guardianId = prefs.getInt('user_id');

      if (_guardianId == null) {
        debugPrint('⚠️ Guardian ID not found');
        return;
      }

      // Connect to socket
      await _socketService.connect();

      // PENTING: Subscribe ke SOS alerts SEBELUM join topic
      // Ini memastikan listener siap menangkap SOS event
      _socketService.subscribeSOS((data) {
        if (data != null) {
          _handleSOSAlert(data);
        }
      });
      debugPrint('✅ SOS alert listener ready');

      // SEKARANG join guardian's own topic untuk menerima SOS
      final guardianTopic = 'wali_$_guardianId';
      _socketService.joinTopic(guardianTopic);
      debugPrint('👂 Guardian standby on topic: $guardianTopic');

      setState(() {
        _isMonitoring = true;
      });

      debugPrint('✅ SOS monitoring active for wali_$_guardianId');
    } catch (e) {
      debugPrint('❌ Error initializing SOS monitoring: $e');
    }
  }

  Future<void> _handleSOSAlert(Map<String, dynamic> data) async {
    debugPrint('🚨 SOS ALERT RECEIVED: $data');

    // Play alarm sound
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('sounds/alarm.wav'));
    } catch (e) {
      debugPrint('Error playing alarm: $e');
    }

    // Vibrate
    try {
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500], amplitude: 255);
      }
    } catch (e) {
      debugPrint('Error vibrating: $e');
    }

    // Show SOS dialog
    if (mounted) {
      _showSOSDialog(data);
    }
  }

  void _showSOSDialog(Map<String, dynamic> data) {
    final userId = data['userId']?.toString() ?? 'Unknown';
    final location = data['location'] ?? {};
    final lat = location['lat'];
    final lng = location['lng'];
    final address = location['address'] ?? 'Unknown location';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
            SizedBox(width: 12),
            Text(
              'SOS ALERT!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User ID: $userId',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Location: $address',
              style: TextStyle(color: Colors.white),
            ),
            if (lat != null && lng != null)
              Text(
                'Coordinates: $lat, $lng',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _audioPlayer.stop();
              Vibration.cancel();
              Navigator.pop(context);
            },
            child: Text('DISMISS', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () {
              _audioPlayer.stop();
              Vibration.cancel();
              Navigator.pop(context);
              // TODO: Navigate to map showing user location
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            child: Text('VIEW MAP', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    // Cleanup socket
    if (_guardianId != null) {
      _socketService.leaveTopic('wali_$_guardianId');
    }
    _socketService.disconnect();
    _audioPlayer.dispose();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    await prefs.remove('user_email');
    await prefs.remove('user_role');

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const InitialSplashScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    if (_guardianId != null) {
      _socketService.leaveTopic('wali_$_guardianId');
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Dashboard Wali'),
        backgroundColor: const Color(0xFF1B9BD8),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1B9BD8),
                    Color(0xFF1584BB),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selamat Datang, $_username',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Dashboard Wali untuk memantau pengguna tunanetra',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // SOS Monitoring Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isMonitoring ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isMonitoring ? Icons.wifi : Icons.wifi_off,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isMonitoring ? 'SOS Monitoring Active' : 'Connecting...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu Cards
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fitur Utama',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B9BD8),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Track Location Card
                  _buildFeatureCard(
                    icon: Icons.location_on,
                    title: 'Tracking Lokasi',
                    subtitle: 'Pantau lokasi pengguna real-time',
                    color: Colors.green,
                    onTap: () {
                      // Navigate to Select User Screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SelectUserScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // SOS Alerts Card
                  _buildFeatureCard(
                    icon: Icons.warning_amber_rounded,
                    title: 'SOS Alerts',
                    subtitle: 'Daftar panggilan darurat',
                    color: Colors.red,
                    onTap: () {
                      // TODO: Navigate to SOS alerts screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fitur SOS alerts akan segera hadir'),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Location History Card
                  _buildFeatureCard(
                    icon: Icons.history,
                    title: 'Riwayat Lokasi',
                    subtitle: 'Lihat riwayat perjalanan',
                    color: Colors.blue,
                    onTap: () {
                      // TODO: Navigate to location history screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fitur riwayat akan segera hadir'),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Connected Users Card
                  _buildFeatureCard(
                    icon: Icons.people,
                    title: 'Daftar Pengguna',
                    subtitle: 'Kelola daftar pengguna yang dipantau',
                    color: Colors.purple,
                    onTap: () {
                      // Navigate to manage users screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ManageUsersScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Info Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Sebagai wali, Anda dapat memantau lokasi dan status pengguna tunanetra yang terhubung dengan akun Anda.',
                            style: TextStyle(fontSize: 13),
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
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
