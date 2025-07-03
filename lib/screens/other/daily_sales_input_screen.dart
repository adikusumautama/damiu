// lib/screens/other/daily_sales_input_screen.dart

import 'package:damiu/models/delivery_log_model.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/services/database_helper.dart';
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
  bool _isLoading = false;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _gallonQuantityController.dispose();
    super.dispose();
  }

  Future<void> _saveDeliveryLog() async {
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

      final logItem = DeliveryLogItem(
        timestamp: DateTime.now(),
        gallons: int.parse(_gallonQuantityController.text),
        emptyGallonsReturned: 0, // Ini adalah log pengeluaran, jadi galon kembali 0
        employeeUid: employeeUid,
      );

      try {
        await _dbHelper.insertDeliveryLog(logItem);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Log pengantaran berhasil disimpan!')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan log: $e')),
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
        title: const Text('Input Penjualan/Pengantaran'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Catat jumlah galon yang keluar untuk diantar.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _gallonQuantityController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Galon Keluar',
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
                      label: const Text('Simpan Log'),
                      onPressed: _saveDeliveryLog,
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