// lib/screens/admin/admin_returned_gallon_log_screen.dart
import 'package:damiu/models/returned_gallon_log_model.dart';
import 'package:damiu/models/user_model.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminReturnedGallonLogScreen extends StatefulWidget {
  const AdminReturnedGallonLogScreen({super.key});

  @override
  State<AdminReturnedGallonLogScreen> createState() =>
      _AdminReturnedGallonLogScreenState();
}

class _AdminReturnedGallonLogScreenState
    extends State<AdminReturnedGallonLogScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final Map<String, String> _userNamesCache = {};

  Future<String> _getUserName(String? uid) async {
    if (uid == null || uid.isEmpty) return 'Tidak diketahui';
    if (_userNamesCache.containsKey(uid)) return _userNamesCache[uid]!;
    try {
      final UserModel? user = await _authService.getUserModel(uid);
      final userName = user?.name ?? 'UID: ${uid.substring(0, 6)}...';
      _userNamesCache[uid] = userName;
      return userName;
    } catch (e) {
      return 'Gagal memuat';
    }
  }

  void _handleApiResponse(String? error, String successMessage) {
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage), backgroundColor: Colors.green),
      );
    }
  }

  void _showDeleteConfirmDialog(ReturnedGallonLog log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Log?'),
        content: Text(
            'Anda yakin ingin menghapus log ini? (${log.quantity} galon pada ${DateFormat('dd/MM/yy HH:mm').format(log.createdAt)})'),
        actions: [
          TextButton(
            child: const Text('Batal'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final error =
                  await _firestoreService.deleteReturnedGallonLog(log.id);
              _handleApiResponse(error, 'Log berhasil dihapus.');
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteAllConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Semua Log?'),
        content: const Text(
            'Anda yakin ingin menghapus SEMUA data log galon kembali? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            child: const Text('Batal'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Hapus Semua', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final error = await _firestoreService.deleteAllReturnedGallonLogs();
              _handleApiResponse(error, 'Semua log berhasil dihapus.');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Galon Kembali'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _showDeleteAllConfirmDialog,
            tooltip: 'Hapus Semua Log',
          ),
        ],
      ),
      body: StreamBuilder<List<ReturnedGallonLog>>(
        stream: _firestoreService.getReturnedGallonLogsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Belum ada data log galon kembali.'));
          }

          final logs = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    foregroundColor: Theme.of(context).primaryColor,
                    child: const Icon(Icons.inventory_2_outlined),
                  ),
                  title: Text('${log.quantity} Galon Kembali', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pada: ${DateFormat('EEEE, dd MMM yyyy - HH:mm', 'id_ID').format(log.createdAt)}'),
                      FutureBuilder<String>(
                        future: _getUserName(log.employeeUid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Text('Oleh: Memuat...', style: TextStyle(fontSize: 12, color: Colors.grey));
                          }
                          return Text('Oleh: ${snapshot.data ?? 'Tidak diketahui'}', style: const TextStyle(fontSize: 12, color: Colors.grey));
                        },
                      ),
                    ],
                  ),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _showDeleteConfirmDialog(log)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
