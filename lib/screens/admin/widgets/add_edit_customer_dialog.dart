import 'package:damiu/models/customer_model.dart';
import 'package:flutter/material.dart';

class AddEditCustomerDialog extends StatefulWidget {
  final Customer? customerToEdit;
  final Function({
    required String name,
    String? address,
    String? phoneNumber,
  }) onSubmit;

  const AddEditCustomerDialog({
    super.key,
    this.customerToEdit,
    required this.onSubmit,
  });

  @override
  State<AddEditCustomerDialog> createState() => _AddEditCustomerDialogState();
}

class _AddEditCustomerDialogState extends State<AddEditCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.customerToEdit?.name ?? '');
    _addressController =
        TextEditingController(text: widget.customerToEdit?.address ?? '');
    _phoneController =
        TextEditingController(text: widget.customerToEdit?.phoneNumber ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    // Pertama, validasi form. Gunakan null-aware operator untuk keamanan.
    if (_formKey.currentState?.validate() ?? false) {
      // Sembunyikan keyboard secara eksplisit untuk menghindari race condition
      FocusScope.of(context).unfocus();

      // Jalankan proses submit yang async
      await widget.onSubmit(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );

      // Setelah proses async selesai, selalu cek 'mounted'
      if (!mounted) return;

      // Tutup dialog
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.customerToEdit == null ? 'Tambah Pelanggan' : 'Ubah Pelanggan'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Pelanggan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Alamat (Opsional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'No. Telepon (Opsional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _submitForm,
          child: Text(widget.customerToEdit == null ? 'Tambah' : 'Simpan'),
        ),
      ],
    );
  }
}
