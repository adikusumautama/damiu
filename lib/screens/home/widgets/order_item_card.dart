// ======================================================================
// FILE: lib/screens/home/widgets/order_item_card.dart
// ======================================================================
// FOKUS: Menampilkan UI untuk satu item pesanan.

import 'package:damiu/models/order_model.dart';
import 'package:flutter/material.dart';

class OrderItemCard extends StatelessWidget {
  final Order order;
  final VoidCallback onStartDelivery;
  final VoidCallback onCompleteDelivery;
  final VoidCallback onCancelOrder;

  const OrderItemCard({
    super.key,
    required this.order,
    required this.onStartDelivery,
    required this.onCompleteDelivery,
    required this.onCancelOrder,
  });
  
  Color _getStatusColor(String status) {
    switch (status) {
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.inDelivery:
        return Colors.orange;
      case OrderStatus.pending:
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    order.customerName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    order.status,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: _getStatusColor(order.status),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const Divider(),
            _buildDetailRow(Icons.local_drink_outlined, '${order.gallonQuantity} Galon'),
            if (order.otherItems != null && order.otherItems!.isNotEmpty)
              _buildDetailRow(Icons.add_shopping_cart_outlined, order.otherItems!),
            if (order.address != null && order.address!.isNotEmpty)
              _buildDetailRow(Icons.location_on_outlined, order.address!),
            if (order.phoneNumber != null && order.phoneNumber!.isNotEmpty)
              _buildDetailRow(Icons.phone_outlined, order.phoneNumber!),
            const SizedBox(height: 8),
            _buildOrderActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderActionButtons() {
    switch (order.status) {
      case OrderStatus.pending:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.local_shipping_outlined, size: 18),
              label: const Text('Mulai Antar'),
              onPressed: onStartDelivery,
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Batalkan'),
              onPressed: onCancelOrder,
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            ),
          ],
        );
      case OrderStatus.inDelivery:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Selesaikan'),
              onPressed: onCompleteDelivery,
              style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
            ),
          ],
        );
      case OrderStatus.delivered:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 18),
            const SizedBox(width: 4),
            Text('Terkirim', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold)),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}