// lib/screens/employee/daily_sales_input_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:damiu/models/delivery_log_model.dart'; // Ganti ke DeliveryLogItem
import 'package:damiu/services/database_helper.dart';
import 'package:damiu/services/auth_service.dart'; // Untuk mendapatkan UID karyawan
import 'package:intl/intl.dart'; // Tambahkan dependency intl di pubspec.yaml

class DailySalesInputScreen extends StatefulWidget {
  const DailySalesInputScreen({super.key});

  @override
  State<DailySalesInputScreen> createState() => _DailySalesInputScreenState();
}

class _DailySalesInputScreenState extends State<DailySalesInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _quantityController = TextEditingController();
  DateTime _selectedDate = DateTime.now(); // Tetap untuk DatePicker
  TimeOfDay _selectedTime = TimeOfDay.now(); // Untuk TimePicker
  bool _isLoading = false;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(), // Hanya bisa input tanggal hari ini atau sebelumnya
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveSale() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final int quantity = int.parse(_quantityController.text);
      final String? employeeUid = AuthService().getCurrentUser()?.uid; // Ambil UID karyawan yang login

      if (employeeUid == null) {
         // Handle error: user not logged in
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: Pengguna tidak login.')),
            );
         }
         setState(() { _isLoading = false; });
         return;
      }

      final DateTime deliveryTimestamp = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final DeliveryLogItem newLog = DeliveryLogItem(
        timestamp: deliveryTimestamp,
        gallons: quantity, // Ganti 'quantity' menjadi 'gallons'
        employeeUid: employeeUid,
        isSummarized: false, // Baru, belum diringkas
      );

      final dbHelper = DatabaseHelper();
      try {
        int id = await dbHelper.insertDeliveryLog(newLog);
        if (mounted) {
           if (id > 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data pengantaran berhasil disimpan!')),
              );
              // Reset form
              _quantityController.clear();
              Navigator.pop(context, {'saved': true, 'navigateToBeranda': true}); // Kembali dengan hasil Map
              // Tidak perlu reset tanggal/waktu, biarkan untuk input berikutnya jika mirip
           } else {
               ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Gagal menyimpan data pengantaran.')),
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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveNoDeliveryEntry() async {
    setState(() {
      _isLoading = true;
    });

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

    final DateTime entryTimestamp = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final DeliveryLogItem noDeliveryLog = DeliveryLogItem(
      timestamp: entryTimestamp,
      gallons: 0, // Jumlah galon 0
      employeeUid: employeeUid,
      isSummarized: false,
      isNoDeliveryMarker: true, // Tandai sebagai entri "tidak ada pengantaran"
    );

    final dbHelper = DatabaseHelper();
    try {
      int id = await dbHelper.insertDeliveryLog(noDeliveryLog);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(id > 0 ? 'Data "Tidak Ada Pengantaran" berhasil disimpan.' : 'Gagal menyimpan data.')),
        );
        Navigator.pop(context, {'saved': true, 'navigateToBeranda': true});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan data: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Pengantaran Galon'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ListTile(
                title: Text('Tanggal: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}'),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () => _pickDate(context),
              ),
              ListTile(
                title: Text('Waktu: ${_selectedTime.format(context)}'),
                trailing: const Icon(Icons.access_time_outlined),
                onTap: () => _pickTime(context),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: '1', // Default value 1
                decoration: const InputDecoration(
                  labelText: 'Jumlah Pengantaran',
                  border: OutlineInputBorder(),
                  // Bisa tambahkan helperText jika perlu
                  // helperText: 'Setiap input dihitung sebagai 1 pengantaran',
                ),
                enabled: false, // Tidak dapat diubah oleh pengguna
              ),
              const SizedBox(height: 16), // Tambah jarak
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Galon Terjual',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Masukkan jumlah galon';
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
                      onPressed: _saveSale,
                      child: const Text('Simpan Pengantaran'),
                    ),
              const SizedBox(height: 16),
              _isLoading
                  ? const SizedBox.shrink() // Jangan tampilkan tombol kedua jika sedang loading
                  : OutlinedButton(
                      onPressed: _saveNoDeliveryEntry,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Theme.of(context).colorScheme.primary),
                      ),
                      child: const Text('Tidak Ada Pengantaran'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
