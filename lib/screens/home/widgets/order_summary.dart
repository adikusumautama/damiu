import 'package:flutter/material.dart';
import 'package:damiu/models/order_model.dart';

class OrderSummary extends StatelessWidget {
  final List<Order> orders;
  final bool isOnline;
  final DateTime? date;
  const OrderSummary({required this.orders, required this.isOnline, this.date, super.key});

  @override
  Widget build(BuildContext context) {
    final total = orders.length;
    final delivered = orders.where((o) => o.status == OrderStatus.delivered).length;
    final inDelivery = orders.where((o) => o.status == OrderStatus.inDelivery).length;
    final pending = orders.where((o) => o.status == OrderStatus.pending).length;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStat('Total Pesanan', total, Icons.list_alt),
            _buildStat('Belum Diantar', pending, Icons.pending_actions),
            _buildStat('Sedang Antar', inDelivery, Icons.local_shipping),
            _buildStat('Terkirim', delivered, Icons.check_circle),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, int value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 28, color: Colors.blueGrey),
        const SizedBox(height: 4),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
