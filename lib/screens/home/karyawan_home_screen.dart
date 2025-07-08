// lib/screens/home/karyawan_home_screen.dart

import 'dart:async';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:damiu/models/order_model.dart';
import 'package:damiu/models/user_model.dart';
import 'package:damiu/models/daily_stock_model.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:damiu/screens/home/widgets/add_order_dialog.dart';
import 'package:damiu/screens/home/widgets/order_summary.dart';
import 'package:damiu/screens/home/widgets/orders_list.dart';
import 'package:damiu/screens/home/widgets/resource_board.dart';
import 'package:damiu/screens/home/widgets/profile_section.dart';
import 'package:damiu/screens/home/widgets/customer_book.dart';
import 'package:damiu/main.dart' show resetDailyStockIfNeeded;

class KaryawanHomeViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  int _selectedIndex = 0;
  bool _isOnline = true;
  UserModel? _currentUser;
  String _selectedStatus = 'Semua';
  late StreamSubscription _connectivitySubscription;

  // --- State untuk menampilkan Snackbar Konektivitas ---
  String? _snackBarMessage;
  Color? _snackBarColor;

  // --- State untuk Input Galon Kosong ---
  final GlobalKey<FormState> _emptyGallonFormKey = GlobalKey<FormState>();
  final TextEditingController _gallonQuantityController = TextEditingController();
  String? _emptyGallonSnackBarMessage;
  Color? _emptyGallonSnackBarColor;

  int get selectedIndex => _selectedIndex;
  bool get isOnline => _isOnline;
  UserModel? get currentUser => _currentUser;
  String get selectedStatus => _selectedStatus;
  String? get snackBarMessage => _snackBarMessage;
  Color? get snackBarColor => _snackBarColor;

  void clearSnackBar() {
    _snackBarMessage = null;
    _snackBarColor = null;
  }
  
  void clearEmptyGallonSnackBar() {
    _emptyGallonSnackBarMessage = null;
    _emptyGallonSnackBarColor = null;
  }

  String? get emptyGallonSnackBarMessage => _emptyGallonSnackBarMessage;
  Color? get emptyGallonSnackBarColor => _emptyGallonSnackBarColor;

  KaryawanHomeViewModel() {
    _init();
  }

  void _init() async {
    await _loadCurrentUser();
    _initConnectivity();
    await resetDailyStockIfNeeded(
      isOnline: _isOnline,
      employeeUid: _currentUser?.uid,
      activeDate: DateTime.now(),
    );
    if (hasListeners) notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _gallonQuantityController.dispose();
    super.dispose();
  }

  void _initConnectivity() {
    Connectivity().checkConnectivity().then(
      (r) => _updateConnectionStatus(r, isInitial: true),
    );
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  Future<void> _updateConnectionStatus(
    List<ConnectivityResult> results, {
    bool isInitial = false,
  }) async {
    final currentlyOnline =
        results.isNotEmpty && results.first != ConnectivityResult.none;
    if (currentlyOnline == _isOnline && !isInitial) return;

    _isOnline = currentlyOnline;
    if (hasListeners) {
      _snackBarMessage = _isOnline
          ? 'Semua data akan disinkronkan secara otomatis.'
          : 'Anda sekarang offline. Perubahan akan disimpan di perangkat.';
      _snackBarColor = _isOnline ? Colors.green : Colors.orange[800];
    }

    notifyListeners();
  }

  Future<void> _loadCurrentUser() async {
    final user = _authService.getCurrentUser();
    if (user != null) _currentUser = await _authService.getUserModel(user.uid);
    if (hasListeners) notifyListeners();
  }

  void onItemTapped(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  void onFilterChanged(String newStatus) {
    _selectedStatus = newStatus;
    notifyListeners();
  }

  Future<String?> onUpdateOrder(String firestoreId, Order updatedOrder) async =>
      await _firestoreService.updateOrder(firestoreId, updatedOrder);
  Future<String?> onDeleteOrder(String firestoreId) async =>
      await _firestoreService.deleteOrder(firestoreId);
  Future<String?> onStartDelivery(Order order) async =>
      (order.firestoreId == null)
      ? "Order ID tidak valid."
      : await _firestoreService.updateOrderStatus(
          order.firestoreId!,
          OrderStatus.inDelivery,
        );
  // Cukup panggil metode batched, Firestore akan menanganinya baik online maupun offline.
  Future<String?> onCompleteDelivery(Order order) async =>
      await _firestoreService.completeOrderBatched(order);

  Future<void> onAddOrder({
    required String customerName,
    required int gallonQuantity,
    String? otherItems,
    String? address,
    String? phoneNumber,
    required DateTime date,
  }) async {
    final now = DateTime.now();
    final finalDateTime = (date.hour == 0 && date.minute == 0)
        ? DateTime(
            date.year,
            date.month,
            date.day,
            now.hour,
            now.minute,
            now.second,
          )
        : date;
    final newOrder = Order(
      customerName: customerName,
      gallonQuantity: gallonQuantity,
      otherItems: otherItems,
      address: address,
      phoneNumber: phoneNumber,
      status: OrderStatus.pending,
      createdAt: finalDateTime,
      employeeUid: _currentUser?.uid,
      isSynced: true, // Selalu true, biarkan Firestore yang menangani antrean offline
    );
    // Cukup panggil metode Firestore, SDK akan menangani caching & antrean offline.
    await _firestoreService.addOrderAndUpsertCustomer(newOrder);
    notifyListeners();
  }

  // --- FUNGSI BARU: Menyimpan Galon Kosong ---
  void saveEmptyGallons() {
    if (!_emptyGallonFormKey.currentState!.validate()) return;

    final employeeUid = _currentUser?.uid;

    // Validasi penting: Pastikan UID karyawan tersedia sebelum melanjutkan.
    if (employeeUid == null) {
      _emptyGallonSnackBarMessage = 'Error: Pengguna tidak ditemukan. Coba lagi.';
      _emptyGallonSnackBarColor = Colors.red;
      notifyListeners();
      return;
    }

    final quantity = int.parse(_gallonQuantityController.text);

    // Beri feedback ke pengguna secepatnya dan bersihkan input.
    // Operasi database akan berjalan di latar belakang.
    _gallonQuantityController.clear();
    _emptyGallonSnackBarMessage =
        'Berhasil! Data akan disinkronkan saat kembali online.';
    _emptyGallonSnackBarColor = Colors.green;
    notifyListeners();

    // Jalankan operasi Firestore di latar belakang.
    // SDK Firestore akan menangani antrean saat offline secara otomatis.
    _firestoreService.incrementEmptyStock(
      quantity: quantity,
      updatedByUid: employeeUid,
    );
    _firestoreService.addReturnedGallonLog(
        quantity: quantity,
        employeeUid: employeeUid,
    );
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
          // --- PERBAIKAN: Tampilkan Snackbar saat status koneksi berubah ---
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (viewModel.snackBarMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(viewModel.snackBarMessage!),
                backgroundColor: viewModel.snackBarColor,
              ));
              viewModel.clearSnackBar();
            }

            // --- PERBAIKAN: Tampilkan Snackbar untuk input galon kosong ---
            if (viewModel.emptyGallonSnackBarMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(viewModel.emptyGallonSnackBarMessage!),
                backgroundColor: viewModel.emptyGallonSnackBarColor,
              ));
              viewModel.clearEmptyGallonSnackBar();
            }
          });

          return Scaffold(
            appBar: AppBar(
              title: Text(_getAppBarTitle(viewModel.selectedIndex)),
              bottom: !viewModel.isOnline
                  ? PreferredSize(
                      preferredSize: const Size.fromHeight(24.0),
                      child: Container(
                        color: Colors.orange.shade700,
                        width: double.infinity,
                        padding: const EdgeInsets.all(4),
                        child: const Text(
                          'Mode Offline',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color.fromARGB(255, 79, 79, 79), fontSize: 12),
                        ),
                      ),
                    )
                  : null,
            ),
            body: IndexedStack(
              index: viewModel.selectedIndex,
              children: _buildBodyPages(context, viewModel),
            ),
            bottomNavigationBar: BottomNavigationBar(
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Beranda',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long_outlined),
                  label: 'Pesanan',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.book),
                  label: 'Pelanggan',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profil',
                ),
              ],
              currentIndex: viewModel.selectedIndex,
              onTap: viewModel.onItemTapped,
              // --- PERBAIKAN: Mengatur tipe agar warna ikon non-aktif terlihat ---
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Theme.of(context).primaryColor,
              unselectedItemColor: Colors.grey,
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

  String _getAppBarTitle(int index) =>
      ['Beranda', 'Daftar Pesanan', 'Buku Pelanggan', 'Profil'][index];

  // --- PERBAIKAN: Memisahkan halaman Beranda dan Pesanan ---
  List<Widget> _buildBodyPages(
    BuildContext context,
    KaryawanHomeViewModel viewModel,
  ) {
    // --- PERBAIKAN: Selalu gunakan StreamBuilder, Firestore menangani offline ---
    Widget summaryWidget = StreamBuilder<List<Order>>(
      stream: viewModel._firestoreService.getTodaysOrdersStream(),
      builder: (_, s) => OrderSummary(
        orders: s.data ?? [],
        isOnline: viewModel.isOnline,
      ),
    );

    Widget berandaPage = SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Card(
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  summaryWidget,
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  // --- PERBAIKAN: Selalu gunakan StreamBuilder ---
                  StreamBuilder<DailyStock?>(
                    stream: viewModel._firestoreService
                        .getDailyStockStream(DateTime.now()),
                    builder: (context, snapshot) =>
                        ResourceBoard(stock: snapshot.data),
                  ),
                ],
              ),
            ),
          ),
          _buildEmptyGallonInput(context, viewModel),
        ],
      ),
    );

    Widget pesananPage = Column(
      children: [
          _buildFilterChips(context, viewModel),
        Expanded(
          child: OrdersStreamWidget(
            status: viewModel.selectedStatus,
            onStartDelivery: (o) async {
              final e = await viewModel.onStartDelivery(o);
              if (context.mounted) _handleApiError(context, e);
            },
            onCompleteDelivery: (o) async {
              final e = await viewModel.onCompleteDelivery(o);
              if (context.mounted) _handleApiError(context, e);
            },
            onEdit: (o) => _showAddOrderDialog(
              context,
              viewModel,
              orderToEdit: o,
            ),
            onDelete: (o) => _showDeleteConfirmDialog(context, viewModel, o),
          ),
        ),
        ],
      );

    return [
      berandaPage,
      pesananPage,
      const CustomerBook(isOnline: true),
      ProfileSection(
        user: viewModel.currentUser,
        onLogout: () => _showLogoutConfirmDialog(context, viewModel),
      ),
    ];
  }


  // --- WIDGET BARU: Input Galon Kosong ---
  Widget _buildEmptyGallonInput(BuildContext context, KaryawanHomeViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: viewModel._emptyGallonFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Input Galon Kosong Kembali',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: viewModel._gallonQuantityController,
                  decoration: const InputDecoration(
                    labelText: 'Jumlah Galon',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.hourglass_empty_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == null || int.parse(v) <= 0)
                      ? 'Masukkan jumlah valid'
                      : null,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Simpan'),
                  onPressed: viewModel.saveEmptyGallons,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(
    BuildContext context,
    KaryawanHomeViewModel viewModel,
  ) {
    final statuses = [
      'Semua',
      OrderStatus.pending,
      OrderStatus.inDelivery,
      OrderStatus.delivered,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: statuses.map((status) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: FilterChip(
                shape: const StadiumBorder(),
                side: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                    width: 0.5),
                label: Text(status),
                selected: viewModel.selectedStatus == status,
                onSelected: (bool selected) {
                  if (selected) {
                    viewModel.onFilterChanged(status);
                  }
                },
                selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAddOrderDialog(
    BuildContext context,
    KaryawanHomeViewModel viewModel, {
    Order? orderToEdit,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AddOrderDialog(
        orderToEdit: orderToEdit,
        onSubmit:
            ({
              required customerName,
              required gallonQuantity,
              otherItems,
              address,
              phoneNumber,
              required date,
            }) async {
              if (orderToEdit != null) {
                final updatedOrder = Order(
                  firestoreId: orderToEdit.firestoreId,
                  customerName: customerName,
                  gallonQuantity: gallonQuantity,
                  otherItems: otherItems,
                  address: address,
                  phoneNumber: phoneNumber,
                  status: orderToEdit.status,
                  createdAt: orderToEdit.createdAt,
                  employeeUid: viewModel.currentUser?.uid,
                );
                final e = await viewModel.onUpdateOrder(
                  orderToEdit.firestoreId!,
                  updatedOrder,
                );
                if (context.mounted)
                  _handleApiError(
                    context,
                    e,
                    successMessage: 'Pesanan berhasil diperbarui!',
                  );
              } else {
                await viewModel.onAddOrder(
                  customerName: customerName,
                  gallonQuantity: gallonQuantity,
                  otherItems: otherItems,
                  address: address,
                  phoneNumber: phoneNumber,
                  date: date,
                );
                if (context.mounted)
                  _handleApiError(
                    context,
                    null,
                    successMessage: 'Pesanan baru berhasil ditambahkan!',
                  );
              }
            },
      ),
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    KaryawanHomeViewModel viewModel,
    Order order,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text(
          'Anda yakin ingin menghapus pesanan untuk "${order.customerName}"?',
        ),
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
                final e = await viewModel.onDeleteOrder(order.firestoreId!);
                if (context.mounted)
                  _handleApiError(
                    context,
                    e,
                    successMessage: 'Pesanan berhasil dihapus.',
                  );
              }
            },
          ),
        ],
      ),
    );
  }

  void _handleApiError(
    BuildContext context,
    String? error, {
    String? successMessage,
  }) {
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

  // --- PERBAIKAN: Mengganti BottomSheet dengan Dialog Konfirmasi ---
  void _showLogoutConfirmDialog(
    BuildContext context,
    KaryawanHomeViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Anda yakin ingin keluar dari akun Anda?'),
        actions: [
          TextButton(
            child: const Text('Batal'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.of(ctx).pop(); // Tutup dialog
              viewModel._authService.signOut();
            },
          ),
        ],
      ),
    );
  }
}
