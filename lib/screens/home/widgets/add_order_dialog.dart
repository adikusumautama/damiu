// lib/screens/home/widgets/add_order_dialog.dart

import 'package:damiu/models/customer_model.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:damiu/models/order_model.dart';
import 'package:intl/intl.dart';

class AddOrderDialog extends StatefulWidget {
  // --- PERBAIKAN: Memastikan definisi callback ini benar ---
  final Function({
    required String customerName,
    required int gallonQuantity,
    String? otherItems,
    String? address,
    String? phoneNumber,
    required DateTime date,
  }) onSubmit;
  final Order? orderToEdit;

  const AddOrderDialog({
    super.key,
    required this.onSubmit,
    this.orderToEdit,
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
  final FirestoreService _firestoreService = FirestoreService();
  List<Customer> _customers = [];
  bool _isLoadingCustomers = true;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.orderToEdit != null;
    
    _customerNameController = TextEditingController(text: widget.orderToEdit?.customerName ?? '');
    _gallonQuantityController = TextEditingController(text: widget.orderToEdit?.gallonQuantity?.toString() ?? '');
    _otherItemsController = TextEditingController(text: widget.orderToEdit?.otherItems ?? '');
    _addressController = TextEditingController(text: widget.orderToEdit?.address ?? '');
    _phoneNumberController = TextEditingController(text: widget.orderToEdit?.phoneNumber ?? '');
    _selectedDate = widget.orderToEdit?.createdAt ?? DateTime.now();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final customers = await _firestoreService.getAllCustomersOnce();
      if (mounted) {
        setState(() {
          _customers = customers;
          _isLoadingCustomers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCustomers = false);
      }
      print("Gagal memuat data pelanggan untuk autocomplete: $e");
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      locale: const Locale('id', 'ID'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
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
              Autocomplete<Customer>(
                initialValue: TextEditingValue(text: _customerNameController.text),
                displayStringForOption: (Customer option) => option.name,
                optionsBuilder: (TextEditingValue textEditingValue) {
                  _customerNameController.text = textEditingValue.text;
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<Customer>.empty();
                  }
                  return _customers.where((Customer option) {
                    return option.name
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (Customer selection) {
                  setState(() {
                    _customerNameController.text = selection.name;
                    _addressController.text = selection.address ?? '';
                    _phoneNumberController.text = selection.phoneNumber ?? '';
                  });
                },
                fieldViewBuilder: (BuildContext context,
                    TextEditingController fieldTextEditingController,
                    FocusNode fieldFocusNode,
                    VoidCallback onFieldSubmitted) {
                  if (_customerNameController.text != fieldTextEditingController.text) {
                    fieldTextEditingController.text = _customerNameController.text;
                  }
                  return TextFormField(
                    controller: fieldTextEditingController,
                    focusNode: fieldFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Nama Pelanggan',
                      suffixIcon: _isLoadingCustomers
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : null,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Nama tidak boleh kosong';
                      }
                      return null;
                    },
                  );
                },
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
                decoration: const InputDecoration(labelText: 'Catatan Lain (Opsional)'),
              ),
              const SizedBox(height: 16),
              const Divider(),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, color: Colors.grey, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_calendar_outlined, color: Colors.blue),
                    onPressed: () => _selectDate(context),
                    tooltip: 'Ubah Tanggal',
                  ),
                ],
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