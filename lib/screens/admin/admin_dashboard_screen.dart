// lib/screens/admin/admin_dashboard_screen.dart

import 'package:damiu/models/daily_sale_model.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/models/daily_stock_model.dart';
import 'package:intl/intl.dart'; // Untuk format tanggal
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:damiu/models/order_model.dart' show Order, OrderStatus;
import 'package:damiu/screens/admin/widgets/summary_card.dart';

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
    return RefreshIndicator(
      onRefresh: () async {
        // Memicu refresh data dengan setState
        setState(() {});
      },
      child: StreamBuilder<List<Order>>(
        stream: _firestoreService.getTodaysOrdersStream(date: activeDate),
        builder: (context, orderSnapshot) {
          if (orderSnapshot.connectionState == ConnectionState.waiting && !orderSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (orderSnapshot.hasError) {
            return Center(child: Text('Error memuat pesanan: \\${orderSnapshot.error}'));
          }
          final orders = orderSnapshot.data ?? [];
          final totalGallon = orders.fold<int>(0, (sum, o) => sum + (o.gallonQuantity ?? 0));
          final deliveredOrders = orders.where((o) => o.status == OrderStatus.delivered).length;
          final pendingOrders = orders.where((o) => o.status == OrderStatus.pending).length;
          final inDeliveryOrders = orders.where((o) => o.status == OrderStatus.inDelivery).length;

          return StreamBuilder<DailySale?>(
            stream: _firestoreService.getDailySaleStreamByDate(activeDate),
            builder: (context, saleSnapshot) {
              final todaySales = saleSnapshot.data;
              return StreamBuilder<DailyStock?>(
                stream: _firestoreService.getDailyStockStream(activeDate),
                builder: (context, stockSnapshot) {
                  final dailyStock = stockSnapshot.data;
                  return ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      _buildDatePicker(),
                      const SizedBox(height: 16),
                      _buildSummaryGrid(orders, todaySales, dailyStock),
                      const SizedBox(height: 24),
                      _buildStockInfoCard(dailyStock, todaySales),
                      const SizedBox(height: 24),
                      Text('Daftar Pesanan Hari Ini', style: Theme.of(context).textTheme.titleLarge),
                      const Divider(height: 24),
                      _buildOrdersList(orders),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDatePicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          icon: const Icon(Icons.calendar_today),
          label: Text(_customDateTime == null
              ? 'Hari Ini'
              : DateFormat('dd MMM yyyy').format(_activeDate)),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _activeDate,
              firstDate: DateTime(_activeDate.year - 1),
              lastDate: DateTime(_activeDate.year + 2),
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
    );
  }

  Widget _buildSummaryGrid(List<Order> orders, DailySale? sales, DailyStock? stock) {
    final totalGallon = orders.fold<int>(0, (sum, o) => sum + (o.gallonQuantity ?? 0));
    final deliveredOrders = orders.where((o) => o.status == OrderStatus.delivered).length;
    final pendingOrders = orders.where((o) => o.status == OrderStatus.pending).length;
    final inDeliveryOrders = orders.where((o) => o.status == OrderStatus.inDelivery).length;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        SummaryCard(title: 'Total Pesanan', value: '${orders.length}', icon: Icons.shopping_cart_outlined, color: Colors.blue),
        SummaryCard(title: 'Galon Terjual', value: '${sales?.quantity ?? 0}', icon: Icons.local_drink_outlined, color: Colors.green),
        SummaryCard(title: 'Sisa Stok Isi', value: '${stock?.currentStock ?? 0}', icon: Icons.inventory_2_outlined, color: Colors.orange),
        SummaryCard(title: 'Stok Kosong', value: '${stock?.initialEmptyStock ?? 0}', icon: Icons.replay_circle_filled_outlined, color: Colors.grey),
        SummaryCard(title: 'Belum Diantar', value: '$pendingOrders', icon: Icons.pending_actions_outlined, color: Colors.red),
        SummaryCard(title: 'Sudah Diantar', value: '$deliveredOrders', icon: Icons.check_circle_outline, color: Colors.teal),
      ],
    );
  }

  Widget _buildOrdersList(List<Order> orders) {
    if (orders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48.0),
          child: Text('Belum ada pesanan untuk tanggal ini.'),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: orders.length,
      itemBuilder: (context, i) {
        final o = orders[i];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(child: Icon(o.status == OrderStatus.delivered ? Icons.check : Icons.local_shipping_outlined)),
            title: Text(o.customerName ?? '-'),
            subtitle: Text('Galon: ${o.gallonQuantity ?? 0} | Status: ${o.status ?? '-'}'),
            trailing: Text(
              o.createdAt != null ? DateFormat('HH:mm').format(o.createdAt!) : '-',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStockInfoCard(DailyStock? stock, DailySale? sales) {
    // Data untuk Galon Isi
    final initialFilledStock = stock?.initialStock ?? 0;
    final totalSold = sales?.quantity ?? 0;
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
