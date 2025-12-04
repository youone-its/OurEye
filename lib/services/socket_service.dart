import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  bool _isConnecting = false;

  // Socket.io server URL - sama seperti Python client (port 80 default via Nginx)
  static const String _serverUrl = 'http://178.128.122.114';

  bool get isConnected => _isConnected;

  // Connect to Socket.io server
  Future<void> connect() async {
    if (_socket != null && _isConnected) {
      debugPrint('✅ Socket already connected');
      return;
    }

    if (_isConnecting) {
      debugPrint('⏳ Connection in progress, waiting...');
      // Wait for connection to complete
      await Future.delayed(const Duration(seconds: 2));
      return;
    }

    _isConnecting = true;

    try {
      final connectionCompleter = Completer<void>();
      
      _socket = IO.io(
        _serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling']) // Add polling fallback
            .setTimeout(10000) // 10 seconds timeout
            .setReconnectionAttempts(5)
            .setReconnectionDelay(2000)
            .build(),
      );

      _socket!.onConnect((_) {
        _isConnected = true;
        _isConnecting = false;
        debugPrint('✅ Socket connected successfully to $_serverUrl');
        if (!connectionCompleter.isCompleted) {
          connectionCompleter.complete();
        }
      });

      _socket!.connect();

      // Wait for actual connection event with timeout
      await connectionCompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ Socket connection timeout after 5 seconds');
        },
      );

      _socket!.onDisconnect((_) {
        _isConnected = false;
        _isConnecting = false;
        debugPrint('❌ Socket disconnected');
      });

      _socket!.onConnectError((error) {
        _isConnected = false;
        _isConnecting = false;
        debugPrint('❌ Socket connection error: $error');
      });

      _socket!.onError((error) {
        debugPrint('❌ Socket error: $error');
      });

      _socket!.onReconnect((_) {
        _isConnected = true;
        debugPrint('🔄 Socket reconnected');
      });

      // Listen for topic join confirmation
      _socket!.on('topic_joined', (data) {
        debugPrint('✅ Topic joined confirmation: $data');
      });

      // Listen for errors
      _socket!.on('error', (data) {
        debugPrint('❌ Socket error event: $data');
      });

    } catch (e) {
      _isConnected = false;
      _isConnecting = false;
      debugPrint('❌ Socket connection failed: $e');
    }
  }

  // ==================== PUBLISHER MODE (User/Blind) ====================
  
  /// Publish location updates to server (for User app)
  void publishLocation({
    required String userId,
    required double latitude,
    required double longitude,
    String? topic,
    double? heading,
  }) {
    if (_socket == null || !_isConnected) {
      debugPrint('⚠️ Socket not connected. Cannot publish location.');
      return;
    }

    final data = {
      'user_id': userId,
      'lat': latitude,
      'lng': longitude,
      'heading': heading ?? 0.0,
      'topic': topic,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _socket!.emit('location_update', data);
    debugPrint('📍 Location published: $data');
  }

  /// Publish SOS alert to guardian's topic (for User app)
  void publishSOS({
    required String userId,
    required int guardianId,
    required String guardianTopic,
    double? latitude,
    double? longitude,
    String? address,
  }) {
    if (_socket == null || !_isConnected) {
      debugPrint('⚠️ Socket not connected. Cannot publish SOS.');
      return;
    }

    final data = {
      'type': 'SOS',
      'userId': userId,
      'guardianId': guardianId,
      'topic': guardianTopic,
      'location': {
        'lat': latitude,
        'lng': longitude,
        'address': address ?? 'Unknown location',
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'timestampISO': DateTime.now().toIso8601String(),
    };

    // Emit SOS to guardian's topic
    _socket!.emit('sos_alert', data);
    debugPrint('🚨 SOS Alert published to $guardianTopic: $data');
  }

  /// Join a topic/room to receive updates from specific user
  void joinTopic(String topic) {
    if (_socket == null || !_isConnected) {
      debugPrint('⚠️ Socket not connected. Cannot join topic.');
      return;
    }

    _socket!.emit('join_topic', {'topic': topic});
    debugPrint('👂 Joined topic: $topic');
  }

  /// Auto-join user's own topic after connection (called by user app after login)
  void joinUserTopic(String userId) {
    final topic = 'user_$userId';
    joinTopic(topic);
    debugPrint('🔑 Auto-joined own topic: $topic');
  }

  /// Leave a topic/room
  void leaveTopic(String topic) {
    if (_socket == null || !_isConnected) {
      debugPrint('⚠️ Socket not connected. Cannot leave topic.');
      return;
    }

    _socket!.emit('leave_topic', {'topic': topic});
    debugPrint('👋 Left topic: $topic');
  }

  /// Subscribe to location updates from user (Guardian receives this)
  void subscribeLocation(Function(Map<String, dynamic>) callback) {
    if (_socket == null) {
      debugPrint('⚠️ Socket not initialized. Cannot subscribe to location.');
      return;
    }

    _socket!.on('update_ui', (data) {
      debugPrint('📍 Location update received: $data');
      
      if (data is Map<String, dynamic>) {
        callback(data);
      } else {
        debugPrint('⚠️ Invalid location data format');
      }
    });

    debugPrint('✅ Subscribed to location updates');
  }

  /// Subscribe to SOS alerts from user (Guardian receives this)
  void subscribeSOS(Function(Map<String, dynamic>?) callback) {
    if (_socket == null) {
      debugPrint('⚠️ Socket not initialized. Cannot subscribe to SOS.');
      return;
    }

    // PENTING: Gunakan .on() yang persistent, bukan sekali listening
    // Ini memungkinkan menerima SOS berkali-kali tanpa perlu re-subscribe
    _socket!.on('sos_alert', (data) {
      debugPrint('🚨 SOS Alert received: $data');
      
      if (data is Map<String, dynamic>) {
        callback(data);
      } else {
        callback(null);
      }
    });

    debugPrint('✅ Subscribed to SOS alerts (persistent listener)');
  }

  /// Unsubscribe from location updates
  void unsubscribeLocation() {
    if (_socket != null) {
      _socket!.off('update_ui');
      debugPrint('❌ Unsubscribed from location updates');
    }
  }

  /// Unsubscribe from SOS alerts
  void unsubscribeSOS() {
    if (_socket != null) {
      _socket!.off('sos_alert');
      debugPrint('❌ Unsubscribed from SOS alerts');
    }
  }

  // ==================== COMMON ====================

  /// Disconnect from socket
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
      debugPrint('👋 Socket disconnected and disposed');
    }
  }

  /// Check connection status
  Future<bool> checkConnection() async {
    if (_socket == null) return false;
    return _isConnected;
  }
}
