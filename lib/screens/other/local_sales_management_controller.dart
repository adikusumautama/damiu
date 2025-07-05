// lib/screens/other/local_sales_management_controller.dart

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
import 'package:damiu/models/order_model.dart'; // <-- PERBAIKAN: Tambahkan impor ini
import 'widgets/edit_customer_dialog.dart';


class LocalSalesManagementController extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AuthService _authService = AuthService();
  final SyncService _syncService = SyncService();
  StreamSubscription? _firestoreChangesListener;
  StreamSubscription? _connectivitySubscription;
  bool _isOnline = false;

  // State
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
    _firestoreChangesListener?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _initConnectivityAndSync() {
    Connectivity().checkConnectivity().then((results) {
       _updateConnectionStatus(results.first);
    });
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      _updateConnectionStatus(results.first);
    });
  }

  void _updateConnectionStatus(ConnectivityResult result) async {
    final online = result != ConnectivityResult.none;
    if (online && !_isOnline) {
      await _syncService.syncAllData();
      _firestoreChangesListener?.cancel();
      _firestoreChangesListener = _syncService.listenToFirestoreChanges();
    } else if (!online && _isOnline) {
      _firestoreChangesListener?.cancel();
    }
    _isOnline = online;
    notifyListeners();
  }

  Future<void> refreshAllData() async {
    isLoading = true;
    notifyListeners();
    await Future.wait([
      _loadLocalOrdersAsLogs(),
      _loadLocalStockData(),
      _loadLocalCustomers(),
    ]);
    isLoading = false;
    notifyListeners();
  }

  Future<void> _loadLocalOrdersAsLogs() async {
    final orders = await _dbHelper.getTodaysOrders();
    localDeliveryLogs = orders.map((order) => DeliveryLogItem(
      id: order.id,
      timestamp: order.createdAt ?? DateTime.now(),
      gallons: order.gallonQuantity ?? 0,
      employeeUid: order.employeeUid ?? '',
      isSummarized: order.status == OrderStatus.delivered
    )).toList();

    totalGallonsInLogs = localDeliveryLogs.fold(0, (sum, log) => sum + log.gallons);
    totalLogs = localDeliveryLogs.where((log) => log.gallons > 0).length;

    for (var log in localDeliveryLogs) {
      if (!employeeNames.containsKey(log.employeeUid)) {
        employeeNames[log.employeeUid] = await getEmployeeName(log.employeeUid);
      }
    }
    notifyListeners();
  }

  Future<void> _loadLocalStockData() async {
    final stock = await _dbHelper.getDailyStock(DateTime.now());
    localStockData = stock != null ? [stock] : [];
    notifyListeners();
  }

  Future<void> _loadLocalCustomers() async {
    localCustomers = await _dbHelper.getAllCustomers();
    notifyListeners();
  }

  Future<String> getEmployeeName(String? employeeUid) async {
    if (employeeUid == null || employeeUid.isEmpty) return 'N/A';
    if (employeeNames.containsKey(employeeUid)) return employeeNames[employeeUid]!;
    
    final userModel = await _authService.getUserModel(employeeUid);
    final name = userModel?.name ?? 'Unknown';
    employeeNames[employeeUid] = name;
    return name;
  }

  Future<void> showEditCustomerDialog(Customer customer) async {
    if (context == null) return;
    final Customer? updatedCustomer = await showDialog<Customer>(
      context: context!,
      builder: (ctx) => EditCustomerDialog(customer: customer),
    );

    if (updatedCustomer != null) {
      final hasChanges = updatedCustomer.name != customer.name ||
          updatedCustomer.address != customer.address ||
          updatedCustomer.phoneNumber != customer.phoneNumber;
          
      if (hasChanges) {
        await _dbHelper.updateCustomer(updatedCustomer.copyWith(isSynced: false));
        await refreshAllData();
        if(context!.mounted) {
           ScaffoldMessenger.of(context!).showSnackBar(const SnackBar(content: Text('Data pelanggan diperbarui.')));
        }
      }
    }
  }
}