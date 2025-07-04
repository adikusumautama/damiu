// ======================================================================
// FILE: lib/screens/home/widgets/order_list_view.dart
// ======================================================================
// FOKUS: Menampilkan daftar pesanan dalam sebuah ListView.

import 'package:damiu/models/order_model.dart';
import 'package:damiu/screens/home/widgets/order_item_card.dart';
import 'package:flutter/material.dart';

class OrderListView extends StatelessWidget {
  final List<Order> orders;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final Function(Order) onStartDelivery;
  final Function(Order) onCompleteDelivery;
  final Function(Order) onCancelOrder;

  const OrderListView({
    super.key,
    required this.orders,
    required this.emptyMessage,
    required this.onRefresh,
    required this.onStartDelivery,
    required this.onCompleteDelivery,
    required this.onCancelOrder,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(emptyMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                  ),
                ),
              ),
            );
          }
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return OrderItemCard(
            order: order,
            onStartDelivery: () => onStartDelivery(order),
            onCompleteDelivery: () => onCompleteDelivery(order),
            onCancelOrder: () => onCancelOrder(order),
          );
        },
      ),
    );
  }
}
