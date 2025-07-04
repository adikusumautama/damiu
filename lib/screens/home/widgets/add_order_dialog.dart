import 'package:flutter/material.dart';
import 'package:damiu/models/customer_model.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:damiu/screens/home/widgets/customer_autocomplete_field.dart';

class AddOrderDialog extends StatefulWidget {
  final void Function({
    required String customerName,
    required int gallonQuantity,
    String? otherItems,
    String? address,
    String? phoneNumber,
  }) onSubmit;

  const AddOrderDialog({super.key, required this.onSubmit});

  @override
  State<AddOrderDialog> createState() => _AddOrderDialogState();
}

class _AddOrderDialogState extends State<AddOrderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _gallonController = TextEditingController();
  final _otherItemsController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  final List<Customer> _customers = [];
  bool _loadingCustomers = false;
  Customer? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _loadingCustomers = true);
    // TODO: Ganti dengan dependency injection jika perlu
    final firestoreService = FirestoreService();
    try {
      final stream = firestoreService.getCustomersStream();
      stream.listen((data) {
        setState(() {
          _customers.clear();
          _customers.addAll(data);
          _loadingCustomers = false;
        });
      });
    } catch (_) {
      setState(() => _loadingCustomers = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gallonController.dispose();
    _otherItemsController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Catat Pesanan Baru'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _loadingCustomers
                  ? const LinearProgressIndicator()
                  : CustomerAutocompleteField(
                      customers: _customers,
                      controller: _nameController,
                      onSelected: (customer) {
                        setState(() {
                          _selectedCustomer = customer;
                        });
                        if (customer != null) {
                          _addressController.text = customer.address ?? '';
                          _phoneController.text = customer.phoneNumber ?? '';
                        }
                      },
                    ),
              TextFormField(
                controller: _gallonController,
                decoration: const InputDecoration(labelText: 'Jumlah Galon *'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Jumlah galon wajib diisi';
                  final n = int.tryParse(v);
                  if (n == null || n <= 0) return 'Masukkan angka galon yang valid';
                  return null;
                },
              ),
              TextFormField(
                controller: _otherItemsController,
                decoration: const InputDecoration(labelText: 'Pesanan Lainnya (opsional)'),
              ),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Alamat (opsional)'),
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Nomor Telepon (opsional)'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final name = _selectedCustomer?.name ?? _nameController.text.trim();
              final address = _selectedCustomer?.address ?? (_addressController.text.trim().isEmpty ? null : _addressController.text.trim());
              final phone = _selectedCustomer?.phoneNumber ?? (_phoneController.text.trim().isEmpty ? null : _phoneController.text.trim());
              widget.onSubmit(
                customerName: name,
                gallonQuantity: int.parse(_gallonController.text.trim()),
                otherItems: _otherItemsController.text.trim().isEmpty ? null : _otherItemsController.text.trim(),
                address: address,
                phoneNumber: phone,
              );
              // Tambahkan pelanggan baru ke database jika belum ada
              final exists = _customers.any((c) => c.name.toLowerCase() == name.toLowerCase());
              if (!exists) {
                final newCustomer = Customer(
                  name: name,
                  address: address,
                  phoneNumber: phone,
                  createdAt: DateTime.now(),
                  isSynced: false,
                );
                FirestoreService().upsertCustomer(newCustomer);
                // TODO: insert ke database lokal jika offline
              }
              Navigator.pop(context);
            }
          },
          child: const Text('Catat'),
        ),
      ],
    );
  }
}
