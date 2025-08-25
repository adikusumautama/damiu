// lib/screens/other/order_input_screen.dart

import 'package:damiu/models/customer_model.dart';
import 'package:damiu/models/order_model.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:collection/collection.dart';

class OrderInputScreen extends StatefulWidget {
  const OrderInputScreen({super.key});

  @override
  State<OrderInputScreen> createState() => _OrderInputScreenState();
}

class _OrderInputScreenState extends State<OrderInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _gallonQuantityController = TextEditingController();
  final _otherItemsController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  List<Customer> _allCustomers = [];
  Customer? _selectedCustomer; // Untuk melacak pelanggan yang dipilih dari autocomplete

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
    });
    // Ambil data pelanggan langsung dari Firestore
    final customers = await _firestoreService.getAllCustomersOnce();
    if (mounted) {
      setState(() {
        _allCustomers = customers;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _gallonQuantityController.dispose();
    _otherItemsController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveOrder() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final String? employeeUid = _authService.getCurrentUser()?.uid;
      if (employeeUid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Pengguna tidak login.')),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      final customerName = _customerNameController.text.trim();
      final address = _addressController.text.trim();
      final phoneNumber = _phoneController.text.trim();

      // Buat objek pesanan untuk disimpan langsung ke Firestore.
      // Logika upsert pelanggan sudah ditangani di dalam firestoreService.
      final newOrder = Order(
        customerName: customerName,
        gallonQuantity: int.parse(_gallonQuantityController.text),
        otherItems: _otherItemsController.text.trim().isNotEmpty ? _otherItemsController.text.trim() : null,
        address: address.isNotEmpty ? address : null,
        phoneNumber: phoneNumber.isNotEmpty ? phoneNumber : null,
        status: OrderStatus.pending,
        createdAt: DateTime.now(),
        employeeUid: employeeUid,
        isSynced: true, // Selalu true, Firestore yang akan menangani antrean offline
      );

      try {
        // Simpan pesanan dan upsert pelanggan ke Firestore
        await _firestoreService.addOrderAndUpsertCustomer(newOrder);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pesanan berhasil disimpan!')),
          );
          Navigator.pop(context, true); // Kirim sinyal bahwa ada perubahan
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan pesanan: $e')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catat Pesanan Masuk'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Isi detail pesanan yang masuk dari pelanggan.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Widget Autocomplete
              Autocomplete<Customer>(
                displayStringForOption: (Customer option) => option.name,
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') {
                    return const Iterable<Customer>.empty();
                  }
                  return _allCustomers.where((Customer option) {
                    return option.name
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (Customer selection) {
                  setState(() => _selectedCustomer = selection);
                  _customerNameController.text = selection.name;
                  _addressController.text = selection.address ?? '';
                  _phoneController.text = selection.phoneNumber ?? '';
                },
                fieldViewBuilder: (BuildContext context,
                    TextEditingController fieldController,
                    FocusNode fieldFocusNode,
                    VoidCallback onFieldSubmitted) {
                  // Sinkronisasi controller dari Autocomplete ke controller state
                  if (_customerNameController.text != fieldController.text) {
                    _customerNameController.text = fieldController.text;
                    // Reset _selectedCustomer jika pengguna mengetik manual
                    setState(() => _selectedCustomer = null);
                  }
                  return TextFormField(
                    controller: fieldController,
                    focusNode: fieldFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Cari atau Masukkan Nama Pelanggan',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_search_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Nama pelanggan tidak boleh kosong';
                      }
                      return null;
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gallonQuantityController,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Galon',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_drink_outlined),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Jumlah galon tidak boleh kosong';
                  }
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Masukkan jumlah yang valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _otherItemsController,
                decoration: const InputDecoration(
                  labelText: 'Pesanan Lain (Opsional)',
                  hintText: 'Contoh: Gas 3kg: 1, Tisu: 2',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.add_shopping_cart_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Alamat (Otomatis terisi jika ada)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'No. Telepon/WA (Otomatis terisi jika ada)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Simpan Pesanan'),
                      onPressed: _saveOrder,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}