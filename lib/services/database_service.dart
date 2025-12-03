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
          role VARCHAR(20) DEFAULT 'user' CHECK (role IN ('user', 'wali')),
          topic VARCHAR(100) UNIQUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Create guardian_users relational table (one wali can have multiple users)
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS guardian_users (
          id SERIAL PRIMARY KEY,
          guardian_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
          user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(guardian_id, user_id)
        )
      ''');

      // Create sos_alerts table
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS sos_alerts (
          id SERIAL PRIMARY KEY,
          user_id INTEGER REFERENCES users(id),
          guardian_id INTEGER REFERENCES users(id),
          latitude DOUBLE PRECISION,
          longitude DOUBLE PRECISION,
          address TEXT,
          topic VARCHAR(100),
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
    String role = 'user', // Default role is 'user'
  }) async {
    try {
      final conn = await connection;
      final passwordHash = _hashPassword(password);

      final result = await conn.query(
        'INSERT INTO users (email, username, password_hash, role) VALUES (@email, @username, @passwordHash, @role) RETURNING id, email, username, role, created_at',
        substitutionValues: {
          'email': email,
          'username': username,
          'passwordHash': passwordHash,
          'role': role,
        },
      );

      if (result.isNotEmpty) {
        final row = result.first;
        return {
          'id': row[0],
          'email': row[1],
          'username': row[2],
          'role': row[3],
          'created_at': row[4],
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
        'SELECT id, email, username, role, topic, created_at FROM users WHERE email = @email AND password_hash = @passwordHash',
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
          'role': row[3],
          'topic': row[4],
          'created_at': row[5],
        };
      }
      return null;
    } catch (e) {
      print('❌ Error logging in: $e');
      return null;
    }
  }

  // ========== GUARDIAN-USER RELATIONSHIP METHODS ==========

  /// Menambahkan relasi guardian-user (wali mengadopsi user tunanetra)
  Future<bool> addGuardianUserRelation({
    required int guardianId,
    required int userId,
  }) async {
    try {
      final conn = await connection;

      // Verify guardian is actually a wali
      final guardianCheck = await conn.query(
        'SELECT role FROM users WHERE id = @guardianId',
        substitutionValues: {'guardianId': guardianId},
      );

      if (guardianCheck.isEmpty || guardianCheck.first[0] != 'wali') {
        print('❌ User $guardianId is not a guardian');
        return false;
      }

      // Add relation (UNIQUE constraint prevents duplicates)
      await conn.execute(
        'INSERT INTO guardian_users (guardian_id, user_id) VALUES (@guardianId, @userId) ON CONFLICT (guardian_id, user_id) DO NOTHING',
        substitutionValues: {
          'guardianId': guardianId,
          'userId': userId,
        },
      );

      print('✅ Guardian $guardianId now monitors user $userId');
      return true;
    } catch (e) {
      print('❌ Error adding guardian-user relation: $e');
      return false;
    }
  }

  /// Mendapatkan semua user yang dimonitor oleh guardian
  Future<List<Map<String, dynamic>>> getGuardianUsers(int guardianId) async {
    try {
      final conn = await connection;

      final result = await conn.query(
        '''
        SELECT u.id, u.email, u.username, u.topic, gu.created_at 
        FROM guardian_users gu
        JOIN users u ON gu.user_id = u.id
        WHERE gu.guardian_id = @guardianId
        ORDER BY gu.created_at DESC
        ''',
        substitutionValues: {'guardianId': guardianId},
      );

      return result.map((row) {
        return {
          'id': row[0],
          'email': row[1],
          'username': row[2],
          'topic': row[3],
          'added_at': row[4],
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting guardian users: $e');
      return [];
    }
  }

  /// Mendapatkan semua guardian yang memonitor user tertentu
  Future<List<Map<String, dynamic>>> getUserGuardians(int userId) async {
    try {
      final conn = await connection;

      final result = await conn.query(
        '''
        SELECT u.id, u.email, u.username, u.topic, gu.created_at 
        FROM guardian_users gu
        JOIN users u ON gu.guardian_id = u.id
        WHERE gu.user_id = @userId
        ORDER BY gu.created_at DESC
        ''',
        substitutionValues: {'userId': userId},
      );

      return result.map((row) {
        return {
          'id': row[0],
          'email': row[1],
          'username': row[2],
          'topic': row[3],
          'added_at': row[4],
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting user guardians: $e');
      return [];
    }
  }

  /// Menghapus relasi guardian-user
  Future<bool> removeGuardianUserRelation({
    required int guardianId,
    required int userId,
  }) async {
    try {
      final conn = await connection;

      await conn.execute(
        'DELETE FROM guardian_users WHERE guardian_id = @guardianId AND user_id = @userId',
        substitutionValues: {
          'guardianId': guardianId,
          'userId': userId,
        },
      );

      print('✅ Guardian $guardianId no longer monitors user $userId');
      return true;
    } catch (e) {
      print('❌ Error removing guardian-user relation: $e');
      return false;
    }
  }

  /// Generate unique topic for user (based on user ID)
  Future<String?> generateUserTopic(int userId) async {
    try {
      final conn = await connection;

      // Create topic format: user_<id>_<timestamp>
      final topic = 'user_${userId}_${DateTime.now().millisecondsSinceEpoch}';

      // Update user's topic field
      await conn.execute(
        'UPDATE users SET topic = @topic WHERE id = @userId',
        substitutionValues: {
          'topic': topic,
          'userId': userId,
        },
      );

      print('✅ Generated topic for user $userId: $topic');
      return topic;
    } catch (e) {
      print('❌ Error generating user topic: $e');
      return null;
    }
  }

  // ========== END GUARDIAN-USER METHODS ==========

  // Create SOS alert with guardian and topic
  Future<int?> createSOSAlert({
    required int userId,
    int? guardianId,
    required double latitude,
    required double longitude,
    String? address,
    String? topic,
  }) async {
    try {
      final conn = await connection;

      final result = await conn.query(
        'INSERT INTO sos_alerts (user_id, guardian_id, latitude, longitude, address, topic) VALUES (@userId, @guardianId, @latitude, @longitude, @address, @topic) RETURNING id',
        substitutionValues: {
          'userId': userId,
          'guardianId': guardianId,
          'latitude': latitude,
          'longitude': longitude,
          'address': address ?? 'Unknown location',
          'topic': topic,
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
