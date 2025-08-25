
import 'package:damiu/models/daily_stock_model.dart';
import 'package:damiu/models/order_model.dart';
import 'package:damiu/screens/admin/widgets/dashboard_summary_card.dart';
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
  late Future<ApiPredictionResult> _predictionFuture;

  @override
  void initState() {
    super.initState();
    _loadPrediction();
  }

  void _loadPrediction() {
    setState(() {
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
        final int emptyStock = stock?.initialEmptyStock ?? 0;
        final int soldStock = stock?.totalSold ?? 0;

        final List<Map<String, dynamic>> summaryData = [
          {'title': 'Total Pesanan', 'value': '$totalOrdersToday', 'icon': Icons.shopping_cart_outlined, 'color': Colors.blue},
          {'title': 'Sudah Diantar', 'value': '$deliveredOrdersCount', 'icon': Icons.check_circle_outline, 'color': Colors.green},
          {'title': 'Belum Diantar', 'value': '$pendingOrdersCount', 'icon': Icons.pending_actions_outlined, 'color': Colors.orange},
          {'title': 'Sedang Diantar', 'value': '$inDeliveryOrdersCount', 'icon': Icons.delivery_dining_outlined, 'color': Colors.purple},
          {'title': 'Galon Tersedia', 'value': '$currentStock', 'icon': Icons.inventory, 'color': Colors.teal},
          {'title': 'Terjual Hari Ini', 'value': '$soldStock', 'icon': Icons.point_of_sale, 'color': Colors.pink},
          {'title': 'Galon Kembali', 'value': '$emptyStock', 'icon': Icons.hourglass_empty_outlined, 'color': Colors.orange},
        ];

        return RefreshIndicator(
          onRefresh: () async {
            _loadPrediction();
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Ringkasan Hari Ini', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.edit_note_outlined, color: Colors.blueAccent),
                      onPressed: _showSetInitialStockDialog,
                      tooltip: 'Ubah Stok Awal Hari Ini',
                    )
                  ],
                ),
                

                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: summaryData.length,
                  itemBuilder: (context, index) {
                    final data = summaryData[index];
                    return DashboardSummaryCard(
                      title: data['title'],
                      value: data['value'],
                      icon: data['icon'],
                      color: data['color'],
                    );
                  },
                ),
                
              ],
            ),
          ),
        );
      },
    );
  }

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
              final predictionValue = snapshot.data!.predictionForNextDay?.predictedQuantity ?? 'N/A';
              content = Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.online_prediction_outlined, color: Colors.indigo),
                    const SizedBox(width: 15),
                    const Text('Prediksi Penjualan Besok', style: TextStyle(fontSize: 16)),
                    const Spacer(),
                    Text('${predictionValue.toString()} Galon', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Informasi Prediksi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                const SizedBox(height: 10),
                content, 
                const SizedBox(height: 10),
              ],
            );
          },
        ),
      ),
    );
  }

}