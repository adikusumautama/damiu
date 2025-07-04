import 'package:damiu/models/customer_model.dart';
import 'package:damiu/models/daily_stock_model.dart';
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

class _LocalSalesManagementWidgetState
    extends State<LocalSalesManagementWidget> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AuthService _authService = AuthService();

  List<DeliveryLogItem> _localDeliveryLogs = [];
  List<DailyStock> _localStockData = [];
  List<Customer> _localCustomers = [];

  Map<String, String> _employeeNames = {};
  bool _isLoading = true;
  int _totalLogs = 0;
  int _totalGallonsInLogs = 0;

  @override
  void initState() {
    super.initState();
    _refreshAllData();
  }

  Future<void> _refreshAllData() async {
    setState(() {
      _isLoading = true;
    });
    await Future.wait([
      _loadLocalDeliveryLogs(),
      _loadLocalStockData(),
      _loadLocalCustomers(),
    ]);
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLocalDeliveryLogs() async {
    final logs = await _dbHelper.getAllDeliveryLogs();
    int totalGallons = 0;
    int actualLogsCount = 0;
    _employeeNames.clear();

    for (var log in logs) {
      totalGallons += log.gallons;
      if (!log.isNoDeliveryMarker && log.gallons > 0) {
        actualLogsCount++;
      }
      if (!_employeeNames.containsKey(log.employeeUid)) {
        final employeeName = await _getEmployeeName(log.employeeUid);
        if (mounted) {
          _employeeNames[log.employeeUid] = employeeName;
        }
      }
    }
    if (mounted) {
      setState(() {
        _localDeliveryLogs = logs;
        _totalLogs = actualLogsCount;
        _totalGallonsInLogs = totalGallons;
      });
    }
  }

  Future<void> _loadLocalStockData() async {
    try {
      final stocks = await _dbHelper.getAllLocalStocks();
      if (mounted) {
        setState(() {
          _localStockData = stocks;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data stok lokal: $e')),
        );
      }
    }
  }

  Future<void> _loadLocalCustomers() async {
    try {
      final customers = await _dbHelper.getAllCustomers();
      if (mounted) {
        setState(() {
          _localCustomers = customers;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data pelanggan: $e')),
        );
      }
    }
  }

  Future<void> _deleteLog(int id) async {
    await _dbHelper.deleteDeliveryLog(id);
    _refreshAllData();
  }

  Future<void> _deleteAllLogs() async {
    final bool confirm =
        await showDialog(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Konfirmasi Hapus Semua Log'),
            content: const Text(
              'Anda yakin ingin menghapus SEMUA log pengantaran lokal?',
            ),
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
          ),
        ) ??
        false;

    if (confirm) {
      await _dbHelper.deleteAllDeliveryLogs();
      _refreshAllData();
    }
  }

  Future<void> _deleteSummarizedLogs() async {
    await _dbHelper.deleteSummarizedDeliveryLogs();
    _refreshAllData();
  }

  Future<void> _deleteStock(String dateId) async {
    await _dbHelper.deleteDailyStock(dateId);
    _refreshAllData();
  }

  Future<void> _deleteAllStocks() async {
    final bool confirm =
        await showDialog(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Konfirmasi Hapus Semua Stok'),
            content: const Text(
              'Anda yakin ingin menghapus SEMUA data stok awal lokal?',
            ),
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
          ),
        ) ??
        false;

    if (confirm) {
      await _dbHelper.deleteAllDailyStocks();
      _refreshAllData();
    }
  }

  Future<void> _deleteCustomer(int id) async {
    final bool confirm =
        await showDialog(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Konfirmasi Hapus'),
            content: const Text(
              'Anda yakin ingin menghapus data pelanggan ini?',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Batal'),
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Hapus'),
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        await _dbHelper.deleteCustomer(id);
        _refreshAllData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus pelanggan: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteAllCustomers() async {
    final bool confirm =
        await showDialog(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Hapus Semua Pelanggan'),
            content: const Text(
              'ANDA YAKIN ingin menghapus SEMUA data pelanggan dari perangkat ini? Tindakan ini tidak dapat dibatalkan.',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Batal'),
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Ya, Hapus Semua'),
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        await _dbHelper.deleteAllCustomers();
        _refreshAllData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus semua pelanggan: $e')),
          );
        }
      }
    }
  }

  Future<void> _showEditCustomerDialog(Customer customer) async {
    final _formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: customer.name);
    final addressController = TextEditingController(text: customer.address);
    final phoneController = TextEditingController(text: customer.phoneNumber);

    final updatedCustomer = await showDialog<Customer>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${customer.name}'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nama'),
                validator: (val) =>
                    val!.isEmpty ? 'Nama tidak boleh kosong' : null,
              ),
              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Alamat (Opsional)',
                ),
              ),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'No. HP (Opsional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            child: const Text('Simpan'),
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final newCustomer = customer.copyWith(
                  name: nameController.text,
                  address: addressController.text,
                  phoneNumber: phoneController.text,
                );
                Navigator.pop(context, newCustomer);
              }
            },
          ),
        ],
      ),
    );

    if (updatedCustomer != null) {
      try {
        await _dbHelper.updateCustomer(updatedCustomer);
        _refreshAllData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memperbarui pelanggan: $e')),
          );
        }
      }
    }
  }

  Future<void> _showEditLogDialog(DeliveryLogItem log) async {
    // ... (kode fungsi ini tidak berubah)
  }

  Future<void> _showEditStockDialog(DailyStock stock) async {
    // ... (kode fungsi ini tidak berubah)
  }

  Future<String> _getEmployeeName(String? employeeUid) async {
    if (employeeUid == null || employeeUid.isEmpty) {
      return 'Tidak diketahui';
    }
    if (_employeeNames.containsKey(employeeUid)) {
      return _employeeNames[employeeUid]!;
    }
    try {
      final UserModel? userModel = await _authService.getUserModel(employeeUid);
      final userName = userModel?.name ?? 'Nama tidak ditemukan';
      if (mounted) {
        _employeeNames[employeeUid] = userName;
      }
      return userName;
    } catch (e) {
      return 'Gagal memuat nama';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.delivery_dining_outlined),
                text: 'Log Pengantaran',
              ),
              Tab(
                icon: Icon(Icons.inventory_2_outlined),
                text: 'Data Stok Awal',
              ),
              Tab(icon: Icon(Icons.people_outline), text: 'Pelanggan'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildDeliveryLogView(),
                _buildStockDataView(),
                _buildCustomerDataView(),
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
                  const Text(
                    'Ringkasan Log Pengantaran Lokal (delivery_log)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _isLoading
                      ? const LinearProgressIndicator()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pengantaran: $_totalLogs' + ' kali'),
                            Text(
                              'Total Galon dari Log: $_totalGallonsInLogs galon',
                            ),
                          ],
                        ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Tooltip(
                        message: 'Hapus semua log yang sudah diringkas',
                        child: TextButton.icon(
                          icon: Icon(
                            Icons.delete_sweep_outlined,
                            color: Colors.orange[700],
                          ),
                          label: Text(
                            'Hapus Diringkas',
                            style: TextStyle(color: Colors.orange[700]),
                          ),
                          onPressed: _isLoading ? null : _deleteSummarizedLogs,
                        ),
                      ),
                      Tooltip(
                        message: 'Hapus semua log pengantaran',
                        child: TextButton.icon(
                          icon: const Icon(
                            Icons.delete_forever_outlined,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'Hapus Semua',
                            style: TextStyle(color: Colors.red),
                          ),
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
                    child: Text('Tidak ada log pengantaran tersimpan.'),
                  )
                : ListView.builder(
                    itemCount: _localDeliveryLogs.length,
                    itemBuilder: (context, index) {
                      final log = _localDeliveryLogs[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: ListTile(
                          title: Text(
                            'Waktu: ${DateFormat('dd MMM kk:mm', 'id_ID').format(log.timestamp)}',
                          ),
                          subtitle: Text(
                            'Galon: ${log.gallons} - Karyawan: ${_employeeNames[log.employeeUid] ?? "Memuat..."}\nStatus: ${log.isSummarized ? "Sudah Diringkas" : "Belum Diringkas"}',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  color: Theme.of(context).primaryColor,
                                ),
                                onPressed: log.isSummarized
                                    ? null
                                    : () => _showEditLogDialog(log),
                                tooltip: log.isSummarized
                                    ? "Tidak bisa edit log yang sudah diringkas"
                                    : "Edit Log",
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete,
                                  color: Colors.red[700],
                                ),
                                onPressed: () => _deleteLog(log.id!),
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
                  const Text(
                    'Data Stok Awal Lokal (daily_stock)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _isLoading
                      ? const LinearProgressIndicator()
                      : Text(
                          'Total Data Tersimpan: ${_localStockData.length} hari',
                        ),
                  const SizedBox(height: 10),
                  Center(
                    child: Tooltip(
                      message: 'Hapus semua data stok awal lokal',
                      child: TextButton.icon(
                        icon: const Icon(
                          Icons.delete_forever_outlined,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Hapus Semua Stok',
                          style: TextStyle(color: Colors.red),
                        ),
                        onPressed: _isLoading || _localStockData.isEmpty
                            ? null
                            : _deleteAllStocks,
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
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: ListTile(
                          title: Text(
                            'Tanggal: ${DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(DateTime.parse(stock.id))}',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Stok Isi: ${stock.initialStock} Galon'),
                              Text(
                                'Stok Kosong: ${stock.initialEmptyStock} Galon',
                              ),
                              FutureBuilder<String>(
                                future: _getEmployeeName(stock.updatedByUid),
                                builder: (context, snapshot) {
                                  return Text(
                                    'Diupdate oleh: ${snapshot.data ?? "Memuat..."}',
                                  );
                                },
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  color: Theme.of(context).primaryColor,
                                ),
                                onPressed: () => _showEditStockDialog(stock),
                                tooltip: 'Edit Stok',
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete,
                                  color: Colors.red[700],
                                ),
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

  Widget _buildCustomerDataView() {
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
                  const Text(
                    'Data Pelanggan Lokal (customers)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _isLoading
                      ? const LinearProgressIndicator()
                      : Text('Total Pelanggan: ${_localCustomers.length}'),
                  const SizedBox(height: 10),
                  Center(
                    child: Tooltip(
                      message: 'Hapus semua data pelanggan dari perangkat ini',
                      child: TextButton.icon(
                        icon: const Icon(
                          Icons.delete_forever_outlined,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Hapus Semua Pelanggan',
                          style: TextStyle(color: Colors.red),
                        ),
                        onPressed: _isLoading || _localCustomers.isEmpty
                            ? null
                            : _deleteAllCustomers,
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
                : _localCustomers.isEmpty
                ? const Center(
                    child: Text('Tidak ada data pelanggan tersimpan.'),
                  )
                : ListView.builder(
                    itemCount: _localCustomers.length,
                    itemBuilder: (context, index) {
                      final customer = _localCustomers[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: ListTile(
                          title: Text(customer.name),
                          subtitle: Text(
                            'Alamat: ${customer.address ?? '-'}\nNo HP: ${customer.phoneNumber ?? '-'}',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  color: Theme.of(context).primaryColor,
                                ),
                                onPressed: () =>
                                    _showEditCustomerDialog(customer),
                                tooltip: 'Edit Pelanggan',
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete,
                                  color: Colors.red[700],
                                ),
                                onPressed: () => _deleteCustomer(customer.id!),
                                tooltip: 'Hapus Pelanggan',
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
}
