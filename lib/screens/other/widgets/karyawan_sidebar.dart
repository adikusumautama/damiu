// lib/screens/other/widgets/karyawan_sidebar.dart
import 'package:flutter/material.dart';
import 'package:damiu/screens/other/local_sales_management_controller.dart';

class KaryawanSidebar extends StatelessWidget {
  final LocalSalesManagementController controller;

  const KaryawanSidebar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: const Text('Menu Admin Lokal', style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sinkronisasi Manual'),
            onTap: () async {
              Navigator.pop(context);
              await controller.refreshAllData();
              if (context.mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sinkronisasi selesai.')));
              }
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Aksi Berbahaya', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ),
          // --- PERBAIKAN: Tombol-tombol yang tidak memiliki fungsi dihapus ---
          // ListTile(
          //   leading: const Icon(Icons.delete_forever, color: Colors.red),
          //   title: const Text('Hapus Semua Log', style: TextStyle(color: Colors.red)),
          //   onTap: () async {
          //     Navigator.pop(context);
          //     await controller.deleteAllLogs();
          //     if (context.mounted) {
          //       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semua log lokal dihapus.')));
          //     }
          //   },
          // ),
          // ... (dan seterusnya untuk tombol hapus lainnya)
        ],
      ),
    );
  }
}