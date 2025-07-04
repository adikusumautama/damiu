// lib/screens/admin/admin_dashboard_screen.dart

import 'package:damiu/models/daily_sale_model.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/models/daily_stock_model.dart';
import 'package:intl/intl.dart'; // Untuk format tanggal
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:damiu/models/order_model.dart';
import 'package:damiu/screens/home/widgets/add_order_dialog.dart';
import 'package:damiu/screens/home/widgets/order_summary.dart';

class BerandaAdminContent extends StatefulWidget {
  const BerandaAdminContent({super.key});

  @override
  State<BerandaAdminContent> createState() => _BerandaAdminContentState();
}

class _BerandaAdminContentState extends State<BerandaAdminContent> {
  final FirestoreService _firestoreService = FirestoreService();
  final DateTime _today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime? _customDateTime;
  DateTime get _activeDate => _customDateTime ?? _today;

  @override
  Widget build(BuildContext context) {
    final activeDate = _activeDate;
    return StreamBuilder<List<Order>>(
      stream: _firestoreService.getTodaysOrdersStream(date: activeDate),
      builder: (context, orderSnapshot) {
        if (orderSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (orderSnapshot.hasError) {
          return Center(child: Text('Error memuat pesanan: \\${orderSnapshot.error}'));
        }
        final orders = orderSnapshot.data ?? [];
        final totalGallon = orders.fold<int>(0, (sum, o) => sum + (o.gallonQuantity ?? 0));
        return StreamBuilder<List<DailySale>>(
          stream: _firestoreService.getDailySalesStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error memuat data: \\${snapshot.error}'));
            }
            final List<DailySale> allSalesData = snapshot.data ?? [];
            allSalesData.sort((a, b) => a.date.compareTo(b.date));
            final todaySales = allSalesData.where((sale) {
              return sale.date.year == activeDate.year &&
                  sale.date.month == activeDate.month &&
                  sale.date.day == activeDate.day;
            }).toList();
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Pilih tanggal manual ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(_customDateTime == null
                              ? 'Tanggal: Hari Ini'
                              : 'Tanggal: \\${activeDate.day}-\\${activeDate.month}-\\${activeDate.year}'),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: activeDate,
                              firstDate: DateTime(activeDate.year - 1),
                              lastDate: DateTime(activeDate.year + 2),
                            );
                            if (picked != null) {
                              setState(() => _customDateTime = picked);
                            }
                          },
                        ),
                        if (_customDateTime != null)
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Reset ke Hari Ini',
                            onPressed: () => setState(() => _customDateTime = null),
                          ),
                      ],
                    ),
                    // --- Statistik Pesanan ---
                    OrderSummary(orders: orders, isOnline: true),
                    const SizedBox(height: 8),
                    // --- Statistik Galon ---
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Total Galon Hari Ini', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('$totalGallon', style: const TextStyle(fontSize: 18)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // --- Tombol Catat Pesanan ---
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Catat Pesanan'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AddOrderDialog(
                              onSubmit: ({
                                required String customerName,
                                required int gallonQuantity,
                                String? otherItems,
                                String? address,
                                String? phoneNumber,
                              }) async {
                                final order = Order(
                                  customerName: customerName,
                                  gallonQuantity: gallonQuantity,
                                  otherItems: otherItems,
                                  address: address,
                                  phoneNumber: phoneNumber,
                                  status: OrderStatus.pending,
                                  createdAt: DateTime.now(),
                                  isSynced: true,
                                );
                                await _firestoreService.addOrder(order);
                                if (mounted) setState(() {});
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    // --- Daftar Pesanan Hari Ini ---
                    Text('Daftar Pesanan Hari Ini', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (orders.isEmpty)
                      const Text('Belum ada pesanan hari ini.')
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: orders.length,
                        itemBuilder: (context, i) {
                          final o = orders[i];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.local_drink),
                              title: Text(o.customerName ?? '-'),
                              subtitle: Text('Galon: \\${o.gallonQuantity ?? 0} | Status: \\${o.status ?? '-'}'),
                              trailing: Text(
                                o.createdAt != null ? DateFormat('HH:mm').format(o.createdAt!) : '-',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                    // --- Bagian Manajemen Stok ---
                    const Center(
                        child: Text('Manajemen Stok Hari Ini',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold))),
                    const SizedBox(height: 8),
                    StreamBuilder<DailyStock?>(
                      stream: _firestoreService.getDailyStockStream(activeDate),
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
