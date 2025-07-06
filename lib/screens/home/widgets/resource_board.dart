// lib/screens/home/widgets/resource_board.dart
import 'package:flutter/material.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:damiu/models/daily_stock_model.dart';
import 'package:damiu/screens/other/empty_gallon_input_screen.dart';
import 'package:damiu/screens/other/daily_sales_input_screen.dart';

class ResourceBoard extends StatelessWidget {
  final bool isOnline;
  final String? employeeUid;

  const ResourceBoard({super.key, required this.isOnline, this.employeeUid});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStockInfo(context, 'Galon Tersedia', Icons.local_drink, Colors.blue, (stock) => stock.currentStock),
                _buildStockInfo(context, 'Galon Kosong', Icons.hourglass_empty, Colors.orange, (stock) => stock.initialEmptyStock),
                _buildStockInfo(context, 'Total Terjual', Icons.point_of_sale, Colors.green, (stock) => stock.initialStock - stock.currentStock, isSale: true),
              ],
            ),
            const Divider(height: 20, thickness: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(context, 'Input Galon Kosong', Icons.add_shopping_cart, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmptyGallonInputScreen()))),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStockInfo(BuildContext context, String title, IconData icon, Color color, int Function(DailyStock) getValue, {bool isSale = false}) {
    return Column(
      children: [
        Icon(icon, size: 30, color: color),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        isOnline
          ? StreamBuilder<DailyStock?>(
              stream: FirestoreService().getDailyStockStream(DateTime.now()),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Text('0', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
                final stock = snapshot.data;
                return Text(stock == null ? '0' : getValue(stock).toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
              },
            )
          : Text("Offline", style: TextStyle(fontSize: 14, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, String title, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(title, style: const TextStyle(fontSize: 10)),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}