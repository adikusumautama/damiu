// lib/screens/home/widgets/add_order_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:damiu/models/order_model.dart'; // Pastikan impor ini ada

class AddOrderDialog extends StatefulWidget {
  final Function({
    required String customerName,
    required int gallonQuantity,
    String? otherItems,
    String? address,
    String? phoneNumber,
    required DateTime date,
  }) onSubmit;
  // --- PERBAIKAN: Tambahkan parameter ini ---
  final Order? orderToEdit;

  const AddOrderDialog({
    super.key,
    required this.onSubmit,
    this.orderToEdit, // Jadikan opsional
  });

  @override
  State<AddOrderDialog> createState() => _AddOrderDialogState();
}

class _AddOrderDialogState extends State<AddOrderDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _customerNameController;
  late TextEditingController _gallonQuantityController;
  late TextEditingController _otherItemsController;
  late TextEditingController _addressController;
  late TextEditingController _phoneNumberController;
  DateTime _selectedDate = DateTime.now();
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.orderToEdit != null;

    // --- PERBAIKAN: Isi form dengan data yang ada jika dalam mode edit ---
    _customerNameController = TextEditingController(text: widget.orderToEdit?.customerName ?? '');
    _gallonQuantityController = TextEditingController(text: widget.orderToEdit?.gallonQuantity?.toString() ?? '');
    _otherItemsController = TextEditingController(text: widget.orderToEdit?.otherItems ?? '');
    _addressController = TextEditingController(text: widget.orderToEdit?.address ?? '');
    _phoneNumberController = TextEditingController(text: widget.orderToEdit?.phoneNumber ?? '');
    _selectedDate = widget.orderToEdit?.createdAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _gallonQuantityController.dispose();
    _otherItemsController.dispose();
    _addressController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      widget.onSubmit(
        customerName: _customerNameController.text,
        gallonQuantity: int.parse(_gallonQuantityController.text),
        otherItems: _otherItemsController.text,
        address: _addressController.text,
        phoneNumber: _phoneNumberController.text,
        date: _selectedDate,
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditMode ? 'Ubah Pesanan' : 'Catat Pesanan Baru'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _customerNameController,
                decoration: const InputDecoration(labelText: 'Nama Pelanggan'),
                validator: (value) => value == null || value.isEmpty ? 'Nama tidak boleh kosong' : null,
              ),
              TextFormField(
                controller: _gallonQuantityController,
                decoration: const InputDecoration(labelText: 'Jumlah Galon'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty || int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Masukkan jumlah yang valid';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Alamat (Opsional)'),
              ),
              TextFormField(
                controller: _phoneNumberController,
                decoration: const InputDecoration(labelText: 'No. Telepon (Opsional)'),
                keyboardType: TextInputType.phone,
              ),
              TextFormField(
                controller: _otherItemsController,
                decoration: const InputDecoration(labelText: 'Item Lain (Opsional)'),
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
          child: Text(_isEditMode ? 'Simpan Perubahan' : 'Simpan'),
        ),
      ],
    );
  }
}