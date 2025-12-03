import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../services/socket_service.dart';

class GuardianMapScreen extends StatefulWidget {
  final String monitoredUserId;
  final String userTopic;
  final String userName;

  const GuardianMapScreen({
    super.key,
    required this.monitoredUserId,
    required this.userTopic,
    required this.userName,
  });

  @override
  State<GuardianMapScreen> createState() => _GuardianMapScreenState();
}

class _GuardianMapScreenState extends State<GuardianMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final SocketService _socketService = SocketService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Map state
  final Set<Marker> _markers = {};
  LatLng _currentUserLocation = const LatLng(-6.2088, 106.8456); // Default: Jakarta
  double _currentHeading = 0.0;
  bool _isTracking = false;
  bool _isConnected = false;

  // User info
  String _userStatus = 'Offline';
  DateTime? _lastUpdate;
  String _address = 'Waiting for location...';

  @override
  void initState() {
    super.initState();
    _initializeSocket();
  }

  Future<void> _initializeSocket() async {
    try {
      // Connect to socket
      await _socketService.connect();

      setState(() {
        _isConnected = _socketService.isConnected;
      });

      // Join topic untuk user yang dipantau (dari database)
      debugPrint('👂 Joining topic: ${widget.userTopic}');
      _socketService.joinTopic(widget.userTopic);

      // Subscribe to location updates
      _socketService.subscribeLocation((data) {
        _handleLocationUpdate(data);
      });

      // Subscribe to SOS alerts
      _socketService.subscribeSOS((data) {
        _handleSOSAlert(data);
      });

      setState(() {
        _isTracking = true;
      });
    } catch (e) {
      debugPrint('Error initializing socket: $e');
      _showErrorSnackbar('Failed to connect to tracking server');
    }
  }

  void _handleLocationUpdate(Map<String, dynamic> data) {
    try {
      final double lat = (data['lat'] ?? data['latitude']) as double;
      final double lng = (data['lng'] ?? data['longitude']) as double;
      final double heading = (data['heading'] ?? 0.0) as double;

      setState(() {
        _currentUserLocation = LatLng(lat, lng);
        _currentHeading = heading;
        _userStatus = 'Online';
        _lastUpdate = DateTime.now();
        _address = 'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}';
      });

      // Update marker
      _updateMarker();

      // Animate camera to follow user
      _animateCameraToUser();
    } catch (e) {
      debugPrint('Error handling location update: $e');
    }
  }

  void _handleSOSAlert(Map<String, dynamic>? data) async {
    // Play alarm sound
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('sounds/alarm.wav'));
    } catch (e) {
      debugPrint('Error playing alarm: $e');
    }

    // Vibrate device
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
      _showSOSDialog();
    }
  }

  void _updateMarker() {
    final marker = Marker(
      markerId: const MarkerId('user_location'),
      position: _currentUserLocation,
      rotation: _currentHeading,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: InfoWindow(
        title: 'User Location',
        snippet: _address,
      ),
    );

    setState(() {
      _markers.clear();
      _markers.add(marker);
    });
  }

  Future<void> _animateCameraToUser() async {
    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(_currentUserLocation, 17.0),
    );
  }

  void _showSOSDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SOSAlertDialog(
        onDismiss: () {
          _audioPlayer.stop();
          Vibration.cancel();
          Navigator.pop(context);
        },
        userLocation: _currentUserLocation,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    // Cleanup
    _socketService.unsubscribeLocation();
    _socketService.unsubscribeSOS();
    _socketService.leaveTopic(widget.userTopic);
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentUserLocation,
              zoom: 15.0,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            onMapCreated: (GoogleMapController controller) {
              _mapController.complete(controller);
            },
          ),

          // Top Status Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildStatusBar(),
          ),

          // Bottom Info Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildInfoPanel(),
          ),

          // Floating Action Buttons
          Positioned(
            right: 16,
            bottom: 200,
            child: Column(
              children: [
                // Center on user button
                FloatingActionButton(
                  heroTag: 'center',
                  onPressed: _animateCameraToUser,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location, color: Colors.blue),
                ),
                const SizedBox(height: 12),
                // Refresh connection button
                FloatingActionButton(
                  heroTag: 'refresh',
                  onPressed: _initializeSocket,
                  backgroundColor: Colors.white,
                  child: Icon(
                    _isConnected ? Icons.wifi : Icons.wifi_off,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      margin: const EdgeInsets.only(top: 50, left: 16, right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          // Status indicator
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _userStatus == 'Online' ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          // Status text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _userStatus,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (_lastUpdate != null)
                  Text(
                    'Updated ${_getTimeAgo(_lastUpdate!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          // Tracking indicator
          if (_isTracking)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.radar, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Tracking',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            'User Location',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Location info
          _buildInfoRow(
            Icons.place,
            'Location',
            _address,
          ),
          const SizedBox(height: 12),

          // Heading info
          _buildInfoRow(
            Icons.navigation,
            'Heading',
            '${_currentHeading.toStringAsFixed(1)}°',
          ),
          const SizedBox(height: 12),

          // Speed info (if available)
          _buildInfoRow(
            Icons.speed,
            'Status',
            _userStatus,
          ),

          const SizedBox(height: 16),

          // Call/Message buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement call feature
                    _showErrorSnackbar('Call feature coming soon');
                  },
                  icon: const Icon(Icons.call),
                  label: const Text('Call User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Implement message feature
                    _showErrorSnackbar('Message feature coming soon');
                  },
                  icon: const Icon(Icons.message),
                  label: const Text('Message'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final Duration diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// SOS Alert Dialog Widget
class _SOSAlertDialog extends StatefulWidget {
  final VoidCallback onDismiss;
  final LatLng userLocation;

  const _SOSAlertDialog({
    required this.onDismiss,
    required this.userLocation,
  });

  @override
  State<_SOSAlertDialog> createState() => _SOSAlertDialogState();
}

class _SOSAlertDialogState extends State<_SOSAlertDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: Colors.red.shade700,
      end: Colors.red.shade900,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _colorAnimation.value,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 60,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Text(
                  'SOS ALERT!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Message
                const Text(
                  'User needs immediate help!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),

                // Location
                Text(
                  'Location: ${widget.userLocation.latitude.toStringAsFixed(6)}, ${widget.userLocation.longitude.toStringAsFixed(6)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onDismiss,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Dismiss'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onDismiss();
                          // TODO: Navigate to user or call emergency
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Go to User',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
