import 'package:damiu/models/order_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onStartDelivery;
  final VoidCallback onCompleteDelivery;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const OrderCard({
    super.key,
    required this.order,
    required this.onStartDelivery,
    required this.onCompleteDelivery,
    required this.onEdit,
    required this.onDelete,
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
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (order.status != OrderStatus.delivered)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Ubah Pesanan'),
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline, color: Colors.red),
                          title: Text('Hapus Pesanan',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const Divider(height: 20),
            Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 16, height: 1.5),
                children: [
                  const TextSpan(
                      text: 'Jumlah: ',
                      style: TextStyle(fontWeight: FontWeight.bold)),
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
                      const TextSpan(
                          text: 'Alamat: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
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
                      const TextSpan(
                          text: 'Telepon: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: order.phoneNumber),
                    ],
                  ),
                ),
              ),
            if (order.otherItems != null && order.otherItems!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 16, height: 1.5),
                    children: [
                      const TextSpan(
                          text: 'Item Lain: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: order.otherItems),
                    ],
                  ),
                ),
              ),
            if (order.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(
                  'Dibuat: ${DateFormat('EEEE, dd MMM yyyy - HH:mm', 'id_ID').format(order.createdAt!)}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic),
                ),
              ),
            if (order.deliveredAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Selesai: ${DateFormat('EEEE, dd MMM yyyy - HH:mm', 'id_ID').format(order.deliveredAt!)}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade800,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusChip(order.status),
                _buildActionButtons(),
              ],
            ),
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
      labelStyle:
          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
          ElevatedButton(
            onPressed: onStartDelivery,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Mulai Antar'),
          ),
        if (order.status == OrderStatus.inDelivery)
          ElevatedButton(
            onPressed: onCompleteDelivery,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Selesaikan'),
          ),
      ],
    );
  }
}
