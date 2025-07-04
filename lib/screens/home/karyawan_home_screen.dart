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
import 'widgets/order_item_card.dart';
import 'widgets/resource_board.dart';

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

  // Getter untuk tanggal & waktu aktif (custom jika ada, else DateTime.now())
  DateTime get _activeDateTime => _customDateTime ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _loadCurrentUser();
    _loadLocalOrders();
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
              return _OrderSummary(orders: orders, isOnline: _isOnline);
            },
          )
        : _OrderSummary(orders: _localOrders, isOnline: _isOnline);

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
                builder: (ctx) => _SetStockDialog(),
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
                          // ONLINE: Kurangi stok galon via transaksi
                          await _firestoreService.completeOrderTransaction(order);
                          // Update daily_sales Firestore (sudah dilakukan di transaksi, tapi pastikan juga di sini jika perlu)
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
                          // OFFLINE: Kurangi stok galon tersedia
                          final stock = await _dbHelper.getDailyStock(DateTime.now());
                          final newStock = (stock?.initialStock ?? 0) - (order.gallonQuantity ?? 0);
                          await _dbHelper.setInitialStock(
                            date: DateTime.now(),
                            filledStock: newStock < 0 ? 0 : newStock,
                            updatedByUid: _currentUser?.uid ?? '-',
                          );
                          // Update daily_sales lokal
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
      const Center(child: Text('Buku Pelanggan')), // Ganti dengan widget pelanggan
      const Center(child: Text('Profil Saya')), // Ganti dengan widget profil
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
          ],
        ),
      ),
    );
  }
} // Penutup class _KaryawanHomeScreenState

class OrdersStreamWidget extends StatelessWidget {
  final void Function(Order) onStartDelivery;
  final void Function(Order) onCompleteDelivery;
  OrdersStreamWidget({super.key, required this.onStartDelivery, required this.onCompleteDelivery});
  final FirestoreService _firestoreService = FirestoreService();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Order>>(
      stream: _firestoreService.getTodaysOrdersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return const Center(child: Text('Tidak ada pesanan hari ini.'));
        }
        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, i) {
            final order = orders[i];
            return OrderItemCard(
              order: order,
              onStartDelivery: () => onStartDelivery(order),
              onCompleteDelivery: () => onCompleteDelivery(order),
              onCancelOrder: () {}, // Implementasi jika perlu
            );
          },
        );
      },
    );
  }
}

class OrdersLocalWidget extends StatelessWidget {
  final List<Order> orders;
  final void Function(Order) onStartDelivery;
  final void Function(Order) onCompleteDelivery;
  const OrdersLocalWidget({super.key, required this.orders, required this.onStartDelivery, required this.onCompleteDelivery});
  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Center(child: Text('Tidak ada pesanan lokal hari ini.'));
    }
    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, i) {
        final order = orders[i];
        return OrderItemCard(
          order: order,
          onStartDelivery: () => onStartDelivery(order),
          onCompleteDelivery: () => onCompleteDelivery(order),
          onCancelOrder: () {}, // Implementasi jika perlu
        );
      },
    );
  }
}

// Widget ringkasan statistik pesanan hari ini
class _OrderSummary extends StatelessWidget {
  final List<Order> orders;
  final bool isOnline;
  const _OrderSummary({required this.orders, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final total = orders.length;
    final delivered = orders.where((o) => o.status == OrderStatus.delivered).length;
    final inDelivery = orders.where((o) => o.status == OrderStatus.inDelivery).length;
    final pending = orders.where((o) => o.status == OrderStatus.pending).length;
    final totalGallon = orders.fold<int>(0, (sum, o) => sum + (o.gallonQuantity ?? 0));
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStat('Total Pesanan', total, Icons.list_alt),
            _buildStat('Belum Diantar', pending, Icons.pending_actions),
            _buildStat('Sedang Antar', inDelivery, Icons.local_shipping),
            _buildStat('Terkirim', delivered, Icons.check_circle),
            _buildStat('Total Galon', totalGallon, Icons.local_drink),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, int value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 28, color: Colors.blueGrey),
        const SizedBox(height: 4),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// Dialog untuk set/kustomisasi resource galon
class _SetStockDialog extends StatefulWidget {
  @override
  State<_SetStockDialog> createState() => _SetStockDialogState();
}

class _SetStockDialogState extends State<_SetStockDialog> {
  final _stockController = TextEditingController();
  @override
  void dispose() {
    _stockController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Persediaan Galon'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _stockController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Galon Tersedia'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'stock': int.tryParse(_stockController.text) ?? 0,
            });
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}