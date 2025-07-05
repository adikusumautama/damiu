// ======================================================================
// CONTROLLER: local_sales_management_controller.dart
// ======================================================================
// Berisi state, logic, dan fungsi async untuk LocalSalesManagementWidget.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:damiu/models/customer_model.dart';
import 'package:damiu/models/daily_stock_model.dart';
import 'package:damiu/models/delivery_log_model.dart';
import 'package:damiu/models/user_model.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/services/database_helper.dart';
import 'package:damiu/services/sync_service.dart';
import 'widgets/edit_customer_dialog.dart';

class LocalSalesManagementController extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AuthService _authService = AuthService();
  final SyncService _syncService = SyncService();
  StreamSubscription? _customerListener;
  StreamSubscription? _orderListener;
  StreamSubscription? _stockListener;
  StreamSubscription? _connectivitySubscription;
  bool _isOnline = false;

  // State untuk data
  List<DeliveryLogItem> localDeliveryLogs = [];
  List<DailyStock> localStockData = [];
  List<Customer> localCustomers = [];
  Map<String, String> employeeNames = {};
  bool isLoading = true;
  int totalLogs = 0;
  int totalGallonsInLogs = 0;

  BuildContext? context;

  void attachContext(BuildContext ctx) {
    context = ctx;
  }

  void init() {
    _initConnectivityAndSync();
    refreshAllData();
  }

  void disposeController() {
    _customerListener?.cancel();
    _orderListener?.cancel();
    _stockListener?.cancel();
    _connectivitySubscription?.cancel();
  }

  void _initConnectivityAndSync() async {
    final results = await Connectivity().checkConnectivity();
    _updateConnectionStatus(results);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      _updateConnectionStatus(results);
    });
  }

  void _updateConnectionStatus(dynamic result) async {
    ConnectivityResult status;
    if (result is List<ConnectivityResult> && result.isNotEmpty) {
      status = result.first;
    } else if (result is ConnectivityResult) {
      status = result;
    } else {
      status = ConnectivityResult.none;
    }
    final online = status != ConnectivityResult.none;
    if (online && !_isOnline) {
      await _syncService.syncAllData();
      _customerListener?.cancel();
      _orderListener?.cancel();
      _stockListener?.cancel();
      _customerListener = _syncService.listenCustomersRealtimeToLocal();
      _orderListener = _syncService.listenOrdersRealtimeToLocal();
      _stockListener = _syncService.listenStocksRealtimeToLocal();
      _isOnline = true;
    } else if (!online && _isOnline) {
      _customerListener?.cancel();
      _orderListener?.cancel();
      _stockListener?.cancel();
      _isOnline = false;
    }
  }

  Future<void> refreshAllData() async {
    isLoading = true;
    notifyListeners();
    await Future.wait([
      _loadLocalDeliveryLogs(),
      _loadLocalStockData(),
      _loadLocalCustomers(),
    ]);
    isLoading = false;
    notifyListeners();
  }

  Future<void> _loadLocalDeliveryLogs() async {
    final logs = await _dbHelper.getAllDeliveryLogs();
    int totalGallons = 0;
    int actualLogsCount = 0;
    employeeNames.clear();
    for (var log in logs) {
      totalGallons += log.gallons;
      if (!log.isNoDeliveryMarker && log.gallons > 0) {
        actualLogsCount++;
      }
      if (!employeeNames.containsKey(log.employeeUid)) {
        final employeeName = await getEmployeeName(log.employeeUid);
        employeeNames[log.employeeUid] = employeeName;
      }
    }
    localDeliveryLogs = logs;
    totalLogs = actualLogsCount;
    totalGallonsInLogs = totalGallons;
    notifyListeners();
  }

  Future<void> _loadLocalStockData() async {
    try {
      final stocks = await _dbHelper.getAllLocalStocks();
      localStockData = stocks;
      notifyListeners();
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context!).showSnackBar(SnackBar(content: Text('Gagal memuat data stok lokal: $e')));
      }
    }
  }

  Future<void> _loadLocalCustomers() async {
    try {
      final customers = await _dbHelper.getAllCustomers();
      localCustomers = customers;
      notifyListeners();
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context!).showSnackBar(SnackBar(content: Text('Gagal memuat data pelanggan: $e')));
      }
    }
  }

  Future<String> getEmployeeName(String? employeeUid) async {
    if (employeeUid == null || employeeUid.isEmpty) return 'Tidak diketahui';
    if (employeeNames.containsKey(employeeUid)) return employeeNames[employeeUid]!;
    try {
      final UserModel? userModel = await _authService.getUserModel(employeeUid);
      final userName = userModel?.name ?? 'Nama tidak ditemukan';
      employeeNames[employeeUid] = userName;
      return userName;
    } catch (e) {
      return 'Gagal memuat nama';
    }
  }

  // ================= CRUD LOG PENGANTARAN =================
  Future<void> deleteLog(int id) async {
    await _dbHelper.deleteDeliveryLog(id);
    await refreshAllData();
  }

  Future<void> deleteAllLogs() async {
    if (context == null) return;
    final bool confirm = await showDialog(
      context: context!,
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
      await refreshAllData();
    }
  }

  Future<void> deleteSummarizedLogs() async {
    await _dbHelper.deleteSummarizedDeliveryLogs();
    await refreshAllData();
  }

  Future<void> showEditLogDialog(DeliveryLogItem log) async {
    // TODO: Implementasi dialog edit log jika diperlukan
    // Setelah selesai, panggil refreshAllData();
  }

  // ================= CRUD STOK =================
  Future<void> deleteStock(String dateId) async {
    await _dbHelper.deleteDailyStock(dateId);
    await refreshAllData();
  }

  Future<void> deleteAllStocks() async {
    if (context == null) return;
    final bool confirm = await showDialog(
      context: context!,
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
      await refreshAllData();
    }
  }

  Future<void> deleteAllCustomers() async {
    if (context == null) return;
    final bool confirm = await showDialog(
      context: context!,
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
      await _dbHelper.deleteAllCustomers();
      await refreshAllData();
    }
  }

  // ================= CRUD PELANGGAN =================
  Future<void> deleteCustomer(int id) async {
    if (context == null) return;
    final bool confirm = await showDialog(
          context: context!,
          builder: (ctx) => AlertDialog(
            title: const Text('Konfirmasi Hapus'),
            content: const Text('Anda yakin ingin menghapus pelanggan ini dari database lokal?'),
            actions: [
              TextButton(child: const Text('Batal'), onPressed: () => Navigator.of(ctx).pop(false)),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Hapus'),
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await _dbHelper.deleteCustomer(id);
      await refreshAllData();
    }
  }

  Future<void> showEditStockDialog(DailyStock stock) async {
    // TODO: Implementasi dialog edit stok jika diperlukan
    // Setelah selesai, panggil refreshAllData();
  }

  Future<void> showEditCustomerDialog(Customer customer) async {
    if (context == null) return;
    final Customer? updatedCustomer = await showDialog<Customer>(
      context: context!,
      builder: (ctx) => EditCustomerDialog(customer: customer),
    );

    if (updatedCustomer != null) {
      // Cek apakah ada perubahan
      if (updatedCustomer.name != customer.name ||
          updatedCustomer.address != customer.address ||
          updatedCustomer.phoneNumber != customer.phoneNumber) {
        // Tandai sebagai belum sinkron jika ada perubahan
        await _dbHelper.updateCustomer(updatedCustomer.copyWith(isSynced: false));
        await refreshAllData();
        ScaffoldMessenger.of(context!).showSnackBar(const SnackBar(content: Text('Data pelanggan diperbarui.')));
      }
    }
  }
}