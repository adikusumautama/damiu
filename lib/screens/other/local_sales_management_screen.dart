// ======================================================================
// FILE UTAMA (DIPERBARUI): lib/screens/other/local_sales_management_screen.dart
// ======================================================================
// FOKUS: Mengelola state, logika, dan menyusun widget-widget tampilan.

import 'package:damiu/models/customer_model.dart';
import 'package:damiu/models/daily_stock_model.dart';
import 'package:damiu/models/delivery_log_model.dart';
import 'package:damiu/models/user_model.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/services/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Impor widget-widget yang sudah dipecah
import 'widgets/delivery_log_view.dart';
import 'widgets/local_stock_view.dart';
import 'widgets/local_customer_view.dart';

class LocalSalesManagementWidget extends StatefulWidget {
  const LocalSalesManagementWidget({super.key});

  @override
  State<LocalSalesManagementWidget> createState() =>
      _LocalSalesManagementWidgetState();
}

class _LocalSalesManagementWidgetState extends State<LocalSalesManagementWidget> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AuthService _authService = AuthService();
  
  // State untuk data
  List<DeliveryLogItem> _localDeliveryLogs = [];
  List<DailyStock> _localStockData = [];
  List<Customer> _localCustomers = [];

  // State untuk UI
  Map<String, String> _employeeNames = {};
  bool _isLoading = true;
  int _totalLogs = 0;
  int _totalGallonsInLogs = 0;

  @override
  void initState() {
    super.initState();
    _refreshAllData();
  }

  // ============== LOGIKA & MANAJEMEN DATA ==============

  Future<void> _refreshAllData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });
    await Future.wait([
      _loadLocalDeliveryLogs(),
      _loadLocalStockData(),
      _loadLocalCustomers(),
    ]);
    if (mounted) {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _loadLocalDeliveryLogs() async {
    final logs = await _dbHelper.getAllDeliveryLogs();
    int totalGallons = 0;
    int actualLogsCount = 0;
    _employeeNames.clear();

    for (var log in logs) {
      totalGallons += log.gallons;
      if (!log.isNoDeliveryMarker && log.gallons > 0) {
        actualLogsCount++;
      }
      if (!_employeeNames.containsKey(log.employeeUid)) {
        final employeeName = await _getEmployeeName(log.employeeUid);
        if(mounted) {
           _employeeNames[log.employeeUid] = employeeName;
        }
      }
    }
    if (mounted) {
        setState(() {
        _localDeliveryLogs = logs;
        _totalLogs = actualLogsCount;
        _totalGallonsInLogs = totalGallons;
        });
    }
  }

  Future<void> _loadLocalStockData() async {
    try {
      final stocks = await _dbHelper.getAllLocalStocks();
      if (mounted) setState(() { _localStockData = stocks; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data stok lokal: $e')));
    }
  }

  Future<void> _loadLocalCustomers() async {
    try {
      final customers = await _dbHelper.getAllCustomers();
      if (mounted) setState(() { _localCustomers = customers; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data pelanggan: $e')));
    }
  }
  
  Future<String> _getEmployeeName(String? employeeUid) async {
    if (employeeUid == null || employeeUid.isEmpty) return 'Tidak diketahui';
    if (_employeeNames.containsKey(employeeUid)) return _employeeNames[employeeUid]!;
    
    try {
      final UserModel? userModel = await _authService.getUserModel(employeeUid);
      final userName = userModel?.name ?? 'Nama tidak ditemukan';
      if(mounted) _employeeNames[employeeUid] = userName;
      return userName;
    } catch (e) {
      return 'Gagal memuat nama';
    }
  }

  Future<void> _deleteLog(int id) async {
    await _dbHelper.deleteDeliveryLog(id);
    _refreshAllData();
  }

  Future<void> _deleteAllLogs() async {
    final bool confirm = await showDialog(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Konfirmasi Hapus Semua Log'),
            content: const Text('Anda yakin ingin menghapus SEMUA log pengantaran lokal?'),
            actions: <Widget>[
              TextButton(child: const Text('Batal'), onPressed: () => Navigator.of(ctx).pop(false)),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Hapus Semua'),
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ) ?? false;

    if (confirm) {
      await _dbHelper.deleteAllDeliveryLogs();
      _refreshAllData();
    }
  }

  Future<void> _deleteSummarizedLogs() async {
    await _dbHelper.deleteSummarizedDeliveryLogs();
    _refreshAllData();
  }

  Future<void> _deleteStock(String dateId) async {
    await _dbHelper.deleteDailyStock(dateId);
    _refreshAllData();
  }

  Future<void> _deleteAllStocks() async {
     final bool confirm = await showDialog(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Konfirmasi Hapus Semua Stok'),
        content: const Text('Anda yakin ingin menghapus SEMUA data stok awal lokal?'),
        actions: <Widget>[
          TextButton(child: const Text('Batal'), onPressed: () => Navigator.of(ctx).pop(false)),
          TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Hapus Semua'), onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await _dbHelper.deleteAllDailyStocks();
      _refreshAllData();
    }
  }

  Future<void> _deleteCustomer(int id) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: const Text('Anda yakin ingin menghapus data pelanggan ini?'),
        actions: <Widget>[
          TextButton(child: const Text('Batal'), onPressed: () => Navigator.of(ctx).pop(false)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await _dbHelper.deleteCustomer(id);
        _refreshAllData();
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus pelanggan: $e')));
      }
    }
  }

  Future<void> _deleteAllCustomers() async {
    final bool confirm = await showDialog(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Hapus Semua Pelanggan'),
        content: const Text('ANDA YAKIN ingin menghapus SEMUA data pelanggan dari perangkat ini? Tindakan ini tidak dapat dibatalkan.'),
        actions: <Widget>[
          TextButton(child: const Text('Batal'), onPressed: () => Navigator.of(ctx).pop(false)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Ya, Hapus Semua'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    ) ?? false;
    
    if (confirm) {
      try {
        await _dbHelper.deleteAllCustomers();
        _refreshAllData();
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus semua pelanggan: $e')));
      }
    }
  }

  Future<void> _showEditCustomerDialog(Customer customer) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: customer.name);
    final addressController = TextEditingController(text: customer.address);
    final phoneController = TextEditingController(text: customer.phoneNumber);

    final updatedCustomer = await showDialog<Customer>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${customer.name}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nama'),
                validator: (val) => val!.isEmpty ? 'Nama tidak boleh kosong' : null,
              ),
              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Alamat (Opsional)'),
              ),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'No. HP (Opsional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            child: const Text('Simpan'),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final newCustomer = customer.copyWith(
                  name: nameController.text,
                  address: addressController.text,
                  phoneNumber: phoneController.text,
                );
                Navigator.pop(context, newCustomer);
              }
            },
          ),
        ],
      )
    );

    if (updatedCustomer != null) {
      try {
        await _dbHelper.updateCustomer(updatedCustomer);
        _refreshAllData();
      } catch (e) {
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memperbarui pelanggan: $e')));
      }
    }
  }

  Future<void> _showEditLogDialog(DeliveryLogItem log) async {
    // Implementasi dialog edit log di sini...
    // Setelah selesai, panggil _refreshAllData();
  }

  Future<void> _showEditStockDialog(DailyStock stock) async {
    // Implementasi dialog edit stok di sini...
    // Setelah selesai, panggil _refreshAllData();
  }

  // ============== BAGIAN UI ==============

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.delivery_dining_outlined), text: 'Log Pengantaran'),
              Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Data Stok Awal'),
              Tab(icon: Icon(Icons.people_outline), text: 'Pelanggan'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // 1. Tampilan Log Pengantaran
                DeliveryLogView(
                  isLoading: _isLoading,
                  logs: _localDeliveryLogs,
                  totalLogs: _totalLogs,
                  totalGallonsInLogs: _totalGallonsInLogs,
                  employeeNames: _employeeNames,
                  onRefresh: _refreshAllData,
                  onDeleteAll: _deleteAllLogs,
                  onDeleteSummarized: _deleteSummarizedLogs,
                  onDeleteLog: _deleteLog,
                  onEditLog: _showEditLogDialog,
                ),

                // 2. Tampilan Data Stok
                LocalStockView(
                  isLoading: _isLoading,
                  stockData: _localStockData,
                  onRefresh: _refreshAllData,
                  getEmployeeName: _getEmployeeName,
                  onDeleteAll: _deleteAllStocks,
                  onDeleteStock: _deleteStock,
                  onEditStock: _showEditStockDialog,
                ),

                // 3. Tampilan Data Pelanggan
                LocalCustomerView(
                  isLoading: _isLoading,
                  customers: _localCustomers,
                  onRefresh: _refreshAllData,
                  onDeleteAll: _deleteAllCustomers,
                  onDeleteCustomer: _deleteCustomer,
                  onEditCustomer: _showEditCustomerDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}