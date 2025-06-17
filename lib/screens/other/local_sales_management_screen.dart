// lib/screens/other/local_sales_management_screen.dart
import 'package:damiu/models/delivery_log_model.dart';
import 'package:damiu/models/user_model.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/services/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class LocalSalesManagementWidget extends StatefulWidget {
  const LocalSalesManagementWidget({super.key});

  @override
  State<LocalSalesManagementWidget> createState() =>
      _LocalSalesManagementWidgetState();
}

class _LocalSalesManagementWidgetState extends State<LocalSalesManagementWidget> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AuthService _authService = AuthService(); // Tambahkan AuthService
  List<DeliveryLogItem> _localDeliveryLogs = [];
  Map<String, String> _employeeNames = {}; // UID -> Nama Karyawan
  bool _isLoading = true;
  int _totalLogs = 0;
  int _totalGallonsInLogs = 0;

  @override
  void initState() {
    super.initState();
    _loadLocalDeliveryLogs();
  }

  Future<void> _loadLocalDeliveryLogs() async {
    setState(() {
      _isLoading = true;
      _localDeliveryLogs = [];
      _totalLogs = 0; // Reset total logs
      _employeeNames = {};
      _totalGallonsInLogs = 0;
    });
    try {
      final logs = await _dbHelper.getAllDeliveryLogs();
      int totalGallons = 0;
      int actualLogsCount = 0; // Counter untuk log yang valid
      for (var log in logs) {
        totalGallons += log.gallons;
        // Hanya hitung sebagai log jika bukan marker "tidak ada pengantaran" DAN galonnya lebih dari 0
        if (!log.isNoDeliveryMarker && log.gallons > 0) {
          actualLogsCount++;
        }
        // Muat nama karyawan secara terpisah (dan efisien jika diperlukan)
        if (!_employeeNames.containsKey(log.employeeUid)) {
          final employeeName = await _getEmployeeName(log.employeeUid);
          _employeeNames[log.employeeUid] = employeeName;
        }
      }
      if (mounted) {
         setState(() {
           _localDeliveryLogs = logs;
           _totalLogs = actualLogsCount; // Gunakan counter log yang valid
           _totalGallonsInLogs = totalGallons;
           _isLoading = false;
         });
       }
    } on Exception catch (e) {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memuat log pengantaran: $e')));
      }
    }
  }

  Future<void> _deleteLog(int id) async {
    try {
      await _dbHelper.deleteDeliveryLog(id);
      _loadLocalDeliveryLogs(); // Muat ulang data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log pengantaran berhasil dihapus.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus log: $e')));
      }
    }
  }

  Future<void> _deleteAllLogs() async {
    final bool confirm = await showDialog(
          context: context,
          builder: (BuildContext ctx) {
            return AlertDialog(
              title: const Text('Konfirmasi Hapus Semua Log'),
              content: const Text(
                  'Anda yakin ingin menghapus SEMUA log pengantaran lokal?'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Batal'),
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Hapus Semua'),
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirm) {
      try {
        await _dbHelper.deleteAllDeliveryLogs();
        _loadLocalDeliveryLogs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Semua log pengantaran lokal berhasil dihapus.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Gagal menghapus semua log pengantaran: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteSummarizedLogs() async {
    final bool confirm = await showDialog(
          context: context,
          builder: (BuildContext ctx) {
            return AlertDialog(
              title: const Text('Konfirmasi Hapus Log Diringkas'),
              content: const Text(
                  'Anda yakin ingin menghapus SEMUA log pengantaran lokal yang SUDAH DIRINGKAS?'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Batal'),
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.orange[700]),
                  child: const Text('Hapus Log Diringkas'),
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirm) {
      try {
        await _dbHelper.deleteSummarizedDeliveryLogs();
        _loadLocalDeliveryLogs(); // Muat ulang data
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Semua log pengantaran yang sudah diringkas berhasil dihapus.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus log yang diringkas: $e')));
        }
      }
    }
  }

  Future<void> _showEditLogDialog(DeliveryLogItem log) async {
    final TextEditingController quantityController =
        TextEditingController(text: log.gallons.toString());
    DateTime selectedDateTime = log.timestamp;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
                'Edit Log Pengantaran (${DateFormat('dd-MM-yyyy HH:mm').format(selectedDateTime)})'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                      'Waktu: ${DateFormat('dd-MM-yyyy HH:mm').format(selectedDateTime)}'),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDateTime,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now());
                    if (pickedDate != null) {
                      final TimeOfDay? pickedTime = await showTimePicker(
                          // ignore: use_build_context_synchronously
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedDateTime));
                      if (pickedTime != null) {
                        setDialogState(() {
                          selectedDateTime = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute);
                        });
                      }
                    }
                  },
                ),
                TextFormField(
                  controller: quantityController,
                  decoration:
                      const InputDecoration(labelText: 'Jumlah Galon'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Masukkan jumlah';
                    if (int.tryParse(value) == null || int.parse(value) <= 0) {
                      return 'Masukkan angka positif';
                    }
                    return null;
                  },
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                  child: const Text('Batal'),
                  onPressed: () => Navigator.of(context).pop()),
              TextButton(
                child: const Text('Simpan'),
                onPressed: () {
                  if (quantityController.text.isNotEmpty &&
                      int.tryParse(quantityController.text) != null &&
                      int.parse(quantityController.text) > 0) {
                    Navigator.of(context).pop({
                      'timestamp': selectedDateTime,
                      'gallons': int.parse(quantityController.text)
                    });
                  }
                },
              ),
            ],
          );
        });
      },
    );

    if (result != null && log.id != null) {
      final DeliveryLogItem updatedLog = DeliveryLogItem(
        id: log.id,
        timestamp: result['timestamp'] as DateTime,
        gallons: result['gallons'] as int,
        employeeUid: log.employeeUid, // Employee UID tidak diubah di sini
        isSummarized: log.isSummarized, // Status isSummarized tidak diubah
      );
      try {
        await _dbHelper.updateDeliveryLog(updatedLog);
        _loadLocalDeliveryLogs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Log berhasil diperbarui.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal memperbarui log: $e')));
        }
      }
    }
  }

  // Fungsi pembantu untuk mendapatkan nama karyawan dari UID
  Future<String> _getEmployeeName(String employeeUid) async {
    try {
      final UserModel? userModel = await _authService.getUserModel(employeeUid);
      if (userModel != null && userModel.name != null && userModel.name!.isNotEmpty) {
        return userModel.name!;
      }
      return 'Nama tidak ditemukan';
    } catch (e) {
      print("Error fetching employee name for UID $employeeUid: $e");
      return 'Gagal memuat nama';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(8.0),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ringkasan Log Pengantaran Lokal (delivery_log)',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _isLoading
                    ? const LinearProgressIndicator()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pengantaran: $_totalLogs' + ' kali'),
                          Text('Total Galon dari Log: $_totalGallonsInLogs galon'),
                        ],
                      ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Tooltip(
                      message: 'Hapus semua log yang sudah diringkas',
                      child: TextButton.icon(
                        icon: Icon(Icons.delete_sweep_outlined, color: Colors.orange[700]),
                        label: Text('Hapus Diringkas', style: TextStyle(color: Colors.orange[700])),
                        onPressed: _isLoading ? null : _deleteSummarizedLogs,
                      ),
                    ),
                    Tooltip(
                      message: 'Hapus semua log pengantaran',
                      child: TextButton.icon(
                        icon: const Icon(Icons.delete_forever_outlined,
                            color: Colors.red),
                        label: const Text('Hapus Semua',
                            style: TextStyle(color: Colors.red)),
                        onPressed: _isLoading ? null : _deleteAllLogs,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _localDeliveryLogs.isEmpty
                  ? const Center(
                      child: Text('Tidak ada log pengantaran tersimpan.'))
                  : ListView.builder(
                      itemCount: _localDeliveryLogs.length,
                      itemBuilder: (context, index) {
                        final log = _localDeliveryLogs[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 4.0),
                          child: ListTile(
                            title: Text(
                                'Waktu: ${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(log.timestamp)}'),
                            subtitle: Text(
                                'Galon: ${log.gallons} - Karyawan: ${_employeeNames[log.employeeUid] ?? "Nama tidak ditemukan"}\nStatus: ${log.isSummarized ? "Sudah Diringkas" : "Belum Diringkas"}'),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit,
                                      color: Theme.of(context).primaryColor),
                                  onPressed: log.isSummarized
                                      ? null // Tidak bisa edit jika sudah diringkas
                                      : () => _showEditLogDialog(log),
                                  tooltip: log.isSummarized
                                      ? "Tidak bisa edit log yang sudah diringkas"
                                      : "Edit Log",
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete,
                                      color: Colors.red[700]),
                                  onPressed: () => _showDeleteConfirmationDialog(log),
                                  tooltip: "Hapus Log",
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _showDeleteConfirmationDialog(DeliveryLogItem log) {
     showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Konfirmasi Hapus'),
          content: Text(
              'Anda yakin ingin menghapus log pengantaran pada ${DateFormat('dd-MM-yyyy HH:mm').format(log.timestamp)}?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: Colors.red),
              child: const Text('Hapus'),
              onPressed: () {
                Navigator.of(ctx).pop();
                if (log.id != null) {
                  _deleteLog(log.id!);
                }
              },
            ),
          ],
        );
      },
    );
  }
}