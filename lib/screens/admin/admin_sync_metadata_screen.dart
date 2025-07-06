// lib/screens/admin/admin_sync_metadata_screen.dart
import 'package:damiu/models/daily_sync_metadata_model.dart';
import 'package:damiu/models/user_model.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AdminSyncMetadataScreen extends StatefulWidget {
  const AdminSyncMetadataScreen({super.key});
  @override
  State<AdminSyncMetadataScreen> createState() => _AdminSyncMetadataScreenState();
}

class _AdminSyncMetadataScreenState extends State<AdminSyncMetadataScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<DailySyncMetadataModel>>(
        stream: _firestoreService.getDailySyncMetadataStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Tidak ada data metadata.'));
          final metadataList = snapshot.data!;
          return ListView.builder(
            itemCount: metadataList.length,
            itemBuilder: (context, index) {
              final metadata = metadataList[index];
              return Card(
                child: ListTile(
                  title: Text('Tanggal: ${DateFormat('dd MMMM yyyy', 'id_ID').format(metadata.date)}'),
                  subtitle: FutureBuilder<String>(
                    future: _getUserName(metadata.lastSyncedByUid),
                    builder: (context, nameSnapshot) {
                      return Text('Disinkronkan Oleh: ${nameSnapshot.data ?? '...'} @ ${DateFormat('HH:mm:ss').format(metadata.lastSyncedAt)}');
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}