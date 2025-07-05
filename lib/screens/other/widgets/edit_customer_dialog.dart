// ======================================================================
// FILE BARU: lib/screens/other/widgets/edit_customer_dialog.dart
// ======================================================================
// FOKUS: UI untuk dialog edit pelanggan.

import 'package:damiu/models/customer_model.dart';
import 'package:flutter/material.dart';

class EditCustomerDialog extends StatefulWidget {
  final Customer customer;

  const EditCustomerDialog({super.key, required this.customer});

  @override
  State<EditCustomerDialog> createState() => _EditCustomerDialogState();
}

class _EditCustomerDialogState extends State<EditCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer.name);
    _addressController = TextEditingController(text: widget.customer.address);
    _phoneController = TextEditingController(text: widget.customer.phoneNumber);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final updatedCustomer = widget.customer.copyWith(
        name: _nameController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      );
      Navigator.of(context).pop(updatedCustomer);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Pelanggan'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama Pelanggan'),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Nama tidak boleh kosong' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Alamat (Opsional)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'No. HP (Opsional)'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
        ElevatedButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}