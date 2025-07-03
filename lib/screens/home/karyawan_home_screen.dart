// lib/screens/home/karyawan_home_screen.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:damiu/models/daily_stock_model.dart';
import 'package:damiu/models/order_model.dart';
import 'package:damiu/models/user_model.dart';
import 'package:damiu/screens/other/customer_book_screen.dart';
import 'package:damiu/screens/other/daily_sales_input_screen.dart';
import 'package:damiu/screens/other/empty_gallon_input_screen.dart';
import 'package:damiu/screens/other/karyawan_profile_screen.dart';
import 'package:damiu/screens/other/local_sales_management_screen.dart'
    hide Padding, SizedBox;
import 'package:damiu/screens/other/order_input_screen.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/services/database_helper.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:damiu/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
  bool _isDailySyncing = false;
  final SyncService _syncService = SyncService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOffline = false;

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
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      print("[KaryawanHomeScreen] App Resumed");
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = _authService.getCurrentUser();
    if (user != null) {
      final userModel = await _authService.getUserModel(user.uid);
      if (mounted) {
        setState(() {
          _currentUserModel = userModel;
        });
      }
    }
  }

  Future<void> _initializeConnectivity() async {
    final initialConnection = await Connectivity().checkConnectivity();
    if (initialConnection.contains(ConnectivityResult.none)) {
      setState(() {
        _isOffline = true;
      });
    }
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    final hasConnection = !result.contains(ConnectivityResult.none);
    if (!hasConnection && !_isOffline) {
      setState(() => _isOffline = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Anda saat ini sedang offline. Data akan disimpan di perangkat.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } else if (hasConnection && _isOffline) {
      setState(() => _isOffline = false);
      _performFullSync();
    }
  }

  Future<void> _performFullSync() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      print("Sync skipped: No internet connection.");
      return;
    }
    setState(() {
      _isDailySyncing = true;
    });
    await _syncService.syncAllUnsummarizedDeliveryLogs();
    await _syncService.syncCustomers();
    if (mounted) {
      setState(() {
        _isDailySyncing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda sudah online. Data telah disinkronkan.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    }
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
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              child: _currentUserModel == null
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentUserModel!.name ?? 'Karyawan',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentUserModel!.email,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
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
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_outlined),
            label: 'Pelanggan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        onTap: _onItemTapped,
      ),
    );
  }
}

class KaryawanBerandaContent extends StatefulWidget {
  const KaryawanBerandaContent({
    super.key,
  });
  @override
  State<KaryawanBerandaContent> createState() => _KaryawanBerandaContentState();
}

class _KaryawanBerandaContentState extends State<KaryawanBerandaContent>
    with WidgetsBindingObserver {
  final FirestoreService _firestoreService = FirestoreService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AuthService _authService = AuthService();

  late DateTime _today;
  late Stream<List<Order>> _ordersStream;

  int _totalGallonsOut = 0;
  int _totalGallonsIn = 0;
  int _deliveryCountToday = 0;
  bool _isLoading = true;
  bool _isDialogShown = false;
  Stream<DailyStock?>? _firestoreStockStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    _initializeAndLoadData();
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
        });
        _initializeAndLoadData();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeAndLoadData() async {
    setState(() {
      _firestoreStockStream = _firestoreService.getDailyStockStream(_today);
      _ordersStream = _firestoreService.getTodaysOrdersStream();
      _isLoading = true;
    });
    await _loadDeliveryStats();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDeliveryStats() async {
    final localLogs = await _dbHelper.getAllDeliveryLogsForDate(_today);
    final totalOut = localLogs.fold<int>(0, (sum, log) => sum + log.gallons);
    final totalIn =
        localLogs.fold<int>(0, (sum, log) => sum + log.emptyGallonsReturned);
    final deliveryCount =
        localLogs.where((log) => !log.isNoDeliveryMarker).length;

    if (mounted) {
      setState(() {
        _totalGallonsOut = totalOut;
        _totalGallonsIn = totalIn;
        _deliveryCountToday = deliveryCount;
      });
    }
  }

  Future<void> _syncLocalOrders(List<Order> firestoreOrders) async {
    await _dbHelper.deleteTodaysOrders();
    for (final order in firestoreOrders) {
      await _dbHelper.insertOrder(order);
    }
    print("Sinkronisasi pesanan lokal selesai.");
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
                  const Text(
                      'Masukkan jumlah galon isi yang tersedia di awal hari kerja.'),
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
                      if (value == null || value.isEmpty) {
                        return 'Stok awal tidak boleh kosong';
                      }
                      if (int.tryParse(value) == null ||
                          int.parse(value) < 0) {
                        return 'Masukkan angka yang valid';
                      }
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
                  final int filledStock =
                      int.parse(filledStockController.text);
                  final String? uid = _authService.getCurrentUser()?.uid;

                  if (uid != null) {
                    _firestoreService
                        .setInitialStock(
                      date: _today,
                      filledStock: filledStock,
                      emptyStock: 0,
                      updatedByUid: uid,
                    )
                        .then((error) {
                      if (mounted && error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Gagal sinkronisasi stok ke server: $error')),
                        );
                      }
                    });
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  }
                }
              },
            ),
            if (currentFilledStock > 0)
              TextButton(
                child: const Text('Batal'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
          ],
        );
      },
    ).then((_) {
      _isDialogShown = false;
    });
  }

  Future<void> _startDelivery(Order order) async {
    if (order.firestoreId != null) {
      final error = await _firestoreService.updateOrderStatus(
          order.firestoreId!, OrderStatus.inDelivery);
      if (mounted && error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memulai pengantaran: $error')),
        );
      }
    }
  }

  Future<void> _completeDelivery(Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selesaikan Pengantaran'),
        content: Text(
            'Yakin pesanan untuk ${order.customerName} sudah selesai diantar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Selesai'),
          ),
        ],
      ),
    );

    if (confirm == true && order.firestoreId != null) {
      final error = await _firestoreService.updateOrderStatus(
          order.firestoreId!, OrderStatus.delivered,
          setDeliveredTime: true);
      if (mounted) {
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Gagal memperbarui status pesanan: $error')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Pesanan untuk ${order.customerName} selesai.')),
          );
        }
      }
    }
  }

  Future<void> _cancelOrder(Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan Pesanan'),
        content: Text(
            'Yakin ingin membatalkan dan menghapus pesanan untuk ${order.customerName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tidak'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirm == true && order.firestoreId != null) {
      final error = await _firestoreService.deleteOrder(order.firestoreId!);
      if (mounted) {
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Gagal membatalkan pesanan di server: $error')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Pesanan untuk ${order.customerName} telah dibatalkan.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : StreamBuilder<List<Order>>(
            stream: _ordersStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
                 return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text("Error memuat pesanan: ${snapshot.error}"));
              }

              final allTodaysOrders = snapshot.data ?? [];

              final activeOrders = allTodaysOrders
                  .where((o) =>
                      o.status == OrderStatus.pending ||
                      o.status == OrderStatus.inDelivery)
                  .toList();
              final completedOrders = allTodaysOrders
                  .where((o) => o.status == OrderStatus.delivered)
                  .toList();

              return FutureBuilder(
                  future: _syncLocalOrders(allTodaysOrders),
                  builder: (context, syncSnapshot) {
                    return DefaultTabController(
                      length: 2,
                      child: NestedScrollView(
                        headerSliverBuilder: (context, innerBoxIsScrolled) {
                          return [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildStockInfoCardStream(),
                                    const SizedBox(height: 16),
                                    _buildActionButtons(),
                                    const Divider(height: 32, thickness: 1),
                                    const Text(
                                      'Daftar Pesanan Hari Ini',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SliverPersistentHeader(
                              delegate: _SliverAppBarDelegate(
                                TabBar(
                                  tabs: [
                                    Tab(
                                        text:
                                            'Perlu Diantar (${activeOrders.length})'),
                                    Tab(
                                        text:
                                            'Selesai (${completedOrders.length})'),
                                  ],
                                ),
                              ),
                              pinned: true,
                            ),
                          ];
                        },
                        body: TabBarView(
                          children: [
                            _buildOrderListView(activeOrders,
                                emptyMessage:
                                    'Tidak ada pesanan yang perlu diantar saat ini.'),
                            _buildOrderListView(completedOrders,
                                emptyMessage:
                                    'Belum ada pesanan yang selesai.'),
                          ],
                        ),
                      ),
                    );
                  });
            },
          );
  }

  Widget _buildStockInfoCardStream() {
    return StreamBuilder<DailyStock?>(
      stream: _firestoreStockStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !_isLoading) {
          return const LinearProgressIndicator();
        }
        final dailyStock = snapshot.data;
        if (!snapshot.hasData && !_isDialogShown && !_isLoading) {
          _isDialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showSetInitialStockDialog(0);
          });
        }

        return _buildStockInfoCard(dailyStock, _totalGallonsOut,
            _totalGallonsIn, _deliveryCountToday);
      },
    );
  }

  Widget _buildOrderListView(List<Order> orders,
      {required String emptyMessage}) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _initializeAndLoadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height / 2.5,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  emptyMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _initializeAndLoadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return _buildOrderItemCard(order);
        },
      ),
    );
  }

  Card _buildOrderItemCard(Order order) {
    Color getStatusColor(String status) {
      switch (status) {
        case OrderStatus.delivered:
          return Colors.green;
        case OrderStatus.inDelivery:
          return Colors.orange;
        case OrderStatus.pending:
        default:
          return Colors.blue;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    order.customerName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    order.status,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: getStatusColor(order.status),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const Divider(),
            _buildDetailRow(
                Icons.local_drink_outlined, '${order.gallonQuantity} Galon'),
            if (order.otherItems != null && order.otherItems!.isNotEmpty)
              _buildDetailRow(
                  Icons.add_shopping_cart_outlined, order.otherItems!),
            if (order.address != null && order.address!.isNotEmpty)
              _buildDetailRow(Icons.location_on_outlined, order.address!),
            if (order.phoneNumber != null && order.phoneNumber!.isNotEmpty)
              _buildDetailRow(Icons.phone_outlined, order.phoneNumber!),
            const SizedBox(height: 8),
            _buildOrderActionButtons(order),
          ],
        ),
      ),
    );
  }

  Widget _buildStockInfoCard(
      DailyStock? stock, int totalOut, int totalIn, int deliveryCount) {
    final initialStock = stock?.initialStock ?? 0;
    final currentStock = initialStock - totalOut + totalIn;

    final Color stockColor;
    if (currentStock <= 0) {
      stockColor = Colors.red.shade800;
    } else if (currentStock <= 5) {
      stockColor = Colors.orange.shade800;
    } else {
      stockColor = Colors.green.shade800;
    }

    final lastUpdatedText = stock != null
        ? 'Diperbarui: ${DateFormat('dd MMM, HH:mm', 'id_ID').format(stock.lastUpdated)}'
        : 'Belum diatur hari ini';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pergerakan Stok Hari Ini',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showSetInitialStockDialog(initialStock),
                  tooltip: 'Ubah Stok Awal',
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildInfoRow('Jumlah Pengantaran', '$deliveryCount kali'),
            const Divider(thickness: 0.5, height: 20),
            _buildInfoRow('Stok Awal (Perkiraan)', '$initialStock Galon'),
            _buildInfoRow('Keluar (Dianter)', '-$totalOut Galon',
                valueColor: Colors.red.shade700),
            _buildInfoRow('Kembali (Diterima)', '+$totalIn Galon',
                valueColor: Colors.blue.shade700),
            const Divider(thickness: 0.5, height: 20),
            _buildInfoRow('Total Persediaan Saat Ini', '$currentStock Galon',
                isBold: true, valueColor: stockColor),
            if (currentStock > 0 && currentStock <= 5)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Center(
                  child: Text(
                    'Persediaan saat ini sangat menipis!',
                    style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Divider(thickness: 1, height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: Text(lastUpdatedText,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderActionButtons(Order order) {
    switch (order.status) {
      case OrderStatus.pending:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.local_shipping_outlined, size: 18),
              label: const Text('Mulai Antar'),
              onPressed: () => _startDelivery(order),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Batalkan'),
              onPressed: () => _cancelOrder(order),
              style:
                  TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            ),
          ],
        );
      case OrderStatus.inDelivery:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Selesaikan'),
              onPressed: () => _completeDelivery(order),
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade700),
            ),
          ],
        );
      case OrderStatus.delivered:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 18),
            const SizedBox(width: 4),
            Text(
              'Terkirim',
              style: TextStyle(
                  color: Colors.green.shade800, fontWeight: FontWeight.bold),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('Catat Pesanan Masuk'),
          onPressed: () {
            Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const OrderInputScreen()))
                .then((saved) {
              if (saved == true) {
                // Tidak perlu refresh manual, stream akan update otomatis
              }
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.add_chart),
          label: const Text('Input Penjualan Harian'),
          onPressed: () {
            Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const DailySalesInputScreen()))
                .then((_) {
              _loadDeliveryStats();
            });
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Input Galon Kosong Kembali'),
          onPressed: () {
            Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const EmptyGallonInputScreen()))
                .then((saved) {
              if (saved == true) {
                _loadDeliveryStats();
              }
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}