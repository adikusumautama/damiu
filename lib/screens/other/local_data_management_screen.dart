// lib/screens/other/local_data_management_screen.dart
import 'package:damiu/services/database_helper.dart';
import 'package:damiu/services/sync_service.dart';
import 'package:flutter/material.dart';

class LocalDataManagementScreen extends StatefulWidget {
  const LocalDataManagementScreen({super.key});

  @override
  State<LocalDataManagementScreen> createState() =>
      _LocalDataManagementScreenState();
}

class _LocalDataManagementScreenState extends State<LocalDataManagementScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SyncService _syncService = SyncService();

  bool _isSyncing = false;
  int _unsyncedOrders = 0;
  int _unsyncedCustomers = 0;

  @override
  void initState() {
    super.initState();
    _loadUnsyncedCounts();
  }

  Future<void> _loadUnsyncedCounts() async {
    final orders = await _dbHelper.getUnsyncedOrders();
    final customers = await _dbHelper.getUnsyncedCustomers();
    if (mounted) {
      setState(() {
        _unsyncedOrders = orders.length;
        _unsyncedCustomers = customers.length;
      });
    }
  }

  Future<void> _manualSync() async {
    setState(() => _isSyncing = true);
    try {
      await _syncService.syncAllData();
      await _loadUnsyncedCounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sinkronisasi selesai!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal sinkronisasi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _clearLocalData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text(
            'Anda yakin ingin menghapus semua data lokal (pesanan, pelanggan) yang belum sinkron? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.clearAllLocalData();
      await _loadUnsyncedCounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data lokal berhasil dibersihkan.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Data Lokal'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadUnsyncedCounts,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSyncCard(),
            const SizedBox(height: 20),
            _buildDangerZoneCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status Sinkronisasi',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
                'Data yang dibuat saat mode offline akan disimpan di sini sebelum dikirim ke server.'),
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Pesanan belum sinkron'),
              trailing: Text('',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_outlined),
              title: const Text('Pelanggan baru belum sinkron'),
              trailing: Text('',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isSyncing
                    ? Container(
                        width: 24,
                        height: 24,
                        padding: const EdgeInsets.all(2.0),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Icon(Icons.sync),
                label: Text(_isSyncing ? 'Menyinkronkan...' : 'Sinkronisasi Manual'),
                onPressed: _isSyncing ? null : _manualSync,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZoneCard() {
    return Card(
      elevation: 2,
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Zona Berbahaya',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Colors.red.shade700)),
            const SizedBox(height: 8),
            const Text(
                'Gunakan fitur ini hanya jika Anda mengalami masalah data yang tidak konsisten.'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Hapus Semua Data Lokal'),
                onPressed: _clearLocalData,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
