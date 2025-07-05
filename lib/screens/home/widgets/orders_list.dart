import 'package:flutter/material.dart';
import 'package:damiu/models/order_model.dart';
import 'order_item_card.dart';
import 'package:damiu/services/firestore_service.dart';

class OrdersStreamWidget extends StatefulWidget {
  final void Function(Order) onStartDelivery;
  final void Function(Order) onCompleteDelivery;
  OrdersStreamWidget({super.key, required this.onStartDelivery, required this.onCompleteDelivery});
  @override
  State<OrdersStreamWidget> createState() => _OrdersStreamWidgetState();
}

class _OrdersStreamWidgetState extends State<OrdersStreamWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  String _filterStatus = 'Semua';
  final List<String> _statusOptions = [
    'Semua',
    OrderStatus.pending,
    OrderStatus.inDelivery,
    OrderStatus.delivered,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Row(
            children: [
              const Text('Filter: '),
              DropdownButton<String>(
                value: _filterStatus,
                items: _statusOptions.map((status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status == 'Semua' ? 'Semua' : status),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _filterStatus = val);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Order>>(
            stream: _firestoreService.getOrdersStream(), // Ubah: tampilkan semua orders tanpa filter tanggal
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: \\${snapshot.error}'));
              }
              final orders = snapshot.data ?? [];
              // Filter status
              List<Order> filtered = _filterStatus == 'Semua'
                  ? orders
                  : orders.where((o) => o.status == _filterStatus).toList();
              // Urutkan: terbaru di atas
              filtered.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
              return filtered.isEmpty
                  ? const Center(child: Text('Tidak ada pesanan.'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final order = filtered[i];
                        return OrderItemCard(
                          order: order,
                          onStartDelivery: () => widget.onStartDelivery(order),
                          onCompleteDelivery: () => widget.onCompleteDelivery(order),
                          onCancelOrder: () {},
                        );
                      },
                    );
            },
          ),
        ),
      ],
    );
  }
}

class OrdersLocalWidget extends StatelessWidget {
  final List<Order> orders;
  final void Function(Order) onStartDelivery;
  final void Function(Order) onCompleteDelivery;
  const OrdersLocalWidget({super.key, required this.orders, required this.onStartDelivery, required this.onCompleteDelivery});
  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Tidak ada pesanan lokal hari ini.'),
          ],
        ),
      );
    }
    // Filter dan urutkan lokal (opsional: bisa tambahkan filter status juga jika mau)
    List<Order> sortedOrders = List.from(orders);
    sortedOrders.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
    return ListView.builder(
      itemCount: sortedOrders.length,
      itemBuilder: (context, i) {
        final order = sortedOrders[i];
        return OrderItemCard(
          order: order,
          onStartDelivery: () => onStartDelivery(order),
          onCompleteDelivery: () => onCompleteDelivery(order),
          onCancelOrder: () {},
        );
      },
    );
  }
}
