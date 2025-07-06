// lib/screens/admin/admin_order_management_screen.dart

import 'package:damiu/models/order_model.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:damiu/screens/home/widgets/order_card.dart';
import 'package:damiu/screens/home/widgets/add_order_dialog.dart';
import 'package:flutter/material.dart';

class AdminOrderManagementScreen extends StatefulWidget {
  const AdminOrderManagementScreen({super.key});

  @override
  State<AdminOrderManagementScreen> createState() => _AdminOrderManagementScreenState();
}

class _AdminOrderManagementScreenState extends State<AdminOrderManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  void _showEditOrderDialog(Order orderToEdit) {
    showDialog(
      context: context,
      builder: (ctx) => AddOrderDialog(
        orderToEdit: orderToEdit,
        onSubmit: ({
          required String customerName,
          required int gallonQuantity,
          String? otherItems,
          String? address,
          String? phoneNumber,
          required DateTime date,
        }) async {
          final updatedOrder = Order(
            firestoreId: orderToEdit.firestoreId,
            customerName: customerName,
            gallonQuantity: gallonQuantity,
            otherItems: otherItems,
            address: address,
            phoneNumber: phoneNumber,
            status: orderToEdit.status,
            createdAt: orderToEdit.createdAt,
            employeeUid: orderToEdit.employeeUid,
          );
          final error = await _firestoreService.updateOrder(orderToEdit.firestoreId!, updatedOrder);
          if (mounted) _handleApiResponse(error, 'Pesanan berhasil diperbarui!');
        },
      ),
    );
  }

  Future<void> _onStartDelivery(Order order) async {
    if (order.firestoreId == null) {
      _handleApiResponse('Pesanan tidak memiliki ID Firestore.', null);
      return;
    }
    // Buat salinan order dengan status baru
    final updatedOrder = Order(
      firestoreId: order.firestoreId,
      customerName: order.customerName,
      gallonQuantity: order.gallonQuantity,
      otherItems: order.otherItems,
      address: order.address,
      phoneNumber: order.phoneNumber,
      status: OrderStatus.inDelivery, // <-- Ubah status
      createdAt: order.createdAt,
      employeeUid: order.employeeUid,
      deliveredAt: order.deliveredAt, // Pertahankan waktu selesai yang mungkin sudah ada
    );
    final error = await _firestoreService.updateOrder(order.firestoreId!, updatedOrder);
    if (mounted) _handleApiResponse(error, 'Status pesanan diubah menjadi "Sedang Diantar".');
  }

  Future<void> _onCompleteDelivery(Order order) async {
    if (order.firestoreId == null) {
      _handleApiResponse('Pesanan tidak memiliki ID Firestore.', null);
      return;
    }
    final updatedOrder = Order(
      firestoreId: order.firestoreId,
      customerName: order.customerName,
      gallonQuantity: order.gallonQuantity,
      otherItems: order.otherItems,
      address: order.address,
      phoneNumber: order.phoneNumber,
      status: OrderStatus.delivered, // <-- Ubah status
      createdAt: order.createdAt,
      deliveredAt: DateTime.now(), // <-- Atur waktu selesai
      employeeUid: order.employeeUid,
    );
    final error = await _firestoreService.updateOrder(order.firestoreId!, updatedOrder);
    if (mounted) _handleApiResponse(error, 'Pesanan ditandai sebagai "Selesai".');
  }

  void _showDeleteConfirmDialog(Order order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text('Anda yakin ingin menghapus pesanan untuk "${order.customerName}"?'),
        actions: [
          TextButton(
            child: const Text('Batal'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (order.firestoreId != null) {
                final error = await _firestoreService.deleteOrder(order.firestoreId!);
                if (mounted) _handleApiResponse(error, 'Pesanan berhasil dihapus.');
              }
            },
          ),
        ],
      ),
    );
  }

  void _handleApiResponse(String? error, String? successMessage) {
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
      );
    } else if (successMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Order>>(
        stream: _firestoreService.getOrdersStream(), // Mengambil semua pesanan
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Tidak ada data pesanan di Firestore.'));
          }

          final orders = snapshot.data!;
          // Urutkan dari yang terbaru ke terlama
          orders.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return OrderCard(
                order: order,
                onEdit: () => _showEditOrderDialog(order),
                onDelete: () => _showDeleteConfirmDialog(order),
                onStartDelivery: () => _onStartDelivery(order),
                onCompleteDelivery: () => _onCompleteDelivery(order),
              );
            },
          );
        },
      ),
    );
  }
}