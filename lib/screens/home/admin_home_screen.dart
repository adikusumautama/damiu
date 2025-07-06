// lib/screens/home/admin_home_screen.dart

import 'package:damiu/models/order_model.dart';
import 'package:damiu/screens/admin/admin_dashboard_screen.dart';
import 'package:damiu/screens/admin/admin_firestore_data_view_screen.dart';
import 'package:damiu/screens/admin/admin_order_management_screen.dart'; // <-- Impor halaman baru
import 'package:damiu/screens/admin/admin_prediction_view_screen.dart';
import 'package:damiu/screens/admin/admin_sync_metadata_screen.dart';
import 'package:damiu/screens/home/widgets/add_order_dialog.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  // --- DAFTAR HALAMAN ADMIN YANG DIPERBARUI ---
  static const List<Widget> _adminPages = <Widget>[
    AdminDashboardScreen(),
    AdminPredictionViewScreen(),
    AdminOrderManagementScreen(), // Halaman baru untuk CRUD Pesanan
    AdminFirestoreDataWidget(), // Halaman untuk Rekap Penjualan
    AdminSyncMetadataScreen(),
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
        return 'Grafik Prediksi';
      case 2:
        return 'Kelola Pesanan'; // Judul baru
      case 3:
        return 'Rekap Penjualan'; // Judul baru
      case 4:
        return 'Metadata Sinkronisasi';
      default:
        return 'Admin';
    }
  }

  void _showAddOrderDialog() {
    final User? currentUser = _authService.getCurrentUser();
    if (currentUser == null) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mendapatkan info admin.')));
        return;
    }

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
              employeeUid: currentUser.uid,
              isSynced: true,
            );
            
            try {
              await _firestoreService.addOrderAndUpsertCustomer(newOrder);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pesanan baru berhasil ditambahkan!')),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal menambahkan pesanan: $e')),
                );
              }
            }
        },
      ),
    );
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
              await _authService.signOut();
            },
            tooltip: 'Logout',
          )
        ],
      ),
      body: Center(
        child: _adminPages.elementAt(_selectedIndex),
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _showAddOrderDialog,
              tooltip: 'Catat Pesanan Baru',
              child: const Icon(Icons.add_shopping_cart),
            )
          : null,
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
          // --- TAB BARU ---
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Pesanan',
          ),
          // --- TAB LAMA YANG DISESUAIKAN ---
          BottomNavigationBarItem(
            icon: Icon(Icons.summarize_outlined),
            label: 'Rekap',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sync_alt_outlined),
            label: 'Metadata',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}