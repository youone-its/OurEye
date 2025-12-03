import 'package:postgres/postgres.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  PostgreSQLConnection? _connection;

  // NeonDB Connection Details
  static const String _host =
      'ep-raspy-wind-a11zt2ix-pooler.ap-southeast-1.aws.neon.tech';
  static const int _port = 5432;
  static const String _database = 'neondb';
  static const String _username = 'neondb_owner';
  static const String _password = 'npg_AiZk7bwTB3hq';

  Future<PostgreSQLConnection> get connection async {
    if (_connection != null && _connection!.isClosed == false) {
      return _connection!;
    }
    await _connect();
    return _connection!;
  }

  Future<void> _connect() async {
    try {
      _connection = PostgreSQLConnection(
        _host,
        _port,
        _database,
        username: _username,
        password: _password,
        useSSL: true,
      );

      await _connection!.open();

      print('✅ Connected to NeonDB successfully');

      // Initialize tables
      await _initializeTables();
    } catch (e) {
      print('❌ Error connecting to database: $e');
      rethrow;
    }
  }

  Future<void> _initializeTables() async {
    try {
      // Create users table
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id SERIAL PRIMARY KEY,
          email VARCHAR(255) UNIQUE NOT NULL,
          username VARCHAR(255) NOT NULL,
          password_hash VARCHAR(255) NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Create sos_alerts table
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS sos_alerts (
          id SERIAL PRIMARY KEY,
          user_id INTEGER REFERENCES users(id),
          latitude DOUBLE PRECISION,
          longitude DOUBLE PRECISION,
          address TEXT,
          status VARCHAR(50) DEFAULT 'active',
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          resolved_at TIMESTAMP
        )
      ''');

      // Create location_history table
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS location_history (
          id SERIAL PRIMARY KEY,
          user_id INTEGER REFERENCES users(id),
          latitude DOUBLE PRECISION,
          longitude DOUBLE PRECISION,
          address TEXT,
          recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Create command_history table
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS command_history (
          id SERIAL PRIMARY KEY,
          user_id INTEGER REFERENCES users(id),
          command_text TEXT,
          ai_response TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      print('✅ Database tables initialized');
    } catch (e) {
      print('❌ Error initializing tables: $e');
    }
  }

  // Hash password
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  // Register new user
  Future<Map<String, dynamic>?> registerUser({
    required String email,
    required String username,
    required String password,
  }) async {
    try {
      final conn = await connection;
      final passwordHash = _hashPassword(password);

      final result = await conn.query(
        'INSERT INTO users (email, username, password_hash) VALUES (@email, @username, @passwordHash) RETURNING id, email, username, created_at',
        substitutionValues: {
          'email': email,
          'username': username,
          'passwordHash': passwordHash,
        },
      );

      if (result.isNotEmpty) {
        final row = result.first;
        return {
          'id': row[0],
          'email': row[1],
          'username': row[2],
          'created_at': row[3],
        };
      }
      return null;
    } catch (e) {
      print('❌ Error registering user: $e');
      return null;
    }
  }

  // Login user
  Future<Map<String, dynamic>?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      final conn = await connection;
      final passwordHash = _hashPassword(password);

      final result = await conn.query(
        'SELECT id, email, username, created_at FROM users WHERE email = @email AND password_hash = @passwordHash',
        substitutionValues: {
          'email': email,
          'passwordHash': passwordHash,
        },
      );

      if (result.isNotEmpty) {
        final row = result.first;
        return {
          'id': row[0],
          'email': row[1],
          'username': row[2],
          'created_at': row[3],
        };
      }
      return null;
    } catch (e) {
      print('❌ Error logging in: $e');
      return null;
    }
  }

  // Create SOS alert
  Future<int?> createSOSAlert({
    required int userId,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    try {
      final conn = await connection;

      final result = await conn.query(
        'INSERT INTO sos_alerts (user_id, latitude, longitude, address) VALUES (@userId, @latitude, @longitude, @address) RETURNING id',
        substitutionValues: {
          'userId': userId,
          'latitude': latitude,
          'longitude': longitude,
          'address': address ?? 'Unknown location',
        },
      );

      if (result.isNotEmpty) {
        return result.first[0] as int;
      }
      return null;
    } catch (e) {
      print('❌ Error creating SOS alert: $e');
      return null;
    }
  }

  // Save location history
  Future<void> saveLocationHistory({
    required int userId,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    try {
      final conn = await connection;

      await conn.execute(
        'INSERT INTO location_history (user_id, latitude, longitude, address) VALUES (@userId, @latitude, @longitude, @address)',
        substitutionValues: {
          'userId': userId,
          'latitude': latitude,
          'longitude': longitude,
          'address': address ?? 'Unknown location',
        },
      );
    } catch (e) {
      print('❌ Error saving location history: $e');
    }
  }

  // Save command history
  Future<void> saveCommandHistory({
    required int userId,
    required String commandText,
    required String aiResponse,
  }) async {
    try {
      final conn = await connection;

      await conn.execute(
        'INSERT INTO command_history (user_id, command_text, ai_response) VALUES (@userId, @commandText, @aiResponse)',
        substitutionValues: {
          'userId': userId,
          'commandText': commandText,
          'aiResponse': aiResponse,
        },
      );
    } catch (e) {
      print('❌ Error saving command history: $e');
    }
  }

  // Get user's location history
  Future<List<Map<String, dynamic>>> getLocationHistory(int userId) async {
    try {
      final conn = await connection;

      final result = await conn.query(
        'SELECT latitude, longitude, address, recorded_at FROM location_history WHERE user_id = @userId ORDER BY recorded_at DESC LIMIT 50',
        substitutionValues: {
          'userId': userId,
        },
      );

      return result.map((row) {
        return {
          'latitude': row[0],
          'longitude': row[1],
          'address': row[2],
          'recorded_at': row[3],
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting location history: $e');
      return [];
    }
  }

  // Close connection
  Future<void> close() async {
    await _connection?.close();
    _connection = null;
  }
}
