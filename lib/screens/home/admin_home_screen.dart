import 'package:damiu/screens/admin/admin_prediction_view_screen.dart'; // Path file yang sudah diubah
import 'package:damiu/screens/admin/admin_firestore_data_view_screen.dart'; // Impor widget baru
import 'package:damiu/screens/admin/admin_sync_metadata_screen.dart'; // Impor layar metadata baru
import 'package:damiu/models/user_model.dart'; // Impor UserModel
import 'package:damiu/services/auth_service.dart';
import 'package:flutter/material.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;
  late Widget _currentScreenWidget;
  late String _currentScreenTitle;
  UserModel? _currentUserModel;
  final AuthService _authService = AuthService();


  // Daftar widget untuk setiap tab
  static final List<Widget> _widgetOptions = <Widget>[
    const Center(child: Text("Selamat Datang di Admin Dashboard Utama")), // Placeholder untuk Beranda baru
    const AdminPredictionViewScreen(), // Konten prediksi sekarang di sini
    const Center(child: Text("Halaman Manajemen Produk")), // Placeholder, ganti dengan widget ProdukAdminContent jika ada
  ];

  // Daftar judul AppBar untuk setiap tab
  static const List<String> _appBarTitles = <String>[
    'Admin Dashboard',
    'Grafik Prediksi',
    'Manajemen Produk',
  ];

  @override
  void initState() {
    super.initState();
    _currentScreenWidget = _widgetOptions[_selectedIndex];
    _currentScreenTitle = _appBarTitles[_selectedIndex];
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final currentUser = _authService.getCurrentUser();
    if (currentUser != null) {
      final userModel = await _authService.getUserModel(currentUser.uid);
      if (mounted) {
        setState(() {
          _currentUserModel = userModel;
        });
      }
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
      appBar: AppBar(
        title: Text(_currentScreenTitle), // Gunakan judul layar yang aktif
        // Tombol untuk membuka Drawer akan muncul otomatis jika ada Drawer
      ),
      body: Center(
        child: _currentScreenWidget, // Tampilkan widget layar yang aktif
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: _currentUserModel == null
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentUserModel!.name ?? 'Admin',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentUserModel!.email,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        if (_currentUserModel!.phoneNumber != null && _currentUserModel!.phoneNumber!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              _currentUserModel!.phoneNumber!,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
            ),
            // Anda bisa menambahkan item navigasi lain di sini jika diperlukan
            // Contoh:
            ListTile(
              leading: Icon(Icons.dataset_outlined),
              title: Text('Database'),
              onTap: () {
                Navigator.pop(context); // Tutup drawer
                setState(() {
                  _currentScreenWidget = const AdminFirestoreDataWidget(); // Ganti konten utama
                  _currentScreenTitle = "Data Penjualan"; // Ganti judul AppBar
                  // _selectedIndex bisa diatur ke nilai yang tidak ada di bottom nav, atau biarkan
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.sync_alt_outlined),
              title: const Text('Metadata Sinkronisasi'),
              onTap: () {
                Navigator.pop(context); // Tutup drawer
                setState(() {
                  _currentScreenWidget = const AdminSyncMetadataScreen(); // Ganti konten utama
                  _currentScreenTitle = "Metadata Sinkronisasi"; // Ganti judul AppBar
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.pop(context); // Tutup drawer terlebih dahulu
                await AuthService().signOut();
                // AuthWrapper akan menangani navigasi
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
            icon: Icon(Icons.analytics_outlined),
            label: 'Prediksi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Produk',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        onTap: _onItemTapped,
      ),
    );
  }
}
