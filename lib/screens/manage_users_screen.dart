import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _monitoredUsers = [];
  bool _isLoading = true;
  int? _guardianId;

  @override
  void initState() {
    super.initState();
    _loadGuardianData();
  }

  Future<void> _loadGuardianData() async {
    final prefs = await SharedPreferences.getInstance();
    _guardianId = prefs.getInt('user_id');

    if (_guardianId != null) {
      await _loadMonitoredUsers();
    }
  }

  Future<void> _loadMonitoredUsers() async {
    if (_guardianId == null) return;

    setState(() => _isLoading = true);

    try {
      final users = await _dbService.getGuardianUsers(_guardianId!);
      setState(() {
        _monitoredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showAddUserDialog() async {
    final emailController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Pengguna'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Masukkan email pengguna yang ingin dipantau:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email Pengguna',
                hintText: 'user@example.com',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email tidak boleh kosong')),
                );
                return;
              }

              Navigator.pop(context);
              await _addUserByEmail(email);
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  Future<void> _addUserByEmail(String email) async {
    if (_guardianId == null) return;

    try {
      // Find user by email
      final conn = await _dbService.connection;
      final result = await conn.query(
        'SELECT id, username, email, role FROM users WHERE email = @email',
        substitutionValues: {'email': email},
      );

      if (result.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ User dengan email tersebut tidak ditemukan')),
          );
        }
        return;
      }

      final userId = result.first[0] as int;
      final userRole = result.first[3] as String;

      // Verify user is not a guardian
      if (userRole == 'wali') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Tidak bisa menambahkan wali sebagai pengguna yang dipantau')),
          );
        }
        return;
      }

      // Add relation
      final success = await _dbService.addGuardianUserRelation(
        guardianId: _guardianId!,
        userId: userId,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Pengguna berhasil ditambahkan!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadMonitoredUsers();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Gagal menambahkan pengguna')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _removeUser(int userId, String username) async {
    if (_guardianId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pengguna'),
        content: Text('Yakin ingin berhenti memantau $username?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _dbService.removeGuardianUserRelation(
        guardianId: _guardianId!,
        userId: userId,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Pengguna berhasil dihapus'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadMonitoredUsers();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Daftar Pengguna'),
        backgroundColor: const Color(0xFF1B9BD8),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _monitoredUsers.isEmpty
              ? _buildEmptyState()
              : _buildUserList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        backgroundColor: const Color(0xFF1B9BD8),
        icon: const Icon(Icons.person_add),
        label: const Text('Tambah User'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 100,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            'Belum Ada Pengguna',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tekan tombol + untuk menambahkan\npengguna yang ingin dipantau',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _monitoredUsers.length,
      itemBuilder: (context, index) {
        final user = _monitoredUsers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF1B9BD8),
              child: Text(
                user['username'][0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              user['username'],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  user['email'],
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                if (user['topic'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Topic: ${user['topic']}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeUser(user['id'], user['username']),
            ),
          ),
        );
      },
    );
  }
}
