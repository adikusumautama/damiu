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
  Map<String, String> _userNamesCache = {}; // Cache untuk nama pengguna

  Future<String> _getUserName(String? uid) async {
    if (uid == null || uid.isEmpty) {
      return 'Tidak diketahui';
    }
    if (_userNamesCache.containsKey(uid)) {
      return _userNamesCache[uid]!;
    }
    try {
      final UserModel? user = await _authService.getUserModel(uid);
      final userName = user?.name ?? 'UID: ${uid.substring(0, 6)}...';
      _userNamesCache[uid] = userName;
      return userName;
    } catch (e) {
      print("Error fetching user name for UID $uid: $e");
      return 'Gagal memuat nama';
    }
  }


  Future<void> _showEditMetadataDialog(DailySyncMetadataModel metadata) async {
    final TextEditingController deliveryCountController =
        TextEditingController(text: metadata.deliveryCount.toString());
    // UID tidak diedit di sini, hanya delivery count
    // Tanggal juga tidak diedit karena itu adalah ID dokumen

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Metadata Tgl: ${DateFormat('dd-MM-yyyy').format(metadata.date)}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: deliveryCountController,
                decoration: const InputDecoration(labelText: 'Jumlah Pengantaran'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Masukkan jumlah pengantaran';
                  }
                  if (int.tryParse(value) == null || int.parse(value) < 0) {
                    return 'Masukkan angka non-negatif';
                  }
                  return null;
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Simpan'),
              onPressed: () {
                if (deliveryCountController.text.isNotEmpty &&
                    int.tryParse(deliveryCountController.text) != null &&
                    int.parse(deliveryCountController.text) >= 0) {
                  Navigator.of(context).pop({
                    'delivery_count': int.parse(deliveryCountController.text),
                  });
                }
              },
            ),
          ],
        );
      },
    );

    if (result != null) {
      String? error = await _firestoreService.updateDailySyncMetadata(metadata.id, result);
      if (mounted) {
        if (error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Metadata berhasil diperbarui.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memperbarui metadata: $error')),
          );
        }
      }
    }
  }

  Future<void> _deleteMetadata(String docId, DateTime date) async {
    final bool confirm = await showDialog(
          context: context,
          builder: (BuildContext ctx) {
            return AlertDialog(
              title: const Text('Konfirmasi Hapus'),
              content: Text('Anda yakin ingin menghapus metadata tanggal ${DateFormat('dd-MM-yyyy').format(date)}?'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Batal'),
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Hapus'),
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirm) {
      String? error = await _firestoreService.deleteDailySyncMetadata(docId);
      if (mounted) {
        if (error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Metadata berhasil dihapus.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus metadata: $error')),
          );
        }
      }
    }
  }

  Future<void> _deleteAllMetadata() async {
    final bool confirm = await showDialog(
          context: context,
          builder: (BuildContext ctx) {
            return AlertDialog(
              title: const Text('Konfirmasi Hapus Semua Metadata'),
              content: const Text('Anda yakin ingin menghapus SEMUA data metadata sinkronisasi? Tindakan ini tidak dapat dibatalkan.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Batal'),
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Hapus Semua'),
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirm) {
      String? error = await _firestoreService.deleteAllDailySyncMetadata();
      if (mounted) {
        if (error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Semua metadata berhasil dihapus.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus semua metadata: $error')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Metadata Sinkronisasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
            onPressed: _deleteAllMetadata,
            tooltip: 'Hapus Semua Metadata',
          ),
        ],
      ),
      body: StreamBuilder<List<DailySyncMetadataModel>>(
        stream: _firestoreService.getDailySyncMetadataStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Tidak ada data metadata sinkronisasi.'));
          }

          final metadataList = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: metadataList.length,
            itemBuilder: (context, index) {
              final metadata = metadataList[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  title: Text('Tanggal: ${DateFormat('dd MMMM yyyy', 'id_ID').format(metadata.date)}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                         Text('Jml. Pengantaran Aktual: ${metadata.deliveryCount}'),
                         FutureBuilder<String>(
                           future: _getUserName(metadata.lastSyncedByUid),
                           builder: (context, userNameSnapshot) {
                             if (userNameSnapshot.connectionState == ConnectionState.waiting) {
                               return const Text('Disinkronkan Oleh: Memuat...');
                             }
                             return Text('Disinkronkan Oleh: ${userNameSnapshot.data ?? 'Tidak diketahui'}');
                           },
                         ),
                      Text('Waktu Sinkronisasi: ${DateFormat('dd MMM yyyy, HH:mm:ss', 'id_ID').format(metadata.lastSyncedAt)}'),
                    ],
                  ),
                  isThreeLine: true, // Sesuaikan jika perlu
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Theme.of(context).primaryColor),
                        onPressed: () => _showEditMetadataDialog(metadata),
                        tooltip: 'Edit Metadata',
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red[700]),
                        onPressed: () => _deleteMetadata(metadata.id, metadata.date),
                        tooltip: 'Hapus Metadata',
                      ),
                    ],
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
