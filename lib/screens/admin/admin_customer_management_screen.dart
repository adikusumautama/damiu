import 'package:damiu/models/customer_model.dart';
import 'package:damiu/screens/admin/widgets/add_edit_customer_dialog.dart';
import 'package:damiu/screens/admin/widgets/customer_list_tile.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:flutter/material.dart';

class AdminCustomerManagementScreen extends StatefulWidget {
  const AdminCustomerManagementScreen({super.key});

  @override
  State<AdminCustomerManagementScreen> createState() =>
      _AdminCustomerManagementScreenState();
}

class _AdminCustomerManagementScreenState
    extends State<AdminCustomerManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleApiResponse(String? error, String successMessage) {
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage), backgroundColor: Colors.green),
      );
    }
  }

  void _showAddEditDialog({Customer? customer}) {
    showDialog(
      context: context,
      builder: (ctx) => AddEditCustomerDialog(
        customerToEdit: customer,
        onSubmit: ({
          required String name,
          String? address,
          String? phoneNumber,
        }) async {
          if (customer == null) {
            // Tambah baru
            final newCustomer = Customer(
              name: name,
              address: address,
              phoneNumber: phoneNumber,
              createdAt: DateTime.now(),
              isSynced: true,
            );
            final newId = await _firestoreService.addCustomer(newCustomer);
            _handleApiResponse(
                newId.isEmpty ? 'Gagal menambah' : null, 'Pelanggan ditambahkan.');
          } else {
            // Ubah
            final updatedCustomer = Customer(
              firestoreId: customer.firestoreId,
              name: name,
              address: address,
              phoneNumber: phoneNumber,
              createdAt: customer.createdAt,
              isSynced: true,
            );
            final error = await _firestoreService.updateCustomer(updatedCustomer);
            _handleApiResponse(error, 'Pelanggan berhasil diperbarui.');
          }
        },
      ),
    );
  }

  void _showDeleteConfirmDialog(Customer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pelanggan?'),
        content: Text(
            'Anda yakin ingin menghapus pelanggan "${customer.name}"? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            child: const Text('Batal'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (customer.firestoreId != null) {
                final error =
                    await _firestoreService.deleteCustomer(customer.firestoreId!);
                _handleApiResponse(error, 'Pelanggan berhasil dihapus.');
              }
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteAllConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Semua Pelanggan?'),
        content: const Text(
            'Anda yakin ingin menghapus SEMUA data pelanggan? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            child: const Text('Batal'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Hapus Semua', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final error = await _firestoreService.deleteAllCustomers();
              _handleApiResponse(error, 'Semua pelanggan berhasil dihapus.');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Pelanggan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Hapus Semua Pelanggan',
            onPressed: _showDeleteAllConfirmDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Cari Pelanggan',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Customer>>(
              stream: _firestoreService.getCustomersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Belum ada data pelanggan.'));
                }

                final allCustomers = snapshot.data!;
                final filteredCustomers = allCustomers.where((customer) {
                  final query = _searchQuery.toLowerCase();
                  return customer.name.toLowerCase().contains(query) ||
                      (customer.address?.toLowerCase().contains(query) ??
                          false) ||
                      (customer.phoneNumber?.toLowerCase().contains(query) ??
                          false);
                }).toList();

                if (filteredCustomers.isEmpty) {
                  return const Center(child: Text('Pelanggan tidak ditemukan.'));
                }

                return ListView.builder(
                  itemCount: filteredCustomers.length,
                  itemBuilder: (context, index) {
                    final customer = filteredCustomers[index];
                    return CustomerListTile(
                      customer: customer,
                      onEdit: () => _showAddEditDialog(customer: customer),
                      onDelete: () => _showDeleteConfirmDialog(customer),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        tooltip: 'Tambah Pelanggan',
        child: const Icon(Icons.add),
      ),
    );
  }
}
