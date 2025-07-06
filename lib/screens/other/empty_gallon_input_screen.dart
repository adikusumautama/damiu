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

  Future<void> _saveRestock() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final employeeUid = _authService.getCurrentUser()?.uid;
    if (employeeUid == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Pengguna tidak ditemukan.')),
        );
      setState(() => _isLoading = false);
      return;
    }

    final quantity = int.parse(_gallonQuantityController.text);
    // --- PERBAIKAN: Panggil `adjustCurrentStock` yang sudah diperbaiki logikanya ---
    // Fungsi ini sekarang menambah stok awal dan stok tersedia secara bersamaan.
    final stockError = await _firestoreService.adjustCurrentStock(quantity);

    // CATATAN: Log ini secara semantik mencatat "galon kembali", bukan "restock".
    // Pertimbangkan untuk membuat fungsi log baru khusus untuk restock jika diperlukan.
    await _firestoreService.addReturnedGallonLog(
      quantity: quantity,
      employeeUid: employeeUid,
    );

    if (mounted) {
      if (stockError == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berhasil menambah data stok!')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui data: $stockError')),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Stok Galon Isi (Restock)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Masukkan jumlah galon isi yang baru masuk untuk ditambahkan ke stok tersedia hari ini.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _gallonQuantityController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Galon Isi',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory_2_outlined),
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
                      label: const Text('Simpan & Tambah Stok'),
                      onPressed: _saveRestock,
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
