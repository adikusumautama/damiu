// lib/screens/home/widgets/order_card.dart

import 'package:damiu/models/order_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onStartDelivery;
  final VoidCallback onCompleteDelivery;

  const OrderCard({
    super.key,
    required this.order,
    required this.onStartDelivery,
    required this.onCompleteDelivery,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.customerName ?? 'Tanpa Nama',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  DateFormat('HH:mm').format(order.createdAt ?? DateTime.now()),
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
            const Divider(height: 20),
            Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 16, height: 1.5),
                children: [
                  const TextSpan(text: 'Jumlah: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: '${order.gallonQuantity ?? 0} Galon'),
                ],
              ),
            ),
            if (order.address != null && order.address!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 16, height: 1.5),
                    children: [
                      const TextSpan(text: 'Alamat: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: order.address),
                    ],
                  ),
                ),
              ),
            if (order.phoneNumber != null && order.phoneNumber!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 16, height: 1.5),
                    children: [
                      const TextSpan(text: 'Telepon: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: order.phoneNumber),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _buildStatusChip(order.status),
            if (order.status == OrderStatus.pending || order.status == OrderStatus.inDelivery)
              const SizedBox(height: 10),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    Color chipColor;
    IconData chipIcon;
    switch (status) {
      case OrderStatus.delivered:
        chipColor = Colors.green;
        chipIcon = Icons.check_circle;
        break;
      case OrderStatus.inDelivery:
        chipColor = Colors.orange;
        chipIcon = Icons.delivery_dining;
        break;
      case OrderStatus.pending:
      default:
        chipColor = Colors.blue;
        chipIcon = Icons.pending_actions;
        break;
    }
    return Chip(
      avatar: Icon(chipIcon, color: Colors.white, size: 18),
      label: Text(status ?? 'Status Tidak Diketahui'),
      backgroundColor: chipColor,
      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildActionButtons() {
    if (order.status == OrderStatus.delivered) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (order.status == OrderStatus.pending)
          ElevatedButton.icon(
            icon: const Icon(Icons.delivery_dining_outlined, size: 18),
            label: const Text('Mulai Antar'),
            onPressed: onStartDelivery,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        if (order.status == OrderStatus.inDelivery)
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Selesaikan'),
            onPressed: onCompleteDelivery,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }
}