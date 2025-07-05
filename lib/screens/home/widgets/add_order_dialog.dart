import 'package:flutter/material.dart';
import 'package:damiu/models/customer_model.dart';
import 'package:damiu/services/database_helper.dart';
import 'package:damiu/screens/home/widgets/customer_autocomplete_field.dart';
import 'package:collection/collection.dart';

class AddOrderDialog extends StatefulWidget {
  final void Function({
    required String customerName,
    required int gallonQuantity,
    String? otherItems,
    String? address,
    String? phoneNumber,
    required DateTime date,
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

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  List<Customer> _customers = [];
  bool _loadingCustomers = false;
  Customer? _selectedCustomer;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _loadingCustomers = true);
    final data = await _dbHelper.getAllCustomers();
    if (mounted) {
      setState(() {
        _customers = data;
        _loadingCustomers = false;
      });
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
              Row(
                children: [
                  Expanded(
                    child: Text('Tanggal: \\${_selectedDate.day.toString().padLeft(2, '0')}-\\${_selectedDate.month.toString().padLeft(2, '0')}-\\${_selectedDate.year}  Jam: \\${_selectedTime.format(context)}'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    tooltip: 'Pilih Tanggal',
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(DateTime.now().year - 1),
                        lastDate: DateTime(DateTime.now().year + 2),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.access_time),
                    tooltip: 'Pilih Jam',
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                      );
                      if (picked != null) {
                        setState(() => _selectedTime = picked);
                      }
                    },
                  ),
                ],
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
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final name = _nameController.text.trim();
              final address = _addressController.text.trim().isEmpty ? null : _addressController.text.trim();
              final phone = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();

              // Cek apakah pelanggan dengan nama ini sudah ada.
              final existingCustomer = _customers.firstWhereOrNull(
                (c) => c.name.toLowerCase() == name.toLowerCase(),
              );

              if (existingCustomer == null) {
                // Pelanggan baru, simpan ke database lokal.
                final newCustomer = Customer(
                  name: name,
                  address: address,
                  phoneNumber: phone,
                  createdAt: DateTime.now(),
                  isSynced: false, // Tandai untuk sinkronisasi
                );
                await _dbHelper.upsertCustomer(newCustomer);
              } else {
                // Pelanggan sudah ada, cek apakah ada perubahan data.
                if (existingCustomer.address != address || existingCustomer.phoneNumber != phone) {
                  final updatedCustomer = existingCustomer.copyWith(
                    address: address,
                    phoneNumber: phone,
                    isSynced: false, // Tandai untuk disinkronkan
                  );
                  await _dbHelper.updateCustomer(updatedCustomer);
                }
              }

              // Kirim data pesanan ke pemanggil untuk diproses
              widget.onSubmit(
                customerName: name,
                gallonQuantity: int.parse(_gallonController.text.trim()),
                otherItems: _otherItemsController.text.trim().isEmpty ? null : _otherItemsController.text.trim(),
                address: address,
                phoneNumber: phone,
                date: DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                  _selectedTime.hour,
                  _selectedTime.minute,
                ),
              );
              Navigator.pop(context);
            }
          },
          child: const Text('Catat'),
        ),
      ],
    );
  }
}
