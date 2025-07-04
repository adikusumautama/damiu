// ======================================================================
// FILE: lib/screens/home/karyawan_home_screen.dart
// ======================================================================
// FOKUS: File utama yang sekarang lebih ringkas, berisi logika state
// dan menyusun widget-widget yang sudah dipecah.

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:damiu/models/order_model.dart';
import 'package:damiu/models/user_model.dart';
import 'package:damiu/models/daily_sale_model.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:damiu/services/database_helper.dart';
import 'package:damiu/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'widgets/add_order_dialog.dart';
import 'widgets/order_summary.dart';
import 'widgets/orders_list.dart';
import 'widgets/set_stock_dialog.dart';
import 'widgets/resource_board.dart';
import 'widgets/profile_section.dart';
import 'widgets/customer_book.dart';
import '../../main.dart' show resetDailyStockIfNeeded;

class KaryawanHomeScreen extends StatefulWidget {
  const KaryawanHomeScreen({super.key});
  @override
  State<KaryawanHomeScreen> createState() => _KaryawanHomeScreenState();
}

class _KaryawanHomeScreenState extends State<KaryawanHomeScreen> {
  int _selectedIndex = 0;
  bool _isOnline = true;
  late StreamSubscription _connectivitySubscription;
  final FirestoreService _firestoreService = FirestoreService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SyncService _syncService = SyncService();
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  List<Order> _localOrders = [];
  DateTime? _customDateTime; // Tambahan: tanggal/waktu custom

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _loadCurrentUser();
    _loadLocalOrders();
    // Reset stok harian otomatis saat screen diinisialisasi
    Future.microtask(() async {
      await resetDailyStockIfNeeded(isOnline: _isOnline, employeeUid: _currentUser?.uid);
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  void _initConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    _updateConnectionStatus(result);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      _updateConnectionStatus(result);
    });
  }

  void _updateConnectionStatus(ConnectivityResult result) async {
    final online = result != ConnectivityResult.none;
    if (online && !_isOnline) {
      // Baru online, lakukan sinkronisasi
      await _syncService.syncAllData();
      setState(() => _isOnline = true);
    } else if (!online && _isOnline) {
      setState(() => _isOnline = false);
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = _authService.getCurrentUser();
    if (user != null) {
      final userModel = await _authService.getUserModel(user.uid);
      setState(() => _currentUser = userModel);
    }
  }

  Future<void> _loadLocalOrders() async {
    final orders = await _dbHelper.getUnsyncedOrders();
    setState(() => _localOrders = orders);
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  // Tambahan: fungsi untuk memilih tanggal & waktu
  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initialDate = _customDateTime ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );
      if (pickedTime != null) {
        setState(() {
          _customDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget summaryWidget = _isOnline
        ? StreamBuilder<List<Order>>(
            stream: _firestoreService.getTodaysOrdersStream(),
            builder: (context, snapshot) {
              final orders = snapshot.data ?? [];
              return OrderSummary(orders: orders, isOnline: _isOnline);
            },
          )
        : OrderSummary(orders: _localOrders, isOnline: _isOnline);

    final List<Widget> _pages = [
      Column(
        children: [
          if (!_isOnline)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.all(8),
              child: const Text('Mode Offline: Data diambil dari lokal', style: TextStyle(color: Colors.orange)),
            ),
          summaryWidget,
          ResourceBoard(
            isOnline: _isOnline,
            employeeUid: _currentUser?.uid,
            onSetStock: () async {
              final result = await showDialog<Map<String, int>>(
                context: context,
                builder: (ctx) => const SetStockDialog(),
              );
              if (result != null) {
                if (_isOnline) {
                  await _firestoreService.setInitialStock(
                    date: DateTime.now(),
                    filledStock: result['stock'] ?? 0,
                    updatedByUid: _currentUser?.uid ?? '-',
                  );
                } else {
                  await _dbHelper.setInitialStock(
                    date: DateTime.now(),
                    filledStock: result['stock'] ?? 0,
                    updatedByUid: _currentUser?.uid ?? '-',
                  );
                }
                setState(() {});
              }
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Stack(
              children: [
                _isOnline
                    ? OrdersStreamWidget(
                        onStartDelivery: (order) async {
                          await _firestoreService.updateOrderStatus(order.firestoreId!, OrderStatus.inDelivery);
                        },
                        onCompleteDelivery: (order) async {
                          await _firestoreService.completeOrderTransaction(order);
                          await _firestoreService.recordSale(
                            order.gallonQuantity ?? 0,
                            1,
                          );
                        },
                      )
                    : OrdersLocalWidget(
                        orders: _localOrders,
                        onStartDelivery: (order) async {
                          await _dbHelper.updateOrderStatus(order.id!, OrderStatus.inDelivery);
                          await _loadLocalOrders();
                        },
                        onCompleteDelivery: (order) async {
                          await _dbHelper.updateOrderStatus(order.id!, OrderStatus.delivered, setDeliveredTime: true);
                          final stock = await _dbHelper.getDailyStock(DateTime.now());
                          final newStock = (stock?.initialStock ?? 0) - (order.gallonQuantity ?? 0);
                          await _dbHelper.setInitialStock(
                            date: DateTime.now(),
                            filledStock: newStock < 0 ? 0 : newStock,
                            updatedByUid: _currentUser?.uid ?? '-',
                          );
                          final today = DateTime.now();
                          final oldSale = await _dbHelper.getDailySaleByDate(today);
                          final newQty = (oldSale?.quantity ?? 0) + (order.gallonQuantity ?? 0);
                          final newCount = (oldSale?.deliveryCount ?? 0) + 1;
                          await _dbHelper.upsertDailySummary(
                            DailySale(
                              date: today,
                              deliveryCount: newCount,
                              quantity: newQty,
                              isSynced: false,
                              employeeUid: _currentUser?.uid,
                            ),
                          );
                          await _loadLocalOrders();
                        },
                      ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton.extended(
                    icon: const Icon(Icons.add),
                    label: const Text('Catat Pesanan'),
                    onPressed: () async {
                      showDialog(
                        context: context,
                        builder: (ctx) => AddOrderDialog(
                          onSubmit: ({
                            required String customerName,
                            required int gallonQuantity,
                            String? otherItems,
                            String? address,
                            String? phoneNumber,
                          }) async {
                            final newOrder = Order(
                              customerName: customerName,
                              gallonQuantity: gallonQuantity,
                              otherItems: otherItems,
                              address: address,
                              phoneNumber: phoneNumber,
                              status: OrderStatus.pending,
                              createdAt: DateTime.now(),
                              employeeUid: _currentUser?.uid,
                              isSynced: _isOnline, // Jika online, langsung sync
                            );
                            if (_isOnline) {
                              await _firestoreService.addOrder(newOrder);
                            } else {
                              await _dbHelper.insertOrder(newOrder);
                              await _loadLocalOrders();
                            }
                            if (mounted) setState(() {});
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      CustomerBook(isOnline: _isOnline),
      ProfileSection(
        user: _currentUser,
        onLogout: () async {
          await _authService.signOut();
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        },
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_selectedIndex == 0 ? 'Beranda' : _selectedIndex == 1 ? 'Pelanggan' : 'Profil'),
            Text(
              DateFormat('EEEE, dd MMMM yyyy • HH:mm').format(_customDateTime ?? DateTime.now()),
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Pelanggan'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(_currentUser?.name ?? '-'),
              accountEmail: Text(_currentUser?.email ?? '-'),
              currentAccountPicture: const CircleAvatar(child: Icon(Icons.person)),
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Sinkronisasi Manual'),
              onTap: () async {
                await _syncService.syncAllData();
                if (mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Set Tanggal & Waktu'),
              subtitle: _customDateTime != null
                  ? Text(DateFormat('dd MMM yyyy • HH:mm').format(_customDateTime!))
                  : null,
              onTap: () async {
                await _pickDateTime();
                if (mounted) Navigator.pop(context);
              },
            ),
            if (_customDateTime != null)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Reset ke Waktu Sekarang'),
                onTap: () {
                  setState(() {
                    _customDateTime = null;
                  });
                  Navigator.pop(context);
                },
              ),
            ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('Data Lokal'),
              subtitle: const Text('Lihat data log, stok, dan pelanggan yang tersimpan di perangkat.'),
              onTap: () async {
                final db = DatabaseHelper();
                List logs = await db.getAllDeliveryLogs();
                List stocks = await db.getAllLocalStocks();
                List customers = await db.getAllCustomers();
                if (!mounted) return;
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (ctx) => StatefulBuilder(
                    builder: (ctx, setModalState) => Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Log Pengantaran', style: Theme.of(context).textTheme.titleMedium),
                                IconButton(
                                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                                  tooltip: 'Hapus Semua Log',
                                  onPressed: () async {
                                    await db.deleteAllDeliveryLogs();
                                    logs = await db.getAllDeliveryLogs();
                                    setModalState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semua log dihapus.')));
                                  },
                                ),
                              ],
                            ),
                            ...logs.map((e) => ListTile(
                              dense: true,
                              title: Text('Tanggal: ${DateFormat('dd-MM-yyyy HH:mm').format(e.timestamp)}'),
                              subtitle: Text('Karyawan: ${e.employeeUid}\nGalon: ${e.gallons}\nStatus: ${e.isNoDeliveryMarker ? 'Tidak Ada Pengantaran' : 'Terkirim'}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Hapus Log Ini',
                                onPressed: () async {
                                  await db.deleteDeliveryLog(e.id!);
                                  logs = await db.getAllDeliveryLogs();
                                  setModalState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Log dihapus.')));
                                },
                              ),
                            )),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Stok Awal', style: Theme.of(context).textTheme.titleMedium),
                                IconButton(
                                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                                  tooltip: 'Hapus Semua Stok',
                                  onPressed: () async {
                                    await db.deleteAllDailyStocks();
                                    stocks = await db.getAllLocalStocks();
                                    setModalState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semua stok dihapus.')));
                                  },
                                ),
                              ],
                            ),
                            ...stocks.map((e) => ListTile(
                              dense: true,
                              title: Text('Tanggal: ${e.id}'),
                              subtitle: Text('Stok Awal: ${e.initialStock}\nStok Kosong: ${e.initialEmptyStock}\nKaryawan: ${e.updatedByUid}\nUpdate: ${DateFormat('dd-MM-yyyy HH:mm').format(e.lastUpdated)}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Hapus Stok Ini',
                                onPressed: () async {
                                  await db.deleteDailyStock(e.id);
                                  stocks = await db.getAllLocalStocks();
                                  setModalState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stok dihapus.')));
                                },
                              ),
                            )),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Pelanggan', style: Theme.of(context).textTheme.titleMedium),
                                IconButton(
                                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                                  tooltip: 'Hapus Semua Pelanggan',
                                  onPressed: () async {
                                    await db.deleteAllCustomers();
                                    customers = await db.getAllCustomers();
                                    setModalState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semua pelanggan dihapus.')));
                                  },
                                ),
                              ],
                            ),
                            ...customers.map((e) => ListTile(
                              dense: true,
                              title: Text('Nama: ${e.name}'),
                              subtitle: Text('Alamat: ${e.address ?? '-'}\nNo. HP: ${e.phoneNumber ?? '-'}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Hapus Pelanggan Ini',
                                onPressed: () async {
                                  await db.deleteCustomer(e.id);
                                  customers = await db.getAllCustomers();
                                  setModalState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pelanggan dihapus.')));
                                },
                              ),
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}