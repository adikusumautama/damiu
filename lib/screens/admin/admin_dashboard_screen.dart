// lib/screens/admin/admin_dashboard_screen.dart

import 'package:damiu/models/daily_sale_model.dart';
import 'package:damiu/models/daily_stock_model.dart';
import 'package:damiu/models/order_model.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<dynamic>>(
      // --- PERBAIKAN: Menggabungkan semua stream yang dibutuhkan oleh dashboard ---
      stream: CombineLatestStream.list([
        _firestoreService.getOrdersStream(),
        _firestoreService.getDailyStockStream(DateTime.now()),
        _firestoreService.getDailySalesStream(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Tidak ada data untuk ditampilkan.'));
        }

        // --- PERBAIKAN: Mengekstrak dan mengonversi data dengan aman ---
        final List<Order> orders = snapshot.data![0] as List<Order>;
        final DailyStock? stock = snapshot.data![1] as DailyStock?;
        final List<DailySale> sales = snapshot.data![2] as List<DailySale>;

        final int totalOrders = orders.length;
        final int deliveredOrdersCount = orders.where((o) => o.status == OrderStatus.delivered).length;
        final int pendingOrdersCount = orders.where((o) => o.status == OrderStatus.pending).length;
        final int inDeliveryOrdersCount = orders.where((o) => o.status == OrderStatus.inDelivery).length;

        final int currentStock = stock?.currentStock ?? 0;
        final int initialStock = stock?.initialStock ?? 0;

        final double totalRevenue = sales.fold(0, (sum, sale) => sum + (sale.quantity * 7000)); // Asumsi harga per galon

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSummarySection(totalOrders, deliveredOrdersCount, totalRevenue),
                const SizedBox(height: 20),
                _buildStockSection(currentStock, initialStock),
                const SizedBox(height: 20),
                _buildOrderStatusSection(pendingOrdersCount, inDeliveryOrdersCount),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummarySection(int totalOrders, int deliveredOrders, double totalRevenue) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ringkasan Hari Ini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildInfoRow(Icons.shopping_cart_outlined, 'Total Pesanan', '$totalOrders'),
            _buildInfoRow(Icons.check_circle_outline, 'Pesanan Selesai', '$deliveredOrders'),
            _buildInfoRow(Icons.attach_money, 'Total Pendapatan', NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(totalRevenue)),
          ],
        ),
      ),
    );
  }

  Widget _buildStockSection(int currentStock, int initialStock) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informasi Stok', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildInfoRow(Icons.inventory_2_outlined, 'Stok Awal', '$initialStock Galon'),
            _buildInfoRow(Icons.inventory, 'Sisa Stok', '$currentStock Galon'),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatusSection(int pendingOrders, int inDeliveryOrders) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Status Pesanan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildInfoRow(Icons.pending_actions_outlined, 'Menunggu Diantar', '$pendingOrders Pesanan'),
            _buildInfoRow(Icons.delivery_dining_outlined, 'Sedang Diantar', '$inDeliveryOrders Pesanan'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 15),
          Text(label, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}