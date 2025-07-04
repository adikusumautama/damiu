// ======================================================================
// FILE BARU: lib/screens/other/widgets/local_customer_view.dart
// ======================================================================
// FOKUS: Hanya menampilkan UI untuk tab "Data Pelanggan Lokal".

import 'package:damiu/models/customer_model.dart';
import 'package:flutter/material.dart';

class LocalCustomerView extends StatelessWidget {
  final bool isLoading;
  final List<Customer> customers;
  final Future<void> Function() onRefresh;
  final Function() onDeleteAll;
  final Function(int) onDeleteCustomer;
  final Function(Customer) onEditCustomer;

  const LocalCustomerView({
    super.key,
    required this.isLoading,
    required this.customers,
    required this.onRefresh,
    required this.onDeleteAll,
    required this.onDeleteCustomer,
    required this.onEditCustomer,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(8.0),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Data Pelanggan Lokal (customers)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (isLoading)
                    const LinearProgressIndicator()
                  else
                    Text('Total Pelanggan: ${customers.length}'),
                  const SizedBox(height: 10),
                  Center(
                    child: Tooltip(
                      message: 'Hapus semua data pelanggan dari perangkat ini',
                      child: TextButton.icon(
                        icon: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                        label: const Text('Hapus Semua Pelanggan', style: TextStyle(color: Colors.red)),
                        onPressed: isLoading || customers.isEmpty ? null : onDeleteAll,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : customers.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            child: const Text('Tidak ada data pelanggan tersimpan.'),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: customers.length,
                        itemBuilder: (context, index) {
                          final customer = customers[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: ListTile(
                              leading: CircleAvatar(child: Text(customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?')),
                              title: Text(customer.name),
                              subtitle: Text(
                                'Alamat: ${customer.address ?? '-'}\nNo HP: ${customer.phoneNumber ?? '-'}',
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: Theme.of(context).primaryColor),
                                    onPressed: () => onEditCustomer(customer),
                                    tooltip: 'Edit Pelanggan',
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red[700]),
                                    onPressed: () => onDeleteCustomer(customer.id!),
                                    tooltip: 'Hapus Pelanggan',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}