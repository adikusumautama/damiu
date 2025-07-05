// ======================================================================
// FILE: lib/screens/home/widgets/stock_info_card.dart
// ======================================================================
// FOKUS: Hanya menampilkan kartu informasi stok. Stateless dan menerima data.

import 'package:damiu/models/daily_stock_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StockInfoCard extends StatelessWidget {
  final DailyStock? stock;
  final int totalOut;
  final int totalIn;
  final int deliveryCount;
  final VoidCallback onEditPressed;

  const StockInfoCard({
    super.key,
    required this.stock,
    required this.totalOut,
    required this.totalIn,
    required this.deliveryCount,
    required this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    final initialStock = stock?.initialStock ?? 0;
    final currentStock = stock?.currentStock ?? 0;

    final Color stockColor;
    if (currentStock <= 0) {
      stockColor = Colors.red.shade800;
    } else if (currentStock <= 5) {
      stockColor = Colors.orange.shade800;
    } else {
      stockColor = Colors.green.shade800;
    }

    final lastUpdatedText = stock != null
        ? 'Diperbarui: ${DateFormat('dd MMM, HH:mm', 'id_ID').format(stock!.lastUpdated)}'
        : 'Belum diatur hari ini';

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
                Text('Pergerakan Stok Hari Ini', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEditPressed,
                  tooltip: 'Ubah Stok Awal',
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildInfoRow('Jumlah Pengantaran', '$deliveryCount kali'),
            const Divider(thickness: 0.5, height: 20),
            _buildInfoRow('Stok Awal (Hari Ini)', '$initialStock Galon'),
            _buildInfoRow('Keluar (Terjual)', '-$totalOut Galon', valueColor: Colors.red.shade700),
            _buildInfoRow('Kembali (Diterima)', '+$totalIn Galon', valueColor: Colors.blue.shade700),
            const Divider(thickness: 1, height: 24),
            _buildInfoRow('Total Persediaan Saat Ini', '$currentStock Galon', isBold: true, valueColor: stockColor),
            if (currentStock > 0 && currentStock <= 5)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Center(
                  child: Text(
                    'Stok galon sangat menipis!',
                    style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Text(lastUpdatedText, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, Color? valueColor}) {
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
}