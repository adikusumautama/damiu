import 'package:flutter/material.dart';
import '../local_sales_management_controller.dart';

class KaryawanSidebar extends StatelessWidget {
  final LocalSalesManagementController controller;
  const KaryawanSidebar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text('Data Lokal Karyawan', style: TextStyle(color: Colors.white, fontSize: 20)),
          ),
          ListTile(
            title: const Text('Log Pengantaran'),
            subtitle: Text('Total: ${controller.localDeliveryLogs.length}'),
            onTap: () => showDataDialog(
              context,
              'Log Pengantaran',
              controller.localDeliveryLogs.map((e) =>
                'Tanggal: ${e.date}\nKaryawan: ${controller.employeeNames[e.employeeUid] ?? e.employeeUid}\nGalon: ${e.gallons}\nStatus: ${e.isNoDeliveryMarker ? 'Tidak Ada Pengantaran' : 'Terkirim'}'
              ).toList(),
            ),
          ),
          ListTile(
            title: const Text('Stok Awal'),
            subtitle: Text('Total: ${controller.localStockData.length}'),
            onTap: () => showDataDialog(
              context,
              'Stok Awal',
              controller.localStockData.map((e) =>
                'Tanggal: ${e.dateId}\nStok: ${e.stock}\nKaryawan: ${e.employeeUid}'
              ).toList(),
            ),
          ),
          ListTile(
            title: const Text('Pelanggan'),
            subtitle: Text('Total: ${controller.localCustomers.length}'),
            onTap: () => showDataDialog(
              context,
              'Pelanggan',
              controller.localCustomers.map((e) =>
                'Nama: ${e.name}\nAlamat: ${e.address ?? '-'}\nNo. HP: ${e.phoneNumber ?? '-'}'
              ).toList(),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Data Lokal'),
            subtitle: const Text('Lihat data log, stok, dan pelanggan yang tersimpan di perangkat.'),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Log Pengantaran', style: Theme.of(context).textTheme.titleMedium),
                        ...controller.localDeliveryLogs.map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            'Tanggal: ${e.date}\nKaryawan: ${controller.employeeNames[e.employeeUid] ?? e.employeeUid}\nGalon: ${e.gallons}\nStatus: ${e.isNoDeliveryMarker ? 'Tidak Ada Pengantaran' : 'Terkirim'}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        )),
                        const Divider(),
                        Text('Stok Awal', style: Theme.of(context).textTheme.titleMedium),
                        ...controller.localStockData.map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            'Tanggal: ${e.dateId}\nStok: ${e.stock}\nKaryawan: ${e.employeeUid}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        )),
                        const Divider(),
                        Text('Pelanggan', style: Theme.of(context).textTheme.titleMedium),
                        ...controller.localCustomers.map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            'Nama: ${e.name}\nAlamat: ${e.address ?? '-'}\nNo. HP: ${e.phoneNumber ?? '-'}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        )),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Hapus SEMUA Data Lokal', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirm = await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Konfirmasi Hapus Semua Data'),
                  content: const Text('Yakin ingin menghapus SEMUA data lokal? Tindakan ini tidak dapat dibatalkan.'),
                  actions: [
                    TextButton(child: const Text('Batal'), onPressed: () => Navigator.pop(ctx, false)),
                    TextButton(child: const Text('Hapus Semua', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.pop(ctx, true)),
                  ],
                ),
              );
              if (confirm == true) {
                await controller.deleteAllLogs();
                await controller.deleteAllStocks();
                if (controller.deleteAllCustomers != null) {
                  await controller.deleteAllCustomers();
                }
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semua data lokal berhasil dihapus!')));
                controller.refreshAllData();
              }
            },
          ),
        ],
      ),
    );
  }

  void showDataDialog(BuildContext context, String title, List<String> items) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(items[i]),
            ),
          ),
        ),
        actions: [TextButton(child: const Text('Tutup'), onPressed: () => Navigator.pop(ctx))],
      ),
    );
  }
}
