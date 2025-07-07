// lib/screens/other/daily_sales_input_screen.dart

import 'package:damiu/models/order_model.dart'; // PERBAIKAN: Menggunakan OrderModel
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DailySalesInputScreen extends StatefulWidget {
  const DailySalesInputScreen({super.key});

  @override
  State<DailySalesInputScreen> createState() => _DailySalesInputScreenState();
}

class _DailySalesInputScreenState extends State<DailySalesInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _gallonQuantityController = TextEditingController();
  final _customerNameController = TextEditingController(); // Tambahan untuk nama pelanggan
  bool _isLoading = false;
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _gallonQuantityController.dispose();
    _customerNameController.dispose();
    super.dispose();
  }

  // --- PERBAIKAN: Logika diubah dari mencatat log menjadi membuat pesanan ---
  Future<void> _saveDirectOrder() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final String? employeeUid = _authService.getCurrentUser()?.uid;
      if (employeeUid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Pengguna tidak ditemukan.')),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      // Membuat objek Order, bukan DeliveryLogItem
      final newOrder = Order(
        customerName: _customerNameController.text.isNotEmpty ? _customerNameController.text : 'Pelanggan Langsung',
        gallonQuantity: int.parse(_gallonQuantityController.text),
        status: OrderStatus.pending, // Status awal adalah pending
        createdAt: DateTime.now(),
        employeeUid: employeeUid,
        isSynced: true, // Selalu true, Firestore yang akan menangani antrean offline
      );

      try {
        await _firestoreService.addOrderAndUpsertCustomer(newOrder); // Menggunakan service Firestore
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pesanan langsung berhasil disimpan!')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan pesanan: $e')),
          );
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
        title: const Text('Input Pesanan Langsung'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Catat pesanan yang terjadi secara langsung (tanpa melalui daftar pesanan).',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
               TextFormField(
                controller: _customerNameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Pelanggan (Opsional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gallonQuantityController,
                autofocus: true,
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
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Simpan Pesanan'),
                      onPressed: _saveDirectOrder,
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