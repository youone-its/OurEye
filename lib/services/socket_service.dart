import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;

  // Socket.io server URL - ganti dengan URL server Anda
  static const String _serverUrl = 'http://178.128.122.114';

  bool get isConnected => _isConnected;

  // Connect to Socket.io server
  Future<void> connect() async {
    if (_socket != null && _isConnected) {
      debugPrint('✅ Socket already connected');
      return;
    }

    try {
      _socket = IO.io(
        _serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setExtraHeaders({'foo': 'bar'})
            .build(),
      );

      _socket!.connect();

      _socket!.onConnect((_) {
        _isConnected = true;
        debugPrint('✅ Socket connected successfully');
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        debugPrint('❌ Socket disconnected');
      });

      _socket!.onConnectError((error) {
        debugPrint('❌ Socket connection error: $error');
      });

      _socket!.onError((error) {
        debugPrint('❌ Socket error: $error');
      });
    } catch (e) {
      debugPrint('❌ Socket connection failed: $e');
    }
  }

  // ==================== PUBLISHER MODE (User/Blind) ====================
  
  /// Publish location updates to server (for User app)
  void publishLocation({
    required String userId,
    required double latitude,
    required double longitude,
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
      'timestamp': DateTime.now().toIso8601String(),
    };

    _socket!.emit('location_update', data);
    debugPrint('📍 Location published: $data');
  }

  /// Publish SOS alert with full payload (for User app)
  void publishSOS({
    required String userId,
    required String topic,
    List<int>? guardianIds,
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
      'topic': topic,
      'guardianIds': guardianIds ?? [],
      'location': {
        'lat': latitude,
        'lng': longitude,
        'address': address ?? 'Unknown location',
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'timestampISO': DateTime.now().toIso8601String(),
    };

    // Emit to topic channel (topic-based pub/sub)
    _socket!.emit('sos_alert', data);
    debugPrint('🚨 SOS Alert published to topic "$topic": $data');
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

    _socket!.on('sos_alert', (data) {
      debugPrint('🚨 SOS Alert received: $data');
      
      if (data is Map<String, dynamic>) {
        callback(data);
      } else {
        callback(null);
      }
    });

    debugPrint('✅ Subscribed to SOS alerts');
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
