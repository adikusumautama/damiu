// lib/screens/admin/admin_dashboard_screen.dart

import 'package:damiu/models/daily_sale_model.dart';
import 'package:damiu/models/daily_stock_model.dart';
import 'package:damiu/models/order_model.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:damiu/services/prediction_service.dart'; // <-- Tambahkan impor ini
import 'package:damiu/screens/admin/admin_prediction_view_screen.dart'; // <-- Tambahkan impor ini
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
  final PredictionService _predictionService = PredictionService(); // <-- Tambahkan ini
  late Future<Map<String, dynamic>> _predictionFuture; // <-- Tambahkan ini

  @override
  void initState() {
    super.initState();
    _loadPrediction(); // <-- Panggil fungsi untuk memuat prediksi
  }

  void _loadPrediction() {
    setState(() {
      _predictionFuture = _predictionService.getPrediction();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<dynamic>>(
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

        final List<Order> orders = snapshot.data![0] as List<Order>;
        final DailyStock? stock = snapshot.data![1] as DailyStock?;
        final List<DailySale> sales = snapshot.data![2] as List<DailySale>;

        final int totalOrders = orders.length;
        final int deliveredOrdersCount = orders.where((o) => o.status == OrderStatus.delivered).length;
        final int pendingOrdersCount = orders.where((o) => o.status == OrderStatus.pending).length;
        final int inDeliveryOrdersCount = orders.where((o) => o.status == OrderStatus.inDelivery).length;

        final int currentStock = stock?.currentStock ?? 0;
        final int initialStock = stock?.initialStock ?? 0;

        final double totalRevenue = sales.fold(0, (sum, sale) => sum + (sale.quantity * 7000));

        return RefreshIndicator(
          onRefresh: () async {
            _loadPrediction();
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSummarySection(totalOrders, deliveredOrdersCount, totalRevenue),
                const SizedBox(height: 20),
                _buildPredictionCard(), // <-- PANGGIL KARTU PREDIKSI DI SINI
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

  // --- WIDGET BARU UNTUK KARTU PREDIKSI ---
  Widget _buildPredictionCard() {
    return Card(
      elevation: 4,
      color: Colors.indigo[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _predictionFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Gagal memuat prediksi: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('Data prediksi tidak tersedia.'));
            }

            // Ambil data prediksi untuk besok
            final tomorrow = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1)));
            final predictionValue = snapshot.data?['predictions']?[tomorrow] ?? 'N/A';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fitur Unggulan ✨', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                const SizedBox(height: 10),
                _buildInfoRow(Icons.online_prediction_outlined, 'Prediksi Penjualan Besok', '${predictionValue.toString()} Galon'),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Text('Lihat Grafik Detail'),
                    label: const Icon(Icons.arrow_forward_ios, size: 14),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AdminPredictionViewScreen()),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
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