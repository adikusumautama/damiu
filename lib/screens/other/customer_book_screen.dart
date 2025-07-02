// lib/screens/other/customer_book_screen.dart

import 'package:damiu/models/customer_model.dart';
import 'package:damiu/services/database_helper.dart';
import 'package:flutter/material.dart';

class CustomerBookScreen extends StatefulWidget {
  const CustomerBookScreen({super.key});

  @override
  State<CustomerBookScreen> createState() => _CustomerBookScreenState();
}

class _CustomerBookScreenState extends State<CustomerBookScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<List<Customer>> _customersFuture;

  @override
  void initState() {
    super.initState();
    _customersFuture = _dbHelper.getAllCustomers();
  }

  void _refreshCustomers() {
    setState(() {
      _customersFuture = _dbHelper.getAllCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _refreshCustomers(),
        child: FutureBuilder<List<Customer>>(
          future: _customersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  'Belum ada pelanggan yang tercatat.\nCatat pesanan baru untuk menambahkan pelanggan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            final customers = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: customers.length,
              itemBuilder: (context, index) {
                final customer = customers[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?'),
                    ),
                    title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${customer.phoneNumber ?? 'No. HP tidak ada'}\n${customer.address ?? 'Alamat tidak ada'}',
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}