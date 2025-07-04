import 'package:flutter/material.dart';
import 'package:damiu/models/order_model.dart';
import 'order_item_card.dart';
import 'package:damiu/services/firestore_service.dart';

class OrdersStreamWidget extends StatelessWidget {
  final void Function(Order) onStartDelivery;
  final void Function(Order) onCompleteDelivery;
  OrdersStreamWidget({super.key, required this.onStartDelivery, required this.onCompleteDelivery});
  final FirestoreService _firestoreService = FirestoreService();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Order>>(
      stream: _firestoreService.getTodaysOrdersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return const Center(child: Text('Tidak ada pesanan hari ini.'));
        }
        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, i) {
            final order = orders[i];
            return OrderItemCard(
              order: order,
              onStartDelivery: () => onStartDelivery(order),
              onCompleteDelivery: () => onCompleteDelivery(order),
              onCancelOrder: () {},
            );
          },
        );
      },
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
      return const Center(child: Text('Tidak ada pesanan lokal hari ini.'));
    }
    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, i) {
        final order = orders[i];
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
