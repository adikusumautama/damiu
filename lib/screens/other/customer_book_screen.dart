// lib/screens/other/customer_book_screen.dart

import 'package:damiu/models/customer_model.dart';
import 'package:damiu/services/database_helper.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:flutter/material.dart';

class CustomerBookScreen extends StatefulWidget {
  const CustomerBookScreen({super.key});

  @override
  State<CustomerBookScreen> createState() => _CustomerBookScreenState();
}

class _CustomerBookScreenState extends State<CustomerBookScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Stream<List<Customer>> _customerStream;

  @override
  void initState() {
    super.initState();
    _customerStream = _firestoreService.getCustomersStream();
  }

  /// Sinkronisasi data dari Firestore ke database lokal.
  /// Ini adalah inti dari solusi sinkronisasi dua arah.
  Future<void> _syncLocalCustomers(List<Customer> firestoreCustomers) async {
    // 1. Ambil semua pelanggan dari database lokal
    final localCustomers = await _dbHelper.getAllCustomers();

    // 2. Buat set nama pelanggan dari Firestore untuk pencarian cepat
    final firestoreCustomerNames =
        firestoreCustomers.map((c) => c.name).toSet();

    // 3. Hapus pelanggan lokal yang sudah tidak ada di Firestore
    for (final localCustomer in localCustomers) {
      if (!firestoreCustomerNames.contains(localCustomer.name)) {
        print(
            'Menghapus pelanggan lokal yang tidak ada di server: ${localCustomer.name}');
        if (localCustomer.id != null) {
          await _dbHelper.deleteCustomer(localCustomer.id!);
        }
      }
    }

    // 4. Tambahkan atau perbarui pelanggan dari Firestore ke database lokal
    for (final firestoreCustomer in firestoreCustomers) {
      await _dbHelper.upsertCustomer(firestoreCustomer);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Customer>>(
        stream: _customerStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Terjadi error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
                child: Text('Tidak ada data pelanggan di server.'));
          }

          final customers = snapshot.data!;

          // Jalankan sinkronisasi setiap kali ada data baru dari stream
          // FutureBuilder digunakan agar proses sinkronisasi tidak memblokir UI
          return FutureBuilder(
            future: _syncLocalCustomers(customers),
            builder: (context, syncSnapshot) {
              if (syncSnapshot.connectionState == ConnectionState.waiting) {
                // Tampilkan data yang ada sambil sinkronisasi di background
                return _buildCustomerList(customers, isLoading: true);
              }
              // Setelah sinkronisasi selesai, tampilkan list normal
              return _buildCustomerList(customers);
            },
          );
        },
      ),
    );
  }

  Widget _buildCustomerList(List<Customer> customers, {bool isLoading = false}) {
    return Column(
      children: [
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 3)),
                SizedBox(width: 10),
                Text("Sinkronisasi data lokal..."),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              // Memicu pemuatan ulang stream (opsional, tergantung kebutuhan)
              setState(() {
                _customerStream = _firestoreService.getCustomersStream();
              });
            },
            child: ListView.builder(
              itemCount: customers.length,
              itemBuilder: (context, index) {
                final customer = customers[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(customer.name.isNotEmpty
                          ? customer.name.substring(0, 1).toUpperCase()
                          : '?'),
                    ),
                    title: Text(customer.name),
                    subtitle: Text(
                      'Alamat: ${customer.address ?? "Tidak ada"}\nNo. HP: ${customer.phoneNumber ?? "Tidak ada"}',
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}