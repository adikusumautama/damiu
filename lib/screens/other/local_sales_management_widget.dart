// lib/screens/other/local_sales_management_widget.dart

import 'package:flutter/material.dart';
import 'local_sales_management_controller.dart';
import 'widgets/delivery_log_view.dart';
import 'widgets/local_stock_view.dart';
import 'widgets/local_customer_view.dart';
import 'widgets/karyawan_sidebar.dart';

class LocalSalesManagementWidget extends StatefulWidget {
  const LocalSalesManagementWidget({super.key});

  @override
  State<LocalSalesManagementWidget> createState() => _LocalSalesManagementWidgetState();
}

class _LocalSalesManagementWidgetState extends State<LocalSalesManagementWidget> {
  late final LocalSalesManagementController controller;

  @override
  void initState() {
    super.initState();
    controller = LocalSalesManagementController();
    // Inisialisasi controller
    controller.init();
  }

  @override
  void dispose() {
    controller.disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manajemen Data Lokal'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.delivery_dining_outlined), text: 'Log Pesanan'),
              Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Data Stok'),
              Tab(icon: Icon(Icons.people_outline), text: 'Pelanggan'),
            ],
          ),
        ),
        drawer: KaryawanSidebar(controller: controller),
        body: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            // Memberikan context ke controller jika diperlukan untuk dialog, dll.
            controller.attachContext(context);
            return TabBarView(
              children: [
                // 1. Log Pengantaran (sekarang membaca dari data pesanan)
                DeliveryLogView(
                  isLoading: controller.isLoading,
                  logs: controller.localDeliveryLogs,
                  totalLogs: controller.totalLogs,
                  totalGallonsInLogs: controller.totalGallonsInLogs,
                  employeeNames: controller.employeeNames,
                  onRefresh: controller.refreshAllData,
                  // --- PERBAIKAN: Fungsi yang sudah dihapus tidak dipanggil lagi ---
                  onDeleteAll: () {
                    // Logika ini bisa dipindahkan ke dalam controller jika masih relevan
                    // Untuk saat ini, kita nonaktifkan untuk menghindari error
                  },
                  onDeleteSummarized: () {},
                  onDeleteLog: (id) {},
                  onEditLog: (log) {},
                ),
                // 2. Data Stok
                LocalStockView(
                  isLoading: controller.isLoading,
                  stockData: controller.localStockData,
                  onRefresh: controller.refreshAllData,
                  getEmployeeName: controller.getEmployeeName,
                  // --- PERBAIKAN: Fungsi yang sudah dihapus tidak dipanggil lagi ---
                  onDeleteAll: () {},
                  onDeleteStock: (id) {},
                  onEditStock: (stock) {},
                ),
                // 3. Data Pelanggan
                LocalCustomerView(
                  isLoading: controller.isLoading,
                  customers: controller.localCustomers,
                  onRefresh: controller.refreshAllData,
                  // --- PERBAIKAN: Fungsi yang sudah dihapus tidak dipanggil lagi ---
                  onDeleteAll: () {},
                  onDeleteCustomer: (id) {}, // Manajemen hapus pelanggan bisa ditambahkan kembali di controller jika perlu
                  onEditCustomer: controller.showEditCustomerDialog, // Ini masih ada
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}