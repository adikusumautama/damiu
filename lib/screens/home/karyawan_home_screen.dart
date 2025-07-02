import 'dart:async';
import 'package:damiu/models/user_model.dart'; // Impor UserModel
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:damiu/models/order_model.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/services/sync_service.dart'; // Import SyncService
import 'package:damiu/models/daily_stock_model.dart';
import 'package:damiu/services/database_helper.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // Impor intl
import 'package:damiu/screens/other/local_sales_management_screen.dart' hide SizedBox, Padding; // Impor widget baru
import 'package:damiu/screens/other/daily_sales_input_screen.dart'; // Path baru
import 'package:damiu/screens/other/karyawan_profile_screen.dart'; // Impor layar profil
import 'package:damiu/screens/other/empty_gallon_input_screen.dart'; // Impor layar baru
import 'package:damiu/screens/other/customer_book_screen.dart'; // Impor layar buku pelanggan
import 'package:damiu/screens/other/order_input_screen.dart'; // Impor layar baru untuk pesanan

class KaryawanHomeScreen extends StatefulWidget {
  const KaryawanHomeScreen({super.key});

  @override
  State<KaryawanHomeScreen> createState() => _KaryawanHomeScreenState();
}

class _KaryawanHomeScreenState extends State<KaryawanHomeScreen>
    with WidgetsBindingObserver {
  // Tambahkan WidgetsBindingObserver
  int _selectedIndex = 0;
  UserModel? _currentUserModel;
  final AuthService _authService = AuthService();
// Tambahkan DatabaseHelper
  bool _isDailySyncing = false; // State untuk sinkronisasi harian
  final SyncService _syncService = SyncService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOffline = false; // To track the connection state

  late List<Widget> _widgetOptions;

  // Daftar judul AppBar untuk setiap tab
  static const List<String> _appBarTitles = <String>[
    'Beranda',
    'Buku Pelanggan',
    'Profil Saya',
  ];

  @override
  void initState() {
    super.initState();
    // Inisialisasi _widgetOptions di sini agar bisa meneruskan _loadTodaysStats
    _widgetOptions = <Widget>[
      const KaryawanBerandaContent(),
      const CustomerBookScreen(), // Tambahkan layar baru
      const KaryawanProfileScreen(),
    ];
    _initializeConnectivity();
    _loadCurrentUser();
    WidgetsBinding.instance.addObserver(this); // Daftarkan observer
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this); // Hapus observer
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Aplikasi kembali ke foreground, muat ulang statistik
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
    // Check initial connection status
    final initialConnection = await Connectivity().checkConnectivity();
    if (initialConnection.contains(ConnectivityResult.none)) {
      setState(() {
        _isOffline = true;
      });
    }

    // Listen for subsequent changes
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    final hasConnection = !result.contains(ConnectivityResult.none);
    if (!hasConnection && !_isOffline) {
      // We just went offline
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
      // We just came online
      setState(() => _isOffline = false);
      // Trigger automatic sync
      _performFullSync();
    }
  }

  Future<void> _performFullSync() async {
    // Check for connection before attempting to sync
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      print("Sync skipped: No internet connection.");
      return;
    }

    setState(() {
      _isDailySyncing = true;
    });

    // Perform syncs without showing individual SnackBars
    await _syncService.syncAllUnsummarizedDeliveryLogs();
    await _syncService.syncCustomers();

    if (mounted) {
      setState(() {
        _isDailySyncing = false;
      });
      // Show a single confirmation SnackBar after sync is complete
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
      if (index == 1) {
        _widgetOptions[1] = const CustomerBookScreen();
      }
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
                Navigator.pop(context); // Tutup drawer dulu
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
            // Tambahkan item lain di drawer jika perlu
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

// Widget untuk konten Beranda Karyawan
class KaryawanBerandaContent extends StatefulWidget {
  const KaryawanBerandaContent({
    super.key,
  });

  @override
  State<KaryawanBerandaContent> createState() => _KaryawanBerandaContentState();
}

class _KaryawanBerandaContentState extends State<KaryawanBerandaContent> {
  final FirestoreService _firestoreService = FirestoreService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AuthService _authService = AuthService();
  final DateTime _today =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  List<Order> _todaysOrders = [];
  List<Order> _filteredOrders = [];
  String _selectedStatusFilter = 'Semua'; // Default filter: 'Semua'
  int _allCount = 0, _pendingCount = 0, _inDeliveryCount = 0, _deliveredCount = 0;

  DailyStock? _dailyStock;
  int _totalGallonsOut = 0;
  int _totalGallonsIn = 0;
  int _deliveryCountToday = 0; // State baru untuk jumlah pengantaran
  bool _isLoading = true;

  // Kunci untuk memastikan dialog hanya muncul sekali
  final GlobalKey _dialogKey = GlobalKey();
  bool _isDialogShown = false;  

  Future<void> _showSetInitialStockDialog(int currentFilledStock) async {
    final TextEditingController filledStockController =
        TextEditingController(text: currentFilledStock > 0 ? currentFilledStock.toString() : '');
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          key: _dialogKey,
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
                  final int filledStock = int.parse(filledStockController.text);
                  final String? uid = _authService.getCurrentUser()?.uid;
                  
                  if (uid != null) {
                    // Buat objek stok
                    final newStock = DailyStock(
                      id: DateFormat('yyyy-MM-dd').format(_today),
                      initialStock: filledStock,
                      initialEmptyStock: 0, // Selalu 0
                      lastUpdated: DateTime.now(),
                      updatedByUid: uid,
                    );
                    // Simpan ke DB lokal terlebih dahulu untuk kapabilitas offline
                    await _dbHelper.upsertDailyStock(newStock);
                    // Kemudian, coba simpan ke Firestore (jangan blokir UI)
                    _firestoreService.setInitialStock(
                      date: _today,
                      filledStock: filledStock,
                      emptyStock: 0, // Selalu 0
                      updatedByUid: uid,
                    ).then((error) {
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
                      // Muat ulang data dari lokal untuk memperbarui UI
                      _loadOfflineData();
                    }
                  }
                }
              },
            ),
            if (currentFilledStock > 0) // Tampilkan tombol Batal hanya jika sudah ada stok
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
      // Tandai bahwa dialog telah ditutup
      _isDialogShown = false;
    });
  }

  Widget _buildStockInfoCard(DailyStock? stock, int totalOut, int totalIn, int deliveryCount) {
    final initialStock = stock?.initialStock ?? 0;
    final currentStock = initialStock - totalOut + totalIn;
    final stockDifference = currentStock - initialStock;

    // Tentukan warna dinamis untuk teks stok saat ini
    final Color stockColor;
    if (currentStock <= 0) {
      stockColor = Colors.red.shade800;
    } else if (currentStock <= 5) {
      stockColor = Colors.orange.shade800;
    } else {
      stockColor = Colors.green.shade800;
    }

    // Tentukan kapan terakhir stok awal diupdate
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
            // --- Bagian Galon Isi ---
            _buildInfoRow('Jumlah Pengantaran', '$deliveryCount kali'),
            const Divider(thickness: 0.5, height: 20),
            _buildInfoRow('Stok Awal (Perkiraan)', '$initialStock Galon'),
            _buildInfoRow('Keluar (Dianter)', '-$totalOut Galon', valueColor: Colors.red.shade700),
            _buildInfoRow('Kembali (Diterima)', '+$totalIn Galon', valueColor: Colors.blue.shade700),
            const Divider(thickness: 0.5, height: 20),
            _buildInfoRow('Total Persediaan Saat Ini', '$currentStock Galon', isBold: true, valueColor: stockColor),
            
            // Pesan khusus jika stok menipis
            if (currentStock > 0 && currentStock <= 5)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Center(
                  child: Text(
                    'Persediaan saat ini sangat menipis!',
                    style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // Pesan khusus jika stok akhir melebihi stok awal
            if (stockDifference > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(
                  'Ada lebih +$stockDifference galon masuk, sehingga total persediaan sekarang adalah $currentStock.',
                  style: TextStyle(color: Colors.green.shade900, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
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

  @override
  void initState() {
    super.initState();
    _loadOfflineData();
  }

  void _updateFilterCounts() {
    _allCount = _todaysOrders.length;
    _pendingCount =
        _todaysOrders.where((o) => o.status == OrderStatus.pending).length;
    _inDeliveryCount =
        _todaysOrders.where((o) => o.status == OrderStatus.inDelivery).length;
    _deliveredCount =
        _todaysOrders.where((o) => o.status == OrderStatus.delivered).length;
  }

  void _filterOrders() {
    if (!mounted) return;
    setState(() {
      if (_selectedStatusFilter == 'Semua') {
        _filteredOrders = List.from(_todaysOrders);
      } else {
        _filteredOrders = _todaysOrders
            .where((order) => order.status == _selectedStatusFilter)
            .toList();
      }
    });
  }

  Future<void> _loadOfflineData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    // 1. Dapatkan stok awal dari DB lokal
    final String todayDocId = DateFormat('yyyy-MM-dd').format(_today);
    final stockData = await _dbHelper.getDailyStock(todayDocId);

    // 2. Dapatkan log pengantaran hari ini dari DB lokal
    final localLogs = await _dbHelper.getAllDeliveryLogsForDate(_today);
    final totalOut = localLogs.fold<int>(0, (sum, log) => sum + log.gallons);
    final totalIn = localLogs.fold<int>(0, (sum, log) => sum + log.emptyGallonsReturned);

    // 3. Dapatkan daftar pesanan hari ini dari DB lokal
    final orders = await _dbHelper.getTodaysOrders();

    // Hitung jumlah pengantaran yang valid (bukan marker "tidak ada pengantaran")
    final deliveryCount = localLogs.where((log) => !log.isNoDeliveryMarker).length;

    if (mounted) {
      setState(() {
        _dailyStock = stockData;
        _totalGallonsOut = totalOut;
        _totalGallonsIn = totalIn;
        _deliveryCountToday = deliveryCount;
        _todaysOrders = orders;
        _updateFilterCounts();
        _filterOrders(); // Apply the current filter
        _isLoading = false;
      });

      // Jika stok belum diatur untuk hari ini dan dialog belum pernah ditampilkan,
      // tampilkan dialog secara otomatis.
      if (stockData == null && !_isDialogShown) {
        _isDialogShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showSetInitialStockDialog(0);
        });
      }
    }
  }

  Widget _buildFilterChips() {
    Widget buildChip(String label, int count) {
      final isSelected = _selectedStatusFilter == label;
      return Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: ChoiceChip(
          label: Text('$label ($count)'),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _selectedStatusFilter = label;
                _filterOrders();
              });
            }
          },
          selectedColor: Theme.of(context).primaryColor,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          backgroundColor: Colors.grey[200],
          shape: StadiumBorder(
            side: BorderSide(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey[400]!,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          buildChip('Semua', _allCount),
          buildChip(OrderStatus.pending, _pendingCount),
          buildChip(OrderStatus.inDelivery, _inDeliveryCount),
          buildChip(OrderStatus.delivered, _deliveredCount),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadOfflineData,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStockInfoCard(_dailyStock, _totalGallonsOut,
                            _totalGallonsIn, _deliveryCountToday),
                        const SizedBox(height: 16),
                        _buildActionButtons(),
                        const Divider(height: 32, thickness: 1),
                        const Text(
                          'Daftar Pesanan Hari Ini',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        _buildFilterChips(),
                      ],
                    ),
                  ),
                ),
                _buildOrderListSliver(),
              ],
            ),
          );
  }

  Widget _buildOrderListSliver() {
    // A helper to get color based on status
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

    if (_filteredOrders.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48.0, horizontal: 16.0),
          child: Center(
            child: Text(
              _todaysOrders.isEmpty
                  ? 'Belum ada pesanan yang dicatat hari ini.\nTarik ke bawah untuk memuat ulang.'
                  : 'Tidak ada pesanan dengan status "$_selectedStatusFilter".',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) { // Use _filteredOrders
        final order = _filteredOrders[index];
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
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                      backgroundColor: getStatusColor(order.status),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                const Divider(),
                _buildDetailRow(Icons.local_drink_outlined,
                    '${order.gallonQuantity} Galon'),
                if (order.otherItems != null && order.otherItems!.isNotEmpty)
                  _buildDetailRow(
                      Icons.add_shopping_cart_outlined, order.otherItems!),
                if (order.address != null && order.address!.isNotEmpty)
                  _buildDetailRow(Icons.location_on_outlined, order.address!),
                if (order.phoneNumber != null &&
                    order.phoneNumber!.isNotEmpty)
                  _buildDetailRow(Icons.phone_outlined, order.phoneNumber!),
                const SizedBox(height: 8),
                _buildOrderActionButtons(order),
              ],
            ),
          ),
        );
          }, // Use _filteredOrders
          childCount: _filteredOrders.length,
        ),
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
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Batalkan'),
              onPressed: () => _cancelOrder(order),
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
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

    if (confirm == true && order.id != null) {
      await _dbHelper.updateOrderStatus(order.id!, OrderStatus.delivered,
          setDeliveredTime: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Pesanan untuk ${order.customerName} selesai.')),
        );
        _loadOfflineData();
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

    if (confirm == true && order.id != null) {
      await _dbHelper.deleteOrder(order.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Pesanan untuk ${order.customerName} dibatalkan.')),
        );
        _loadOfflineData();
      }
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
            Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const OrderInputScreen()))
                .then((saved) {
              if (saved == true) {
                _loadOfflineData(); // Muat ulang data untuk memperbarui daftar pesanan (langkah berikutnya)
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
            Navigator.push(context, MaterialPageRoute(builder: (context) => const DailySalesInputScreen()))
                .then((_) {
              _loadOfflineData(); // Muat ulang data setelah kembali dari input penjualan
            });
          },
          style: ElevatedButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(vertical: 16), // Tambah padding vertikal
            textStyle: const TextStyle(fontSize: 16), // Ukuran teks tombol
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Input Galon Kosong Kembali'),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const EmptyGallonInputScreen()))
                .then((saved) {
              if (saved == true) {
                _loadOfflineData(); // Muat ulang data jika ada data yang disimpan
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
