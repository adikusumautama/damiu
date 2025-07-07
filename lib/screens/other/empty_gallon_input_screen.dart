// lib/screens/other/empty_gallon_input_screen.dart
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EmptyGallonInputScreen extends StatefulWidget {
  const EmptyGallonInputScreen({super.key});
  @override
  State<EmptyGallonInputScreen> createState() => _EmptyGallonInputScreenState();
}

class _EmptyGallonInputScreenState extends State<EmptyGallonInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _gallonQuantityController = TextEditingController();
  bool _isLoading = false;
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _gallonQuantityController.dispose();
    super.dispose();
  }

  Future<void> _saveEmptyGallons() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final employeeUid = _authService.getCurrentUser()?.uid;
      if (employeeUid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Error: Pengguna tidak ditemukan.'),
                backgroundColor: Colors.red),
          );
        }
        return;
      }

      final quantity = int.parse(_gallonQuantityController.text);

      // Panggil kedua fungsi Firestore. SDK akan menangani antrean saat offline.
      final error1 = await _firestoreService.incrementEmptyStock(
        quantity: quantity,
        updatedByUid: employeeUid,
      );

      final error2 = await _firestoreService.addReturnedGallonLog(
        quantity: quantity,
        employeeUid: employeeUid,
      );

      if (mounted) {
        if (error1 == null && error2 == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Berhasil! Data akan disinkronkan saat kembali online.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          final combinedError = [error1, error2].where((e) => e != null).join('\n');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Gagal memperbarui data: $combinedError'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      // Menangkap error tak terduga (misalnya, jika plugin Firestore sendiri error)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red));
      }
    } finally {
      // Blok ini akan selalu dieksekusi, memastikan loading indicator dimatikan.
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Input Galon Kosong Kembali')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Masukkan jumlah galon kosong yang kembali dari pengantaran.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _gallonQuantityController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Galon Kosong',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.hourglass_empty_outlined),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) =>
                    (v == null ||
                        v.isEmpty ||
                        int.tryParse(v) == null ||
                        int.parse(v) <= 0)
                    ? 'Masukkan jumlah valid'
                    : null,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Simpan Data'),
                      onPressed: _saveEmptyGallons,
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
