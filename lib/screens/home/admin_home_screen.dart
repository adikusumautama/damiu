// lib/screens/home/admin_home_screen.dart

import 'package:damiu/screens/admin/admin_dashboard_screen.dart';
import 'package:damiu/screens/admin/admin_firestore_data_view_screen.dart';
import 'package:damiu/screens/admin/admin_prediction_view_screen.dart';
import 'package:damiu/screens/admin/admin_sync_metadata_screen.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:flutter/material.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;

  // Daftar semua halaman admin
  static const List<Widget> _adminPages = <Widget>[
    AdminDashboardScreen(),
    AdminPredictionViewScreen(),
    AdminFirestoreDataWidget(),
    AdminSyncMetadataScreen(), // Halaman "Lainnya" bisa diganti dengan ini atau menu baru
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  
  String _getAppBarTitle(int index) {
    switch(index) {
      case 0:
        return 'Dasbor Admin';
      case 1:
        return 'Grafik Prediksi Penjualan';
      case 2:
        return 'Kelola Data Penjualan';
      case 3:
        return 'Kelola Metadata Sinkronisasi';
      default:
        return 'Admin';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle(_selectedIndex)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
            },
            tooltip: 'Logout',
          )
        ],
      ),
      body: Center(
        child: _adminPages.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dasbor',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights_outlined),
            label: 'Prediksi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storage_outlined),
            label: 'Data',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sync_alt_outlined),
            label: 'Metadata',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey, // Agar item yang tidak dipilih tetap terlihat
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Agar semua label terlihat
      ),
    );
  }
}