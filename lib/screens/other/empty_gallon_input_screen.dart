// lib/screens/other/empty_gallon_input_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:damiu/models/delivery_log_model.dart';
import 'package:damiu/services/database_helper.dart';
import 'package:damiu/services/auth_service.dart';

class EmptyGallonInputScreen extends StatefulWidget {
  const EmptyGallonInputScreen({super.key});

  @override
  State<EmptyGallonInputScreen> createState() => _EmptyGallonInputScreenState();
}

class _EmptyGallonInputScreenState extends State<EmptyGallonInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emptyGallonsController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emptyGallonsController.dispose();
    super.dispose();
  }

  Future<void> _saveLog() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final int emptyGallons = int.parse(_emptyGallonsController.text);
      final String? employeeUid = AuthService().getCurrentUser()?.uid;

      if (employeeUid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Pengguna tidak login.')),
          );
        }
        setState(() { _isLoading = false; });
        return;
      }

      // Membuat log transaksi khusus untuk galon kosong yang kembali
      final DeliveryLogItem newLog = DeliveryLogItem(
        timestamp: DateTime.now(),
        gallons: 0, // Tidak ada galon isi yang diantar pada transaksi ini
        emptyGallonsReturned: emptyGallons,
        employeeUid: employeeUid,
        isSummarized: false,
      );

      final dbHelper = DatabaseHelper();
      try {
        int id = await dbHelper.insertDeliveryLog(newLog);
        if (mounted) {
          if (id > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Data galon kosong berhasil disimpan!')),
            );
            _emptyGallonsController.clear();
            Navigator.pop(context, true); // Kembali dengan status sukses
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gagal menyimpan data.')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan data: ${e.toString()}')),
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
        title: const Text('Input Galon Kosong Kembali'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Catat jumlah galon kosong yang Anda terima kembali dari pelanggan.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emptyGallonsController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Galon Kosong Diterima',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Masukkan jumlah galon kosong';
                  }
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Masukkan angka positif yang valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveLog,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Simpan', style: TextStyle(fontSize: 16)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}