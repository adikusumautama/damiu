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
import 'widgets/add_order_dialog.dart';
import 'widgets/order_summary.dart';
import 'widgets/orders_list.dart';
import 'widgets/set_stock_dialog.dart';
import 'widgets/resource_board.dart';
import 'widgets/profile_section.dart';
import 'widgets/customer_book.dart';
import '../../main.dart' show resetDailyStockIfNeeded;
import '../other/local_sales_management_screen.dart'; // <-- TAMBAHKAN IMPORT INI

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

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _loadCurrentUser();
    _loadLocalOrders();
    // Reset stok harian otomatis saat screen diinisialisasi
    Future.microtask(() async {
      await resetDailyStockIfNeeded(isOnline: _isOnline, employeeUid: _currentUser?.uid, activeDate: DateTime.now());
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  void _initConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    // Panggil _updateConnectionStatus dengan list hasil awal
    _updateConnectionStatus(results);
    // Dengarkan perubahan konektivitas
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) async {
    // Cek status mounted untuk menghindari error jika widget sudah di-dispose
    if (!mounted) return;

    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    final bool currentlyOnline = result != ConnectivityResult.none;

    // Hanya update state dan tampilkan notifikasi jika statusnya berubah
    if (currentlyOnline != _isOnline) {
      setState(() {
        _isOnline = currentlyOnline;
      });

      if (currentlyOnline) {
        // Baru saja kembali online
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Koneksi kembali terhubung. Memulai sinkronisasi...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        try {
          await _syncService.syncAllData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sinkronisasi data selesai.'), backgroundColor: Colors.blue),
            );
            _loadLocalOrders(); // Muat ulang data setelah sinkronisasi
          }
        } catch (e) {
          print('Error saat sinkronisasi otomatis: $e');
        }
      } else {
        // Baru saja offline
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anda sekarang offline. Perubahan akan disinkronkan nanti.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    Widget summaryWidget = _isOnline
        ? StreamBuilder<List<Order>>(
            stream: _firestoreService.getOrdersStream(), // Tampilkan semua orders, tanpa filter tanggal
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
                          // Hapus pemanggilan recordSale agar tidak double increment
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
                // FloatingActionButton.extended dihapus agar tidak ada tombol ganda
                // Positioned(
                //   bottom: 16,
                //   right: 16,
                //   child: FloatingActionButton.extended(
                //     icon: const Icon(Icons.add),
                //     label: const Text('Catat Pesanan'),
                //     onPressed: () async {
                //       showDialog(
                //         context: context,
                //         builder: (ctx) => AddOrderDialog(
                //           onSubmit: ({
                //             required String customerName,
                //             required int gallonQuantity,
                //             String? otherItems,
                //             String? address,
                //             String? phoneNumber,
                //           }) async {
                //             final newOrder = Order(
                //               customerName: customerName,
                //               gallonQuantity: gallonQuantity,
                //               otherItems: otherItems,
                //               address: address,
                //               phoneNumber: phoneNumber,
                //               status: OrderStatus.pending,
                //               createdAt: DateTime.now(),
                //               employeeUid: _currentUser?.uid,
                //               isSynced: _isOnline, // Jika online, langsung sync
                //             );
                //             if (_isOnline) {
                //               await _firestoreService.addOrder(newOrder);
                //             } else {
                //               await _dbHelper.insertOrder(newOrder);
                //               await _loadLocalOrders();
                //             }
                //             if (mounted) setState(() {});
                //           },
                //         ),
                //       );
                //     },
                //   ),
                // ),
              ],
            ),
          ),
        ],
      ),
      CustomerBook(isOnline: _isOnline),
      ProfileSection(
        user: _currentUser,
        onLogout: () async {
          // Tambahkan menu tambahan di sini
          showModalBottomSheet(
            context: context,
            builder: (ctx) => Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: const Text('Manajemen Data Lokal'),
                  onTap: () {
                    Navigator.pop(ctx); // Tutup bottom sheet
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LocalSalesManagementScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    await _authService.signOut();
                  },
                ),
              ],
            ),
          );
        },
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'Beranda' : _selectedIndex == 1 ? 'Pelanggan' : 'Profil'),
        // HAPUS: Tombol pengaturan tanggal & reset di AppBar
        // actions: [
        //   if (_selectedIndex == 0)
        //     IconButton(
        //       icon: const Icon(Icons.today),
        //       tooltip: 'Ubah Tanggal',
        //       onPressed: _pickDateTime,
        //     ),
        //   if (_selectedIndex == 0 && _customDateTime != null)
        //     IconButton(
        //       icon: const Icon(Icons.refresh),
        //       tooltip: 'Reset ke Hari Ini',
        //       onPressed: () => setState(() => _customDateTime = null),
        //     ),
        // ],
      ),
      // Menggunakan IndexedStack agar state setiap halaman tetap terjaga
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Pelanggan'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _showAddOrderDialog,
              child: const Icon(Icons.add),
              tooltip: 'Catat Pesanan',
            )
          : null,
    );
  }

  // --- LOGIKA UNTUK MENAMPILKAN DIALOG ---

  void _showAddOrderDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddOrderDialog(
        onSubmit: ({
          required String customerName,
          required int gallonQuantity,
          String? otherItems,
          String? address,
          String? phoneNumber,
          required DateTime date,
        }) async {
          // Gabungkan tanggal dari dialog dengan waktu saat ini jika jam 00:00
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
  }
}