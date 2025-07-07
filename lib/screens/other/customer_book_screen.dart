// lib/screens/other/customer_book_screen.dart

import 'package:damiu/models/customer_model.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:flutter/material.dart';

class CustomerBookScreen extends StatefulWidget {
  const CustomerBookScreen({super.key});

  @override
  State<CustomerBookScreen> createState() => _CustomerBookScreenState();
}

class _CustomerBookScreenState extends State<CustomerBookScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late Stream<List<Customer>> _customerStream;

  @override
  void initState() {
    super.initState();
    _customerStream = _firestoreService.getCustomersStream();
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

          // Langsung tampilkan list dari data stream. Firestore menangani cache.
          return _buildCustomerList(customers);
        },
      ),
    );
  }

  Widget _buildCustomerList(List<Customer> customers) {
    return Column(
      children: [
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