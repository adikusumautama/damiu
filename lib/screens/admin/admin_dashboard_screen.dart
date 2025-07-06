// lib/screens/admin/admin_dashboard_screen.dart

import 'package:damiu/models/daily_stock_model.dart';
import 'package:damiu/models/order_model.dart';
import 'package:damiu/models/prediction_result_model.dart'; // <-- Tambahkan impor ini
import 'package:damiu/screens/home/widgets/set_stock_dialog.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:damiu/services/prediction_service.dart';
import 'package:damiu/screens/admin/admin_prediction_view_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final PredictionService _predictionService = PredictionService();
  final AuthService _authService = AuthService();
  // --- PERBAIKAN: Menggunakan tipe data Future yang benar ---
  late Future<ApiPredictionResult> _predictionFuture;

  @override
  void initState() {
    super.initState();
    _loadPrediction();
  }

  void _loadPrediction() {
    setState(() {
      // --- PERBAIKAN: Memanggil nama fungsi yang benar ---
      _predictionFuture = _predictionService.getPredictionsFromApi();
    });
  }

  Future<void> _showSetInitialStockDialog() async {
    final User? currentUser = _authService.getCurrentUser();
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mendapatkan info admin.')),
        );
      }
      return;
    }

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => const SetStockDialog(),
    );

    if (result != null && mounted) {
      final stock = result['stock'] ?? 0;
      final error = await _firestoreService.setInitialStock(
        date: DateTime.now(),
        filledStock: stock,
        updatedByUid: currentUser.uid,
      );

      if (mounted) {
        if (error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Stok awal berhasil diperbarui!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memperbarui stok: $error'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<dynamic>>(
      stream: CombineLatestStream.list([
        _firestoreService.getTodaysOrdersStream(), // PERUBAHAN: Mengambil data pesanan hari ini saja untuk ringkasan
        _firestoreService.getDailyStockStream(DateTime.now()),
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

        final int totalOrdersToday = orders.length;
        final int deliveredOrdersCount = orders.where((o) => o.status == OrderStatus.delivered).length;
        final int pendingOrdersCount = orders.where((o) => o.status == OrderStatus.pending).length;
        final int inDeliveryOrdersCount = orders.where((o) => o.status == OrderStatus.inDelivery).length;

        final int currentStock = stock?.currentStock ?? 0;
        final int initialStock = stock?.initialStock ?? 0;

        return RefreshIndicator(
          onRefresh: () async {
            _loadPrediction();
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSummarySection(totalOrdersToday, deliveredOrdersCount),
                const SizedBox(height: 20),
                _buildPredictionCard(),
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

  // --- WIDGET PREDIKSI YANG SUDAH DISESUAIKAN DENGAN MODEL DATA BARU ---
  Widget _buildPredictionCard() {
    return Card(
      elevation: 4,
      color: Colors.indigo[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<ApiPredictionResult>(
          future: _predictionFuture,
          builder: (context, snapshot) {
            Widget content;
            if (snapshot.connectionState == ConnectionState.waiting) {
              content = const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              content = Center(child: Text('Gagal memuat prediksi: ${snapshot.error}'));
            } else if (!snapshot.hasData || !snapshot.data!.success) {
              content = Center(child: Text(snapshot.data?.errorMessage ?? 'Data prediksi tidak tersedia.'));
            } else {
              // Jika sukses, tampilkan data prediksi
              final predictionValue = snapshot.data!.predictionForNextDay?.predictedQuantity ?? 'N/A';
              content = _buildInfoRow(Icons.online_prediction_outlined, 'Prediksi Penjualan Besok', '${predictionValue.toString()} Galon');
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fitur Unggulan ✨', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                const SizedBox(height: 10),
                content, // Tampilkan konten (loading, error, atau data)
                const SizedBox(height: 10),
                // Align(
                //   alignment: Alignment.centerRight,
                //   child: TextButton.icon(
                //     icon: const Text('Lihat Grafik Detail'),
                //     label: const Icon(Icons.arrow_forward_ios, size: 14),
                //     onPressed: () {
                //       Navigator.push(
                //         context,
                //         MaterialPageRoute(builder: (context) => const AdminPredictionViewScreen()),
                //       );
                //     },
                //   ),
                // ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummarySection(int totalOrders, int deliveredOrders) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Informasi Stok', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.edit_note_outlined),
                  onPressed: _showSetInitialStockDialog,
                  tooltip: 'Ubah Stok Awal Hari Ini',
                )
              ],
            ),
            const Divider(height: 15, thickness: 1),
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