// lib/screens/admin/admin_firestore_data_view_screen.dart
import 'package:damiu/models/daily_sale_model.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminFirestoreDataWidget extends StatefulWidget {
  const AdminFirestoreDataWidget({super.key});

  @override
  State<AdminFirestoreDataWidget> createState() =>
      _AdminFirestoreDataWidgetState();
}

class _AdminFirestoreDataWidgetState
    extends State<AdminFirestoreDataWidget> {
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> _deleteSale(String firestoreId, DateTime date) async {
    final bool confirm =
        await showDialog(
          context: context,
          builder: (BuildContext ctx) {
            return AlertDialog(
              title: const Text('Konfirmasi Hapus Data'),
              content: Text(
                'Anda yakin ingin menghapus data penjualan tanggal ${DateFormat('dd-MM-yyyy').format(date)} dari Firestore?',
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Batal'),
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Hapus'),
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirm) {
      String? error = await _firestoreService.deleteDailySale(firestoreId);
      if (mounted) {
        if (error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data berhasil dihapus dari Firestore.'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus data dari Firestore: $error'),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteAllSales() async {
    final bool confirm =
        await showDialog(
          context: context,
          builder: (BuildContext ctx) {
            return AlertDialog(
              title: const Text('Konfirmasi Hapus Semua Data'),
              content: const Text(
                'Anda yakin ingin menghapus SEMUA data penjualan dari Firestore? Tindakan ini tidak dapat dibatalkan.',
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Batal'),
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Hapus Semua'),
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirm) {
      String? error = await _firestoreService.deleteAllDailySales();
      if (mounted) {
        if (error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Semua data berhasil dihapus dari Firestore.'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Gagal menghapus semua data dari Firestore: $error',
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DailySale>>(
        stream: _firestoreService.getDailySalesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error memuat data: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('Tidak ada data penjualan di Firestore.'),
            );
          }

          final salesData = snapshot.data!;

          // Menggunakan Padding di sini untuk keseluruhan konten di bawah AppBar
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Data: ${salesData.length} entri',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_forever_outlined,
                        color: Colors.red,
                      ),
                      onPressed: salesData.isEmpty ? null : _deleteAllSales,
                      tooltip: 'Hapus Semua Data dari Firestore',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Expanded akan membuat Card (dan DataTable di dalamnya) mengambil sisa ruang vertikal
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: Card(
                      elevation: 2,
                      // SingleChildScrollView di dalam Card untuk membuat DataTable bisa discroll
                      child: SingleChildScrollView(
                        child: DataTable(
                          columnSpacing: 15,
                          headingRowColor:
                              MaterialStateProperty.resolveWith<Color?>((
                            Set<MaterialState> states,
                          ) {
                            return Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1);
                          }),
                          headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          columns: const <DataColumn>[
                            DataColumn(label: Text('Tanggal')),
                            DataColumn(label: Text('Hari')),
                            DataColumn(label: Text('Total Galon')),
                            DataColumn(label: Text('Aksi')), // Kolom untuk tombol hapus
                          ],
                          rows: salesData.map((sale) {
                            return DataRow(
                              cells: <DataCell>[
                                DataCell(
                                  Text(
                                    DateFormat(
                                      'dd MMM yyyy',
                                      'id_ID',
                                    ).format(sale.date),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    DateFormat(
                                      'EEEE',
                                      'id_ID',
                                    ).format(sale.date),
                                  ),
                                ),
                                DataCell(Text(sale.quantity.toString())),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: sale.firestoreId == null
                                        ? null
                                        : () => _deleteSale(
                                            sale.firestoreId!,
                                            sale.date,
                                          ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
  }
}
