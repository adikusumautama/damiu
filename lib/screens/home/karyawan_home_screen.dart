// lib/screens/home/karyawan_home_screen.dart

import 'dart:async';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:damiu/models/order_model.dart';
import 'package:damiu/models/user_model.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:damiu/services/database_helper.dart';
import 'package:damiu/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:damiu/screens/home/widgets/add_order_dialog.dart';
import 'package:damiu/screens/home/widgets/order_summary.dart';
import 'package:damiu/screens/home/widgets/orders_list.dart';
import 'package:damiu/screens/home/widgets/set_stock_dialog.dart';
import 'package:damiu/screens/home/widgets/resource_board.dart';
import 'package:damiu/screens/home/widgets/profile_section.dart';
import 'package:damiu/screens/home/widgets/customer_book.dart';
import 'package:damiu/main.dart' show resetDailyStockIfNeeded;
import 'package:damiu/screens/other/local_sales_management_screen.dart';

class KaryawanHomeViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SyncService _syncService = SyncService();
  final AuthService _authService = AuthService();

  int _selectedIndex = 0;
  bool _isOnline = true;
  UserModel? _currentUser;
  List<Order> _localOrders = [];
  bool _isSyncing = false;
  late StreamSubscription _connectivitySubscription;

  int get selectedIndex => _selectedIndex;
  bool get isOnline => _isOnline;
  UserModel? get currentUser => _currentUser;
  List<Order> get localOrders => _localOrders;
  bool get isSyncing => _isSyncing;

  KaryawanHomeViewModel() {
    _init();
  }

  void _init() async {
    await _loadCurrentUser();
    await _loadLocalOrders();
    _initConnectivity();
    await resetDailyStockIfNeeded(
      isOnline: _isOnline,
      employeeUid: _currentUser?.uid,
      activeDate: DateTime.now(),
    );
    if(hasListeners) notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  void _initConnectivity() {
    Connectivity().checkConnectivity().then((results) {
      _updateConnectionStatus(results, isInitial: true);
    });
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> results, {bool isInitial = false}) async {
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    final bool currentlyOnline = result != ConnectivityResult.none;

    if (currentlyOnline == _isOnline && !isInitial) return;

    _isOnline = currentlyOnline;
    notifyListeners();

    if (currentlyOnline && !isInitial) {
      await syncData();
    }
  }

  Future<void> syncData() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();
    try {
      await _syncService.syncAllData();
      await _loadLocalOrders();
    } finally {
      if(hasListeners) {
        _isSyncing = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = _authService.getCurrentUser();
    if (user != null) {
      _currentUser = await _authService.getUserModel(user.uid);
    }
    if(hasListeners) notifyListeners();
  }

  Future<void> _loadLocalOrders() async {
    _localOrders = await _dbHelper.getUnsyncedOrders();
    if(hasListeners) notifyListeners();
  }

  void onItemTapped(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  // --- LOGIKA CRUD BARU ---
  Future<String?> onUpdateOrder(String firestoreId, Order updatedOrder) async {
    return await _firestoreService.updateOrder(firestoreId, updatedOrder);
  }

  Future<String?> onDeleteOrder(String firestoreId) async {
    return await _firestoreService.deleteOrder(firestoreId);
  }

  Future<String?> onStartDelivery(Order order) async {
    if(order.firestoreId == null) return "Order ID tidak valid.";
    return await _firestoreService.updateOrderStatus(order.firestoreId!, OrderStatus.inDelivery);
  }

  Future<String?> onCompleteDelivery(Order order) async {
    return await _firestoreService.completeOrderTransaction(order);
  }
  
  Future<void> onAddOrder({
    required String customerName,
    required int gallonQuantity,
    String? otherItems,
    String? address,
    String? phoneNumber,
    required DateTime date,
  }) async {
    DateTime finalDateTime = date;
    if (date.hour == 0 && date.minute == 0) {
      final now = DateTime.now();
      finalDateTime = DateTime(date.year, date.month, date.day, now.hour, now.minute, now.second);
    }
    final newOrder = Order(
      customerName: customerName,
      gallonQuantity: gallonQuantity,
      otherItems: otherItems,
      address: address,
      phoneNumber: phoneNumber,
      status: OrderStatus.pending,
      createdAt: finalDateTime,
      employeeUid: _currentUser?.uid,
      isSynced: _isOnline,
    );
    if (_isOnline) {
      await _firestoreService.addOrderAndUpsertCustomer(newOrder);
    } else {
      await _dbHelper.insertOrder(newOrder);
      await _loadLocalOrders();
    }
    if(hasListeners) notifyListeners();
  }

  Future<void> onSetInitialStock(BuildContext context) async {
    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => const SetStockDialog(),
    );
    if (result != null && _currentUser != null) {
      if (!context.mounted) return;
      if (_isOnline) {
        await _firestoreService.setInitialStock(
          date: DateTime.now(),
          filledStock: result['stock'] ?? 0,
          updatedByUid: _currentUser!.uid,
        );
      } else {
        await _dbHelper.setInitialStock(
          date: DateTime.now(),
          filledStock: result['stock'] ?? 0,
          updatedByUid: _currentUser!.uid,
        );
      }
      if(hasListeners) notifyListeners();
    }
  }
  
  Future<void> completeLocalOrder(Order order) async {
      if(order.id == null) return;
      await _dbHelper.updateOrderStatus(order.id!, OrderStatus.delivered, setDeliveredTime: true);
      await _loadLocalOrders();
  }
}

class KaryawanHomeScreen extends StatelessWidget {
  const KaryawanHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => KaryawanHomeViewModel(),
      child: Consumer<KaryawanHomeViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text(_getAppBarTitle(viewModel.selectedIndex)),
              actions: [
                if (viewModel.isSyncing)
                  const Padding(
                    padding: EdgeInsets.only(right: 16.0),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
                  )
              ],
              bottom: !viewModel.isOnline
                  ? PreferredSize(
                      preferredSize: const Size.fromHeight(24.0),
                      child: Container(
                        color: Colors.orange.shade700,
                        width: double.infinity,
                        padding: const EdgeInsets.all(4),
                        child: const Text('Mode Offline', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    )
                  : null,
            ),
            body: IndexedStack(index: viewModel.selectedIndex, children: _buildPages(context, viewModel)),
            bottomNavigationBar: BottomNavigationBar(
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
                BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Pelanggan'),
                BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
              ],
              currentIndex: viewModel.selectedIndex,
              onTap: viewModel.onItemTapped,
            ),
            floatingActionButton: viewModel.selectedIndex == 0
                ? FloatingActionButton(
                    onPressed: () => _showAddOrderDialog(context, viewModel),
                    tooltip: 'Catat Pesanan',
                    child: const Icon(Icons.add),
                  )
                : null,
          );
        },
      ),
    );
  }

  String _getAppBarTitle(int index) {
    const titles = ['Beranda', 'Buku Pelanggan', 'Profil'];
    return titles[index];
  }

  List<Widget> _buildPages(BuildContext context, KaryawanHomeViewModel viewModel) {
    Widget summaryWidget = viewModel.isOnline
        ? StreamBuilder<List<Order>>(
            stream: viewModel._firestoreService.getTodaysOrdersStream(),
            builder: (_, snapshot) => OrderSummary(orders: snapshot.data ?? [], isOnline: true),
          )
        : OrderSummary(orders: viewModel.localOrders, isOnline: false);

    return [
      Column(
        children: [
          summaryWidget,
          ResourceBoard(
            isOnline: viewModel.isOnline,
            employeeUid: viewModel.currentUser?.uid,
            onSetStock: () => viewModel.onSetInitialStock(context),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: viewModel.isOnline
                ? OrdersStreamWidget(
                    onStartDelivery: (order) async {
                      final error = await viewModel.onStartDelivery(order);
                      if (context.mounted) _handleApiError(context, error);
                    },
                    onCompleteDelivery: (order) async {
                      final error = await viewModel.onCompleteDelivery(order);
                      if (context.mounted) _handleApiError(context, error);
                    },
                    // --- HUBUNGKAN AKSI CRUD KE UI ---
                    onEdit: (order) => _showAddOrderDialog(context, viewModel, orderToEdit: order),
                    onDelete: (order) => _showDeleteConfirmDialog(context, viewModel, order),
                  )
                : OrdersLocalWidget(
                    orders: viewModel.localOrders,
                    onStartDelivery: (order) async {
                      if (order.id == null) return;
                      await viewModel._dbHelper.updateOrderStatus(order.id!, OrderStatus.inDelivery);
                      await viewModel._loadLocalOrders();
                    },
                    onCompleteDelivery: (order) async {
                       if (order.id == null) return;
                       await viewModel.completeLocalOrder(order);
                    },
                    // CRUD untuk mode offline bisa ditambahkan di sini
                    onEdit: (order) {}, // Placeholder
                    onDelete: (order) {}, // Placeholder
                  ),
          ),
        ],
      ),
      CustomerBook(isOnline: viewModel.isOnline),
      ProfileSection(
        user: viewModel.currentUser,
        onLogout: () {
          showModalBottomSheet(context: context, builder: (ctx) => Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: const Text('Manajemen Data Lokal'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LocalSalesManagementScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: () => viewModel._authService.signOut(),
              ),
            ],
          ));
        },
      ),
    ];
  }

  // --- FUNGSI DIALOG YANG DIPERBARUI ---
  void _showAddOrderDialog(BuildContext context, KaryawanHomeViewModel viewModel, {Order? orderToEdit}) {
    showDialog(
      context: context,
      builder: (ctx) => AddOrderDialog(
        orderToEdit: orderToEdit, // Kirim data pesanan jika ini mode edit
        onSubmit: ({
          required String customerName,
          required int gallonQuantity,
          String? otherItems,
          String? address,
          String? phoneNumber,
          required DateTime date,
        }) async {
          if (orderToEdit != null) {
            // --- LOGIKA UPDATE ---
            final updatedOrder = Order(
              firestoreId: orderToEdit.firestoreId,
              customerName: customerName,
              gallonQuantity: gallonQuantity,
              otherItems: otherItems,
              address: address,
              phoneNumber: phoneNumber,
              status: orderToEdit.status, // Pertahankan status
              createdAt: orderToEdit.createdAt, // Pertahankan tanggal dibuat
              employeeUid: viewModel.currentUser?.uid,
            );
            final error = await viewModel.onUpdateOrder(orderToEdit.firestoreId!, updatedOrder);
            if(context.mounted) _handleApiError(context, error, successMessage: 'Pesanan berhasil diperbarui!');
          } else {
            // --- LOGIKA CREATE ---
            await viewModel.onAddOrder(
              customerName: customerName,
              gallonQuantity: gallonQuantity,
              otherItems: otherItems,
              address: address,
              phoneNumber: phoneNumber,
              date: date,
            );
             if(context.mounted) _handleApiError(context, null, successMessage: 'Pesanan baru berhasil ditambahkan!');
          }
        },
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, KaryawanHomeViewModel viewModel, Order order) {
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
                final error = await viewModel.onDeleteOrder(order.firestoreId!);
                if(context.mounted) _handleApiError(context, error, successMessage: 'Pesanan berhasil dihapus.');
              }
            },
          ),
        ],
      ),
    );
  }

  void _handleApiError(BuildContext context, String? error, {String? successMessage}) {
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
}