// lib/screens/other/local_sales_management_screen.dart
import 'package:damiu/models/delivery_log_model.dart';
import 'package:damiu/models/daily_stock_model.dart';
import 'package:damiu/models/user_model.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/services/database_helper.dart'; // Pastikan ini ada
import 'package:damiu/services/firestore_service.dart'; // Pastikan ini ada
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
  List<DailyStock> _localStockData = [];

  Map<String, String> _employeeNames = {}; // UID -> Nama Karyawan
  bool _isLoading = true;
  int _totalLogs = 0;
  int _totalGallonsInLogs = 0;


  @override
  void initState() {
    super.initState();
    _refreshAllData();
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

  Future<void> _loadLocalStockData() async {
    setState(() { _isLoading = true; });
    try {
      final stocks = await _dbHelper.getAllLocalStocks();
      if (mounted) {
        setState(() {
          _localStockData = stocks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memuat data stok lokal: $e')));
      }
    }
  }

  Future<void> _refreshAllData() => Future.wait([_loadLocalDeliveryLogs(), _loadLocalStockData()]);

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

  Future<void> _deleteStock(String dateId) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text('Anda yakin ingin menghapus data stok tanggal $dateId?'),
        actions: <Widget>[
          TextButton(child: const Text('Batal'), onPressed: () => Navigator.of(ctx).pop(false)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await _dbHelper.deleteDailyStock(dateId);
      _loadLocalStockData();
    }
  }

  Future<void> _deleteAllStocks() async {
    final bool confirm = await showDialog(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Konfirmasi Hapus Semua Stok'),
        content: const Text('Anda yakin ingin menghapus SEMUA data stok awal lokal?'),
        actions: <Widget>[
          TextButton(child: const Text('Batal'), onPressed: () => Navigator.of(ctx).pop(false)),
          TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Hapus Semua'), onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await _dbHelper.deleteAllDailyStocks();
      _loadLocalStockData();
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

  Future<void> _showEditStockDialog(DailyStock stock) async {
    final TextEditingController filledStockController = TextEditingController(text: stock.initialStock.toString());
    final TextEditingController emptyStockController = TextEditingController(text: stock.initialEmptyStock.toString());
    final formKey = GlobalKey<FormState>();

    final newStockValues = await showDialog<Map<String, int>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Stok Awal (${stock.id})'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: filledStockController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Jumlah Stok Galon Isi'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Jumlah tidak boleh kosong';
                    if (int.tryParse(value) == null || int.parse(value) < 0) return 'Masukkan angka valid';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emptyStockController,
                  decoration: const InputDecoration(labelText: 'Jumlah Galon Kosong Dibawa (Opsional)'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(child: const Text('Batal'), onPressed: () => Navigator.of(context).pop()),
            TextButton(
              child: const Text('Simpan'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop({
                    'filled': int.parse(filledStockController.text),
                    'empty': int.tryParse(emptyStockController.text) ?? 0,
                  });
                }
              },
            ),
          ],
        );
      },
    );

    if (newStockValues != null) {
      final updatedStock = DailyStock(
        id: stock.id,
        initialStock: newStockValues['filled']!,
        initialEmptyStock: newStockValues['empty']!,
        lastUpdated: DateTime.now(),
        updatedByUid: _authService.getCurrentUser()?.uid,
      );

      // Update lokal dan firestore
      await _dbHelper.upsertDailyStock(updatedStock);
      final firestoreService = FirestoreService();
      firestoreService.setInitialStock(
        date: DateTime.parse(updatedStock.id),
        filledStock: updatedStock.initialStock,
        emptyStock: updatedStock.initialEmptyStock,
        updatedByUid: updatedStock.updatedByUid!,
      );

      _loadLocalStockData(); // Muat ulang data untuk tampilan
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data stok berhasil diperbarui.')),
        );
      }
    }
  }

  // Fungsi pembantu untuk mendapatkan nama karyawan dari UID
  Future<String> _getEmployeeName(String? employeeUid) async {
    if (employeeUid == null || employeeUid.isEmpty) { // Handle nullable UID
      return 'Tidak diketahui';
    }
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
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.delivery_dining_outlined), text: 'Log Pengantaran'),
              Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Data Stok Awal'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildDeliveryLogView(),
                _buildStockDataView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryLogView() {
    return RefreshIndicator(
      onRefresh: _refreshAllData,
      child: Column(
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
                                  'Galon: ${log.gallons} - Karyawan: ${_employeeNames[log.employeeUid] ?? "Memuat..."}\nStatus: ${log.isSummarized ? "Sudah Diringkas" : "Belum Diringkas"}'),
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
      ),
    );
  }

  Widget _buildStockDataView() {
    return RefreshIndicator(
      onRefresh: _refreshAllData,
      child: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(8.0),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Data Stok Awal Lokal (daily_stock)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _isLoading
                      ? const LinearProgressIndicator()
                      : Text('Total Data Tersimpan: ${_localStockData.length} hari'),
                  const SizedBox(height: 10),
                  Center(
                    child: Tooltip(
                      message: 'Hapus semua data stok awal lokal',
                      child: TextButton.icon(
                        icon: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                        label: const Text('Hapus Semua Stok', style: TextStyle(color: Colors.red)),
                        onPressed: _isLoading || _localStockData.isEmpty ? null : _deleteAllStocks,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _localStockData.isEmpty
                    ? const Center(child: Text('Tidak ada data stok tersimpan.'))
                    : ListView.builder(
                        itemCount: _localStockData.length,
                        itemBuilder: (context, index) {
                          final stock = _localStockData[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: ListTile(
                              title: Text('Tanggal: ${DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(DateTime.parse(stock.id))}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Stok Isi: ${stock.initialStock} Galon'),
                                  Text('Stok Kosong: ${stock.initialEmptyStock} Galon'),
                                  FutureBuilder<String>(
                                    future: _getEmployeeName(stock.updatedByUid),
                                    builder: (context, snapshot) {
                                      return Text('Diupdate oleh: ${snapshot.data ?? "Memuat..."}');
                                    },
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: Theme.of(context).primaryColor),
                                    onPressed: () => _showEditStockDialog(stock),
                                    tooltip: 'Edit Stok',
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red[700]),
                                    onPressed: () => _deleteStock(stock.id),
                                    tooltip: 'Hapus Stok',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
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
                final logId = log.id;
                if (logId != null) { // Safer null check
                  _deleteLog(logId);
                }
              },
            ),
          ],
        );
      },
    );
  }
}