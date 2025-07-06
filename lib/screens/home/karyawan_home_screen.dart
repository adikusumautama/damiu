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
import 'package:damiu/screens/home/widgets/resource_board.dart';
import 'package:damiu/screens/home/widgets/profile_section.dart';
import 'package:damiu/screens/home/widgets/customer_book.dart';
import 'package:damiu/main.dart' show resetDailyStockIfNeeded;

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

  KaryawanHomeViewModel() { _init(); }

  void _init() async {
    await _loadCurrentUser();
    await _loadLocalOrders();
    _initConnectivity();
    await resetDailyStockIfNeeded(isOnline: _isOnline, employeeUid: _currentUser?.uid, activeDate: DateTime.now());
    if(hasListeners) notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  void _initConnectivity() {
    Connectivity().checkConnectivity().then((r) => _updateConnectionStatus(r, isInitial: true));
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> results, {bool isInitial = false}) async {
    final currentlyOnline = results.isNotEmpty && results.first != ConnectivityResult.none;
    if (currentlyOnline == _isOnline && !isInitial) return;
    _isOnline = currentlyOnline;
    notifyListeners();
    if (currentlyOnline && !isInitial) await syncData();
  }

  Future<void> syncData() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();
    try {
      await _syncService.syncAllData();
      await _loadLocalOrders();
    } finally {
      if(hasListeners) { _isSyncing = false; notifyListeners(); }
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = _authService.getCurrentUser();
    if (user != null) _currentUser = await _authService.getUserModel(user.uid);
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

  Future<String?> onUpdateOrder(String firestoreId, Order updatedOrder) async => await _firestoreService.updateOrder(firestoreId, updatedOrder);
  Future<String?> onDeleteOrder(String firestoreId) async => await _firestoreService.deleteOrder(firestoreId);
  Future<String?> onStartDelivery(Order order) async => (order.firestoreId == null) ? "Order ID tidak valid." : await _firestoreService.updateOrderStatus(order.firestoreId!, OrderStatus.inDelivery);
  Future<String?> onCompleteDelivery(Order order) async => await _firestoreService.completeOrderTransaction(order);
  
  Future<void> onAddOrder({required String customerName, required int gallonQuantity, String? otherItems, String? address, String? phoneNumber, required DateTime date}) async {
    final now = DateTime.now();
    final finalDateTime = (date.hour == 0 && date.minute == 0) ? DateTime(date.year, date.month, date.day, now.hour, now.minute, now.second) : date;
    final newOrder = Order(customerName: customerName, gallonQuantity: gallonQuantity, otherItems: otherItems, address: address, phoneNumber: phoneNumber, status: OrderStatus.pending, createdAt: finalDateTime, employeeUid: _currentUser?.uid, isSynced: _isOnline);
    if (_isOnline) {
      await _firestoreService.addOrderAndUpsertCustomer(newOrder);
    } else {
      await _dbHelper.insertOrder(newOrder);
      await _loadLocalOrders();
    }
    if(hasListeners) notifyListeners();
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
              actions: [ if (viewModel.isSyncing) const Padding(padding: EdgeInsets.only(right: 16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))) ],
              bottom: !viewModel.isOnline ? PreferredSize(preferredSize: const Size.fromHeight(24.0), child: Container(color: Colors.orange.shade700, width: double.infinity, padding: const EdgeInsets.all(4), child: const Text('Mode Offline', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 12)))) : null,
            ),
            body: IndexedStack(index: viewModel.selectedIndex, children: _buildPages(context, viewModel)),
            bottomNavigationBar: BottomNavigationBar(
              items: const [BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'), BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Pelanggan'), BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil')],
              currentIndex: viewModel.selectedIndex,
              onTap: viewModel.onItemTapped,
            ),
            floatingActionButton: viewModel.selectedIndex == 0 ? FloatingActionButton(onPressed: () => _showAddOrderDialog(context, viewModel), tooltip: 'Catat Pesanan', child: const Icon(Icons.add)) : null,
          );
        },
      ),
    );
  }

  String _getAppBarTitle(int index) => ['Beranda', 'Buku Pelanggan', 'Profil'][index];

  List<Widget> _buildPages(BuildContext context, KaryawanHomeViewModel viewModel) {
    Widget summaryWidget = viewModel.isOnline ? StreamBuilder<List<Order>>(stream: viewModel._firestoreService.getTodaysOrdersStream(), builder: (_, s) => OrderSummary(orders: s.data ?? [], isOnline: true)) : OrderSummary(orders: viewModel.localOrders, isOnline: false);
    return [
      Column(children: [
        summaryWidget,
        ResourceBoard(isOnline: viewModel.isOnline, employeeUid: viewModel.currentUser?.uid),
        const SizedBox(height: 8),
        Expanded(child: viewModel.isOnline ? OrdersStreamWidget(
          onStartDelivery: (o) async { final e = await viewModel.onStartDelivery(o); if (context.mounted) _handleApiError(context, e); },
          onCompleteDelivery: (o) async { final e = await viewModel.onCompleteDelivery(o); if (context.mounted) _handleApiError(context, e); },
          onEdit: (o) => _showAddOrderDialog(context, viewModel, orderToEdit: o),
          onDelete: (o) => _showDeleteConfirmDialog(context, viewModel, o),
        ) : OrdersLocalWidget(
          orders: viewModel.localOrders,
          onStartDelivery: (o) async { if (o.id != null) { await viewModel._dbHelper.updateOrderStatus(o.id!, OrderStatus.inDelivery); await viewModel._loadLocalOrders(); } },
          onCompleteDelivery: (o) async { if (o.id != null) await viewModel.completeLocalOrder(o); },
          onEdit: (o) {},
          onDelete: (o) {},
        )),
      ]),
      CustomerBook(isOnline: viewModel.isOnline),
      ProfileSection(user: viewModel.currentUser, onLogout: () => viewModel._authService.signOut()),
    ];
  }

  void _showAddOrderDialog(BuildContext context, KaryawanHomeViewModel viewModel, {Order? orderToEdit}) {
    showDialog(context: context, builder: (ctx) => AddOrderDialog(orderToEdit: orderToEdit, onSubmit: ({required customerName, required gallonQuantity, otherItems, address, phoneNumber, required date}) async {
      if (orderToEdit != null) {
        final updatedOrder = Order(firestoreId: orderToEdit.firestoreId, customerName: customerName, gallonQuantity: gallonQuantity, otherItems: otherItems, address: address, phoneNumber: phoneNumber, status: orderToEdit.status, createdAt: orderToEdit.createdAt, employeeUid: viewModel.currentUser?.uid);
        final e = await viewModel.onUpdateOrder(orderToEdit.firestoreId!, updatedOrder);
        if(context.mounted) _handleApiError(context, e, successMessage: 'Pesanan berhasil diperbarui!');
      } else {
        await viewModel.onAddOrder(customerName: customerName, gallonQuantity: gallonQuantity, otherItems: otherItems, address: address, phoneNumber: phoneNumber, date: date);
        if(context.mounted) _handleApiError(context, null, successMessage: 'Pesanan baru berhasil ditambahkan!');
      }
    }));
  }

  void _showDeleteConfirmDialog(BuildContext context, KaryawanHomeViewModel viewModel, Order order) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Konfirmasi Hapus'), content: Text('Anda yakin ingin menghapus pesanan untuk "${order.customerName}"?'), actions: [
      TextButton(child: const Text('Batal'), onPressed: () => Navigator.of(ctx).pop()),
      TextButton(child: const Text('Hapus', style: TextStyle(color: Colors.red)), onPressed: () async {
        Navigator.of(ctx).pop();
        if (order.firestoreId != null) {
          final e = await viewModel.onDeleteOrder(order.firestoreId!);
          if(context.mounted) _handleApiError(context, e, successMessage: 'Pesanan berhasil dihapus.');
        }
      }),
    ]));
  }

  void _handleApiError(BuildContext context, String? error, {String? successMessage}) {
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red));
    } else if (successMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage), backgroundColor: Colors.green));
    }
  }
}