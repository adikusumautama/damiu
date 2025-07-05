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
    controller.init();
  }

  @override
  void dispose() {
    controller.disposeController(); // Perbaikan nama metode
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // DefaultTabController harus menjadi widget terluar yang membungkus Scaffold.
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manajemen Data Lokal'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.delivery_dining_outlined), text: 'Log Pengantaran'),
              Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Data Stok Awal'),
              Tab(icon: Icon(Icons.people_outline), text: 'Pelanggan'),
            ],
          ),
        ),
        drawer: KaryawanSidebar(controller: controller),
        body: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            controller.attachContext(context);
            return TabBarView(
              children: [
                // 1. Log Pengantaran
                DeliveryLogView(
                  isLoading: controller.isLoading,
                  logs: controller.localDeliveryLogs,
                  totalLogs: controller.totalLogs,
                  totalGallonsInLogs: controller.totalGallonsInLogs,
                  employeeNames: controller.employeeNames,
                  onRefresh: controller.refreshAllData,
                  onDeleteAll: controller.deleteAllLogs,
                  onDeleteSummarized: controller.deleteSummarizedLogs,
                  onDeleteLog: (id) => controller.deleteLog(id),
                  onEditLog: (log) => controller.showEditLogDialog(log),
                ),
                // 2. Data Stok
                LocalStockView(
                  isLoading: controller.isLoading,
                  stockData: controller.localStockData,
                  onRefresh: controller.refreshAllData,
                  getEmployeeName: controller.getEmployeeName,
                  onDeleteAll: controller.deleteAllStocks,
                  onDeleteStock: (id) => controller.deleteStock(id),
                  onEditStock: (stock) => controller.showEditStockDialog(stock),
                ),
                // 3. Data Pelanggan
                LocalCustomerView(
                  isLoading: controller.isLoading,
                  customers: controller.localCustomers,
                  onRefresh: controller.refreshAllData,
                  onDeleteAll: controller.deleteAllCustomers,
                  onDeleteCustomer: (id) => controller.deleteCustomer(id),
                  onEditCustomer: (customer) => controller.showEditCustomerDialog(customer),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
