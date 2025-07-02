// lib/screens/admin/admin_dashboard_screen.dart

import 'package:damiu/models/daily_sale_model.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/models/daily_stock_model.dart';
import 'package:intl/intl.dart'; // Untuk format tanggal
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BerandaAdminContent extends StatefulWidget {
  const BerandaAdminContent({super.key});

  @override
  State<BerandaAdminContent> createState() => _BerandaAdminContentState();
}

class _BerandaAdminContentState extends State<BerandaAdminContent> {
  final FirestoreService _firestoreService = FirestoreService();
  final DateTime _today =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DailySale>>(
      stream: _firestoreService.getDailySalesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error memuat data: ${snapshot.error}'));
        }

        final List<DailySale> allSalesData = snapshot.data ?? [];
        allSalesData.sort((a, b) => a.date.compareTo(b.date));

        final todaySales = allSalesData.where((sale) {
          return sale.date.year == _today.year &&
              sale.date.month == _today.month &&
              sale.date.day == _today.day;
        }).toList();

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bagian Manajemen Stok
                const Center(
                    child: Text('Manajemen Stok Hari Ini',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold))),
                const SizedBox(height: 8),
                StreamBuilder<DailyStock?>(
                  stream: _firestoreService.getDailyStockStream(_today),
                  builder: (context, stockSnapshot) {
                    if (stockSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final dailyStock = stockSnapshot.data;
                    return _buildStockInfoCard(dailyStock, todaySales);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStockInfoCard(DailyStock? stock, List<DailySale> sales) {
    // Data untuk Galon Isi
    final initialFilledStock = stock?.initialStock ?? 0;
    final totalSold = sales.fold<int>(0, (sum, item) => sum + item.quantity);
    final remainingFilledStock = initialFilledStock - totalSold;

    // Data untuk Galon Kosong
    final initialEmptyStock = stock?.initialEmptyStock ?? 0;
    // Admin hanya melihat stok awal kosong, bukan pergerakan harian dari log lokal
    final currentEmptyStock = initialEmptyStock;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Stok Hari Ini (Online)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showSetInitialStockDialog(
                    initialFilledStock,
                    initialEmptyStock,
                  ),
                  tooltip: 'Ubah Stok Awal',
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            // --- Bagian Galon Isi ---
            Text('Galon Isi',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            _buildInfoRow('Stok Awal', '$initialFilledStock Galon'),
            _buildInfoRow('Terjual (dari data sinkron)', '$totalSold Galon',
                valueColor: Colors.red.shade700),
            const Divider(thickness: 1, height: 24),
            _buildInfoRow('Sisa Stok Isi', '$remainingFilledStock Galon',
                isBold: true, valueColor: Colors.green.shade800),

            const SizedBox(height: 24),

            // --- Bagian Galon Kosong ---
            Text('Galon Kosong',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            _buildInfoRow('Stok Awal Dibawa', '$initialEmptyStock Galon'),
            _buildInfoRow('Kembali (Diterima)', 'Data dari Karyawan',
                valueColor: Colors.grey),
            const Divider(thickness: 1, height: 24),
            _buildInfoRow('Stok Kosong Saat Ini', '$currentEmptyStock Galon',
                isBold: true, valueColor: Colors.black87),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSetInitialStockDialog(
      int currentFilledStock, int currentEmptyStock) async {
    final TextEditingController filledStockController = TextEditingController(
        text: currentFilledStock > 0 ? currentFilledStock.toString() : '');
    final TextEditingController emptyStockController = TextEditingController(
        text: currentEmptyStock > 0 ? currentEmptyStock.toString() : '');
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Atur Stok Awal Hari Ini'),
          content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: filledStockController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah Stok Galon Isi',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Stok tidak boleh kosong';
                      }
                      if (int.tryParse(value) == null ||
                          int.parse(value) < 0) {
                        return 'Masukkan angka valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emptyStockController,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah Galon Kosong Dibawa (Opsional)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ],
              )),
          actions: <Widget>[
            TextButton(
                child: const Text('Batal'),
                onPressed: () => Navigator.of(context).pop()),
            TextButton(
              child: const Text('Simpan'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final int filledStock =
                      int.parse(filledStockController.text);
                  final int emptyStock =
                      int.tryParse(emptyStockController.text) ?? 0;
                  final String? uid =
                      AuthService().getCurrentUser()?.uid; // Admin's UID
                  if (uid != null) {
                    await _firestoreService.setInitialStock(
                        date: _today,
                        filledStock: filledStock,
                        emptyStock: emptyStock,
                        updatedByUid: uid);
                    if (mounted) Navigator.of(context).pop();
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}
