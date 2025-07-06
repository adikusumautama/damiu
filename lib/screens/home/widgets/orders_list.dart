// lib/screens/home/widgets/orders_list.dart

import 'package:flutter/material.dart';
import 'package:damiu/models/order_model.dart';
import 'package:damiu/services/firestore_service.dart';


class OrdersStreamWidget extends StatelessWidget {
  const OrdersStreamWidget({
    super.key,
    required this.onStartDelivery,
    required this.onCompleteDelivery,
  });

  final Function(Order) onStartDelivery;
  final Function(Order) onCompleteDelivery;

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();
    return StreamBuilder<List<Order>>(
      stream: firestoreService.getTodaysOrdersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
              child:
                  Text('Belum ada pesanan untuk hari ini.', style: TextStyle(fontSize: 16, color: Colors.grey)));
        }

        final orders = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80), // Padding untuk Floating Action Button
          itemCount: orders.length,
          itemBuilder: (ctx, index) {
            final order = orders[index];
            return OrderCard(
              order: order,
              onStartDelivery: () => onStartDelivery(order),
              onCompleteDelivery: () => onCompleteDelivery(order),
            );
          },
        );
      },
    );
  }
}

class OrdersLocalWidget extends StatelessWidget {
  const OrdersLocalWidget({
    super.key,
    required this.orders,
    required this.onStartDelivery,
    required this.onCompleteDelivery,
  });

  final List<Order> orders;
  final Function(Order) onStartDelivery;
  final Function(Order) onCompleteDelivery;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Center(
        child: Text(
          'Tidak ada data pesanan lokal.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80), // Padding untuk Floating Action Button
      itemCount: orders.length,
      itemBuilder: (ctx, index) {
        final order = orders[index];
        return OrderCard(
          order: order,
          onStartDelivery: () => onStartDelivery(order),
          onCompleteDelivery: () => onCompleteDelivery(order),
        );
      },
    );
  }
}