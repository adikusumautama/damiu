// ======================================================================
// FILE: lib/screens/home/karyawan_home_screen.dart
// ======================================================================
// FOKUS: File utama yang sekarang lebih ringkas, berisi logika state
// dan menyusun widget-widget yang sudah dipecah.

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:damiu/models/daily_sale_model.dart';
import 'package:damiu/models/daily_stock_model.dart';
import 'package:damiu/models/order_model.dart';
import 'package:damiu/models/user_model.dart';
import 'package:damiu/screens/other/customer_book_screen.dart';
import 'package:damiu/screens/other/karyawan_profile_screen.dart';
import 'package:damiu/screens/other/local_sales_management_screen.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:damiu/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart'; // Impor rxdart untuk CombineLatestStream

// Impor widget-widget baru
import 'widgets/stock_info_card.dart';
import 'widgets/home_action_buttons.dart';
import 'widgets/order_list_view.dart';

class KaryawanHomeScreen extends StatefulWidget {
  const KaryawanHomeScreen({super.key});

  @override
  State<KaryawanHomeScreen> createState() => _KaryawanHomeScreenState();
}

class _KaryawanHomeScreenState extends State<KaryawanHomeScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  UserModel? _currentUserModel;
  final AuthService _authService = AuthService();
  final SyncService _syncService = SyncService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  late List<Widget> _widgetOptions;

  static const List<String> _appBarTitles = <String>[
    'Beranda',
    'Buku Pelanggan',
    'Profil Saya',
  ];

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      const KaryawanBerandaContent(),
      const CustomerBookScreen(),
      const KaryawanProfileScreen(),
    ];
    _initializeConnectivity();
    _loadCurrentUser();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _performFullSync();
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = _authService.getCurrentUser();
    if (user != null) {
      final userModel = await _authService.getUserModel(user.uid);
      if (mounted) {
        setState(() => _currentUserModel = userModel);
      }
    }
  }

  Future<void> _initializeConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _updateConnectionStatus(result);
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    final hasConnection = !result.contains(ConnectivityResult.none);
    if (hasConnection) {
      _performFullSync();
    } else {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anda sedang offline.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _performFullSync() async {
    await _syncService.syncAllData();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_appBarTitles[_selectedIndex])),
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            UserAccountsDrawerHeader(
              accountName: Text(_currentUserModel?.name ?? 'Karyawan', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              accountEmail: Text(_currentUserModel?.email ?? 'Memuat...'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  _currentUserModel?.name?.substring(0, 1).toUpperCase() ?? 'K',
                  style: const TextStyle(fontSize: 40.0),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.storage_outlined),
              title: const Text('Kelola Data Lokal'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text("Kelola Data Lokal")),
                      body: const LocalSalesManagementWidget(),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.book_outlined), label: 'Pelanggan'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        onTap: _onItemTapped,
      ),
    );
  }
}

// =================================================
// KONTEN BERANDA KARYAWAN (inti dari file ini)
// =================================================

class KaryawanBerandaContent extends StatefulWidget {
  const KaryawanBerandaContent({super.key});
  @override
  State<KaryawanBerandaContent> createState() => _KaryawanBerandaContentState();
}

class _KaryawanBerandaContentState extends State<KaryawanBerandaContent>
    with WidgetsBindingObserver {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  late DateTime _today;
  late Stream<List<Order>> _ordersStream;
  late Stream<DailyStock?> _stockStream;
  late Stream<DailySale> _dailySaleStream;
  late Stream<int> _returnedGallonsStream;

  bool _isLoading = true;
  bool _isDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    _initializeStreams();
    _checkAndCarryOverStock();
  }
  
  void _initializeStreams() {
    setState(() {
      _stockStream = _firestoreService.getDailyStockStream(_today);
      _ordersStream = _firestoreService.getTodaysOrdersStream();
      _dailySaleStream = _firestoreService.getTodaysDailySaleStream();
      _returnedGallonsStream = _firestoreService.getTodaysReturnedGallonsStream();
      _isLoading = false;
    });
  }
  
  Future<void> _refreshData() async {
    _initializeStreams();
    await _checkAndCarryOverStock();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      final currentDate = DateTime(now.year, now.month, now.day);
      if (_today.isBefore(currentDate)) {
        print("Hari telah berganti. Memuat ulang data untuk hari ini...");
        setState(() {
          _today = currentDate;
          _isLoading = true; // Show loading indicator while re-initializing
        });
        _initializeStreams();
        _checkAndCarryOverStock();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkAndCarryOverStock() async {
    final todayStock = await _firestoreService.getDailyStockOnce(_today);

    if (todayStock == null) {
      final yesterday = _today.subtract(const Duration(days: 1));
      final yesterdayStock = await _firestoreService.getDailyStockOnce(yesterday);
      final String? uid = _authService.getCurrentUser()?.uid;

      if (uid != null) {
        int initialStock = yesterdayStock?.currentStock ?? 0;
        await _firestoreService.setInitialStock(
          date: _today,
          filledStock: initialStock,
          emptyStock: 0,
          updatedByUid: uid,
        );
        
        if (yesterdayStock == null && mounted && !_isDialogShown) {
          _isDialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showSetInitialStockDialog(0);
          });
        }
      }
    }
  }

  Future<void> _showSetInitialStockDialog(int currentFilledStock) async {
    final TextEditingController filledStockController = TextEditingController(
        text: currentFilledStock > 0 ? currentFilledStock.toString() : '');
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Atur Stok Awal Galon Hari Ini'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: ListBody(
                children: <Widget>[
                  const Text('Masukkan jumlah galon isi yang tersedia di awal hari kerja.'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: filledStockController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah Stok Awal',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Stok awal tidak boleh kosong';
                      if (int.tryParse(value) == null || int.parse(value) < 0) return 'Masukkan angka yang valid';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Simpan'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final int filledStock = int.parse(filledStockController.text);
                  final String? uid = _authService.getCurrentUser()?.uid;
                  if (uid != null) {
                    await _firestoreService.setInitialStock(
                        date: _today, filledStock: filledStock, emptyStock: 0, updatedByUid: uid);
                    if (mounted) Navigator.of(context).pop();
                  }
                }
              },
            ),
            if (currentFilledStock > 0)
              TextButton(child: const Text('Batal'), onPressed: () => Navigator.of(context).pop()),
          ],
        );
      },
    ).then((_) {
      _isDialogShown = false;
    });
  }

  Future<void> _startDelivery(Order order) async {
    if (order.firestoreId != null) {
      final error = await _firestoreService.updateOrderStatus(order.firestoreId!, OrderStatus.inDelivery);
      if (mounted && error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memulai pengantaran: $error')));
      }
    }
  }

  Future<void> _completeDelivery(Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selesaikan Pengantaran'),
        content: Text('Yakin pesanan untuk ${order.customerName} sudah selesai diantar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ya, Selesai')),
        ],
      ),
    );

    if (confirm == true) {
      final error = await _firestoreService.completeOrderTransaction(order);
      if (mounted && error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyelesaikan pesanan: $error')),
        );
      }
      // No need for success message, UI will update automatically from stream
    }
  }

  Future<void> _cancelOrder(Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan Pesanan'),
        content: Text('Yakin ingin membatalkan dan menghapus pesanan untuk ${order.customerName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Tidak')),
          FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Ya, Batalkan')),
        ],
      ),
    );

    if (confirm == true && order.firestoreId != null) {
      await _firestoreService.deleteOrder(order.firestoreId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return StreamBuilder<List<dynamic>>(
      stream: CombineLatestStream.list([
        _ordersStream,
        _dailySaleStream,
        _stockStream,
        _returnedGallonsStream,
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error memuat data: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("Tidak ada data tersedia."));
        }

        final allTodaysOrders = snapshot.data![0] as List<Order>;
        final todaysSale = snapshot.data![1] as DailySale;
        final dailyStock = snapshot.data![2] as DailyStock?;
        final totalGallonsInToday = snapshot.data![3] as int;

        final pendingOrders = allTodaysOrders.where((o) => o.status == OrderStatus.pending).toList();
        final inDeliveryOrders = allTodaysOrders.where((o) => o.status == OrderStatus.inDelivery).toList();
        final completedOrders = allTodaysOrders.where((o) => o.status == OrderStatus.delivered).toList();

        return DefaultTabController(
          length: 3,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StockInfoCard(
                          stock: dailyStock,
                          totalOut: todaysSale.quantity,
                          totalIn: totalGallonsInToday,
                          deliveryCount: todaysSale.deliveryCount,
                          onEditPressed: () => _showSetInitialStockDialog(dailyStock?.initialStock ?? 0),
                        ),
                        const SizedBox(height: 16),
                        const HomeActionButtons(),
                        const Divider(height: 32, thickness: 1),
                        const Text('Daftar Pesanan Hari Ini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      tabs: [
                        Tab(text: 'Belum Diantar (${pendingOrders.length})'),
                        Tab(text: 'Diantar (${inDeliveryOrders.length})'),
                        Tab(text: 'Selesai (${completedOrders.length})'),
                      ],
                    ),
                  ),
                  pinned: true,
                ),
              ];
            },
            body: TabBarView(
              children: [
                OrderListView(
                  orders: pendingOrders,
                  emptyMessage: 'Tidak ada pesanan yang perlu diantar.',
                  onRefresh: _refreshData,
                  onStartDelivery: _startDelivery,
                  onCompleteDelivery: _completeDelivery,
                  onCancelOrder: _cancelOrder,
                ),
                OrderListView(
                  orders: inDeliveryOrders,
                  emptyMessage: 'Tidak ada pesanan yang sedang diantar.',
                  onRefresh: _refreshData,
                  onStartDelivery: _startDelivery,
                  onCompleteDelivery: _completeDelivery,
                  onCancelOrder: _cancelOrder,
                ),
                OrderListView(
                  orders: completedOrders,
                  emptyMessage: 'Belum ada pesanan yang selesai hari ini.',
                  onRefresh: _refreshData,
                  onStartDelivery: _startDelivery,
                  onCompleteDelivery: _completeDelivery,
                  onCancelOrder: _cancelOrder,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Helper class for the sticky TabBar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1.0)),
      ),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return true;
  }
}