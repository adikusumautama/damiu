// lib/screens/other/daily_sales_input_screen.dart
// This screen is now repurposed to handle the delivery process based on recorded orders.

import 'package:damiu/models/order_model.dart';
import 'package:flutter/material.dart';
import 'package:damiu/models/delivery_log_model.dart';
import 'package:damiu/services/database_helper.dart';
import 'package:damiu/services/auth_service.dart';

class DailySalesInputScreen extends StatefulWidget {
  const DailySalesInputScreen({super.key});

  @override
  State<DailySalesInputScreen> createState() => _DeliveryProcessScreenState();
}

class _DeliveryProcessScreenState extends State<DailySalesInputScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AuthService _authService = AuthService();
  List<Order> _pendingOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingOrders();
  }

  Future<void> _loadPendingOrders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    final allOrders = await _dbHelper.getTodaysOrders();
    // Filter for orders that are 'Belum Diantar'
    final pending =
        allOrders.where((order) => order.status == OrderStatus.pending).toList();
    if (mounted) {
      setState(() {
        _pendingOrders = pending;
        _isLoading = false;
      });
    }
  }

  Future<void> _processDelivery(Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Pengantaran'),
        content: Text('Antar pesanan untuk ${order.customerName}? Stok galon akan dikurangi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Antar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    final String? employeeUid = _authService.getCurrentUser()?.uid;
    if (employeeUid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Pengguna tidak login.')),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    // 1. Create a delivery log to track stock movement
    final deliveryLog = DeliveryLogItem(
      timestamp: DateTime.now(),
      gallons: order.gallonQuantity,
      emptyGallonsReturned: 0, // This is handled by a separate flow
      employeeUid: employeeUid,
      isSummarized: false,
    );
    await _dbHelper.insertDeliveryLog(deliveryLog);

    // 2. Update the order status to 'In Delivery'
    await _dbHelper.updateOrderStatus(order.id!, OrderStatus.inDelivery);

    // 3. Provide feedback and refresh the UI
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Pesanan untuk ${order.customerName} sedang diantar.')),
      );
      _loadPendingOrders(); // This will refresh the list and remove the processed order
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Pesanan untuk Diantar'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingOrders.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'Tidak ada pesanan yang perlu diantar saat ini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPendingOrders,
                  child: ListView.builder(
                    itemCount: _pendingOrders.length,
                    itemBuilder: (context, index) {
                      final order = _pendingOrders[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          title: Text(order.customerName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${order.gallonQuantity} Galon'),
                              if (order.address != null) Text(order.address!),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed:
                                _isLoading ? null : () => _processDelivery(order),
                            child: const Text('Antar'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
