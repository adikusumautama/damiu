// lib/screens/home/karyawan_home_screen.dart
import 'package:damiu/models/user_model.dart'; // Impor UserModel
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/services/sync_service.dart'; // Import SyncService
import 'package:damiu/services/database_helper.dart'; // Impor DatabaseHelper
import 'package:flutter/material.dart';
// Jika Anda memindahkan DailySalesInputScreen:
import 'package:damiu/screens/other/local_sales_management_screen.dart'; // Impor widget baru
import 'package:damiu/screens/other/daily_sales_input_screen.dart'; // Path baru
import 'package:damiu/screens/other/karyawan_profile_screen.dart'; // Impor layar profil

class KaryawanHomeScreen extends StatefulWidget {
  // Ubah menjadi StatefulWidget
  const KaryawanHomeScreen({super.key});

  @override
  State<KaryawanHomeScreen> createState() => _KaryawanHomeScreenState();
}

class _KaryawanHomeScreenState extends State<KaryawanHomeScreen>
    with WidgetsBindingObserver {
  // Tambahkan WidgetsBindingObserver
  int _selectedIndex = 0;
  late Widget _currentScreenWidget;
  late String _currentScreenTitle;
  UserModel? _currentUserModel;
  final AuthService _authService = AuthService();
  final DatabaseHelper _dbHelper = DatabaseHelper(); // Tambahkan DatabaseHelper
  bool _isDailySyncing = false; // State untuk sinkronisasi harian
  bool _isSyncing = false;
  final SyncService _syncService = SyncService();

  // Daftar widget untuk setiap tab BottomNavigationBar
  // Kita perlu membuat instance KaryawanBerandaContent di initState atau build
  // agar bisa meneruskan callback _loadTodaysStats.
  // Jadi, _widgetOptions akan diinisialisasi nanti.
  late List<Widget> _widgetOptions;
  // static final List<Widget> _widgetOptions = <Widget>[
  //   const KaryawanProfileScreen(), // Konten untuk Profil Karyawan
  // ];

  // Daftar judul AppBar untuk setiap tab
  static const List<String> _appBarTitles = <String>[
    'Beranda Karyawan',
    'Profil Saya',
  ]; // Pastikan ini tidak terkomentari

  @override
  void initState() {
    super.initState();
    // Inisialisasi _widgetOptions di sini agar bisa meneruskan _loadTodaysStats
    _widgetOptions = <Widget>[
      KaryawanBerandaContent( // Jadikan non-const
        getIsDailySyncing: () => _isDailySyncing,
        performDailySummarySyncCallback: _performAllPendingDeliverySync, // Ganti nama callback
      ),
      const KaryawanProfileScreen(),
    ];
    _currentScreenWidget =
        _widgetOptions[_selectedIndex]; // Sekarang _widgetOptions sudah diinisialisasi
    _currentScreenTitle = _appBarTitles[_selectedIndex];
    _loadCurrentUser();
    WidgetsBinding.instance.addObserver(this); // Daftarkan observer
  }

  @override
  void dispose() {
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

  Future<void> _performAllPendingDeliverySync() async { // Ganti nama metode
    setState(() {
      _isDailySyncing = true;
    });

    final result = await _syncService.syncAllUnsummarizedDeliveryLogs(); // Panggil metode baru

    if (mounted) {
      setState(() {
        _isDailySyncing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _performSync() async {
    setState(() {
      _isSyncing = true;
    });

    final result = await _syncService.syncData();

    if (mounted) {
      setState(() {
        _isSyncing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _currentScreenWidget = _widgetOptions[index];
      _currentScreenTitle = _appBarTitles[index];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_currentScreenTitle)),
      body: _currentScreenWidget, // Hapus Center, biarkan konten menentukan tata letak
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
                Navigator.pop(context); // Tutup drawer
                setState(() {
                  _currentScreenWidget =
                      const LocalSalesManagementWidget(); // Ganti konten utama
                  _currentScreenTitle =
                      "Kelola Data Lokal"; // Ganti judul AppBar
                  // Reset _selectedIndex agar BottomNav tidak aktif, atau set ke tab default
                  // Jika ingin BottomNav tidak aktif, pastikan handle _selectedIndex yang tidak valid
                  // Untuk amannya, bisa set ke 0 (Beranda)
                  // _selectedIndex = 0;
                  // _currentScreenWidget = _widgetOptions[0]; // Kembali ke beranda setelah dari drawer
                });
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
  final bool Function() getIsDailySyncing;
  final Future<void> Function() performDailySummarySyncCallback;

  const KaryawanBerandaContent({
    super.key,
    required this.getIsDailySyncing,
    required this.performDailySummarySyncCallback,
  }); // Hapus const

  @override
  State<KaryawanBerandaContent> createState() => _KaryawanBerandaContentState();
}

class _KaryawanBerandaContentState extends State<KaryawanBerandaContent> {
  @override
  Widget build(BuildContext context) {
    // Ambil nilai saat ini untuk ditampilkan dan di-log
    // Akses _isSyncing dan _performSync dari _KaryawanHomeScreenState
    // Ini bisa dilakukan dengan callback atau cara lain jika state management lebih canggih
    // Untuk sekarang, kita asumsikan parentState sudah memiliki data terbaru.

    return SingleChildScrollView(
      // Hapus RefreshIndicator, biarkan SingleChildScrollView
      // physics: const AlwaysScrollableScrollPhysics(), // Bisa dihapus atau diganti jika tidak ingin selalu bisa scroll
      // physics: BouncingScrollPhysics(), // Atau ClampingScrollPhysics()
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch, // Melebarkan tombol
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add_chart),
              label: const Text('Input Penjualan Harian'),
              onPressed: () {
                Navigator.push(
                  context, MaterialPageRoute(builder: (context) => const DailySalesInputScreen()),
                ).then((result) async {
                  // Jadikan callback ini async
                  if (result is Map && result['saved'] == true) {
                    print(
                      "[KaryawanBerandaContent] DailySalesInputScreen returned: $result.",
                    );
                    // Jika perlu refresh UI di sini setelah input, setState akan melakukannya.
                    // Jika ada data yang perlu dimuat ulang dari parent, parent yang harus menanganinya.
                    if (mounted) setState(() {});
                    print(
                      "[KaryawanBerandaContent] Stats refreshed via onRefreshRequested.",
                    );

                    // Jika DailySalesInputScreen mengindikasikan untuk navigasi ke Beranda
                    // (meskipun kita sudah di Beranda), memanggil _onItemTapped(0)
                    // akan memastikan state KaryawanHomeScreen (seperti _currentScreenWidget) konsisten
                    // dan memicu setState, yang akan me-rebuild.
                    // Ini mungkin sedikit redundan jika onRefreshRequested sudah cukup, tapi tidak berbahaya.
                    if (result['navigateToBeranda'] == true) {
                      final parentState = context
                          .findAncestorStateOfType<_KaryawanHomeScreenState>();
                      if (parentState != null) {
                        print(
                          "[KaryawanBerandaContent] Ensuring Beranda tab is active by calling _onItemTapped(0).",
                        );
                        parentState._onItemTapped(0);
                      }
                    }
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16), // Tambah padding vertikal
                textStyle: const TextStyle(fontSize: 16), // Ukuran teks tombol
              ),
            ),
            const SizedBox(height: 20),
            widget.getIsDailySyncing()
                ? const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8), // Perkecil jarak
                      Text("Sinkronisasi data pengantaran..."), // Ubah teks loading
                    ],
                  )
                : ElevatedButton.icon(
                    icon: const Icon(Icons.cloud_sync_outlined),
                    label: const Text('Sinkronkan Data Pengantaran'), // Ubah label tombol
                    onPressed: widget.performDailySummarySyncCallback, 
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, // Tambahkan ini untuk warna teks putih
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 16), // Padding sama dengan tombol input
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
          ],
        ),
      ),
    ); // Hapus satu tanda kurung penutup yang berlebih
  }
}
