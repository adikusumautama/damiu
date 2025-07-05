// ======================================================================
// FILE BARU: lib/screens/other/widgets/local_stock_view.dart
// ======================================================================
// FOKUS: Hanya menampilkan UI untuk tab "Data Stok Lokal".

import 'package:damiu/models/daily_stock_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LocalStockView extends StatelessWidget {
  final bool isLoading;
  final List<DailyStock> stockData;
  final Future<void> Function() onRefresh;
  final Function() onDeleteAll;
  final Function(String) onDeleteStock;
  final Function(DailyStock) onEditStock;
  final Future<String> Function(String?) getEmployeeName;

  const LocalStockView({
    super.key,
    required this.isLoading,
    required this.stockData,
    required this.onRefresh,
    required this.onDeleteAll,
    required this.onDeleteStock,
    required this.onEditStock,
    required this.getEmployeeName,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(8.0),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Data Stok Awal Lokal (daily_stock)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (isLoading)
                    const LinearProgressIndicator()
                  else
                    Text('Total Data Tersimpan: ${stockData.length} hari'),
                  const SizedBox(height: 10),
                  Center(
                    child: Tooltip(
                      message: 'Hapus semua data stok awal lokal',
                      child: TextButton.icon(
                        icon: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                        label: const Text('Hapus Semua Stok', style: TextStyle(color: Colors.red)),
                        onPressed: isLoading || stockData.isEmpty ? null : onDeleteAll,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : stockData.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            child: const Text('Tidak ada data stok tersimpan.'),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: stockData.length,
                        itemBuilder: (context, index) {
                          final stock = stockData[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: ListTile(
                              title: Text('Tanggal: ${DateFormat('EEEE, dd MMM magickwoods', 'id_ID').format(DateTime.parse(stock.id))}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Stok Isi: ${stock.initialStock} Galon'),
                                  Text('Stok Kosong: ${stock.initialEmptyStock} Galon'),
                                  FutureBuilder<String>(
                                    future: getEmployeeName(stock.updatedByUid),
                                    builder: (context, snapshot) {
                                      return Text('Diupdate oleh: ${snapshot.data ?? "Memuat..."}');
                                    },
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: Theme.of(context).primaryColor),
                                    onPressed: () => onEditStock(stock),
                                    tooltip: 'Edit Stok',
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red[700]),
                                    onPressed: () => onDeleteStock(stock.id),
                                    tooltip: 'Hapus Stok',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}