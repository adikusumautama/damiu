// lib/screens/other/order_input_screen.dart

import 'package:damiu/models/customer_model.dart';
import 'package:damiu/models/order_model.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/services/database_helper.dart';
// Import FirestoreService
import 'package:damiu/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final DatabaseHelper _dbHelper = DatabaseHelper();
  // Inisialisasi FirestoreService
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  List<Customer> _allCustomers = [];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final customers = await _dbHelper.getAllCustomers();
    if (mounted) {
      setState(() => _allCustomers = customers);
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

  // MODIFIKASI FUNGSI INI
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

      // 1. Simpan/update data pelanggan di database lokal
      final newCustomer = Customer(
        name: _customerNameController.text.trim(),
        address: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
        phoneNumber: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        createdAt: DateTime.now(),
      );
      await _dbHelper.upsertCustomer(newCustomer);
      // Sinkronkan data pelanggan ini ke Firestore (tanpa menunggu selesai)
      _firestoreService.upsertCustomer(newCustomer);


      // 2. Buat objek pesanan
      final newOrder = Order(
        customerName: _customerNameController.text.trim(),
        gallonQuantity: int.parse(_gallonQuantityController.text),
        otherItems: _otherItemsController.text.trim().isNotEmpty
            ? _otherItemsController.text.trim()
            : null,
        address: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
        phoneNumber: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        status: OrderStatus.pending,
        createdAt: DateTime.now(),
        employeeUid: employeeUid,
      );

      try {
        // 3. Simpan pesanan ke database lokal (prioritas utama)
        await _dbHelper.insertOrder(newOrder);

        // 4. Kirim pesanan ke Firestore (tanpa memblokir UI)
        _firestoreService.addOrder(newOrder).then((error) {
          if (error != null) {
            // Jika gagal, tampilkan notifikasi tanpa mengganggu alur utama
            print("Gagal sinkronisasi pesanan ke Firestore: $error");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Gagal sinkronisasi pesanan ke server. Data tersimpan lokal.'),
                    backgroundColor: Colors.orange),
              );
            }
          }
        });

        // 5. Tampilkan pesan sukses dan kembali ke halaman sebelumnya
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pesanan berhasil dicatat!')),
          );
          Navigator.pop(context, true); // Kembali dengan status sukses
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan pesanan: $e')),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (UI tidak ada perubahan, jadi saya potong untuk keringkasan)
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
              Autocomplete<Customer>(
                displayStringForOption: (Customer option) => option.name,
                optionsBuilder: (TextEditingValue textEditingValue) {
                  _customerNameController.text = textEditingValue.text;
                  if (textEditingValue.text.isEmpty) {
                    _addressController.clear();
                    _phoneController.clear();
                  }
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
                  _customerNameController.text = selection.name;
                  _addressController.text = selection.address ?? '';
                  _phoneController.text = selection.phoneNumber ?? '';
                },
                fieldViewBuilder: (BuildContext context,
                    TextEditingController fieldController,
                    FocusNode fieldFocusNode,
                    VoidCallback onFieldSubmitted) {
                  return TextFormField(
                    controller: fieldController,
                    focusNode: fieldFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Cari atau Masukkan Nama Pelanggan',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_search_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty)
                        return 'Nama pelanggan tidak boleh kosong';
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
                  if (int.tryParse(value) == null ||
                      int.parse(value) <= 0) {
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
                  labelText: 'Alamat (Opsional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'No. Telepon/WA (Opsional)',
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