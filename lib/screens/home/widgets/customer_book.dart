import 'package:flutter/material.dart';
import 'package:damiu/models/customer_model.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:damiu/services/database_helper.dart';

class CustomerBook extends StatelessWidget {
  final bool isOnline;
  const CustomerBook({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    if (isOnline) {
      return StreamBuilder<List<Customer>>(
        stream: FirestoreService().getCustomersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final customers = snapshot.data ?? [];
          if (customers.isEmpty) {
            return const Center(child: Text('Belum ada pelanggan.'));
          }
          return _buildList(customers);
        },
      );
    } else {
      return FutureBuilder<List<Customer>>(
        future: DatabaseHelper().getAllCustomers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final customers = snapshot.data ?? [];
          if (customers.isEmpty) {
            return const Center(child: Text('Belum ada pelanggan lokal.'));
          }
          return _buildList(customers);
        },
      );
    }
  }

  Widget _buildList(List<Customer> customers) {
    return ListView.separated(
      itemCount: customers.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final c = customers[i];
        return ListTile(
          leading: const Icon(Icons.person),
          title: Text(c.name),
          subtitle: Text(c.phoneNumber ?? '-'),
          trailing: Text(c.address ?? ''),
        );
      },
    );
  }
}
