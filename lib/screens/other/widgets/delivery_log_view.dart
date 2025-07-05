// ======================================================================
// FILE BARU: lib/screens/other/widgets/delivery_log_view.dart
// ======================================================================
// FOKUS: Hanya menampilkan UI untuk tab "Log Pengantaran".

import 'package:damiu/models/delivery_log_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DeliveryLogView extends StatelessWidget {
  final bool isLoading;
  final List<DeliveryLogItem> logs;
  final int totalLogs;
  final int totalGallonsInLogs;
  final Map<String, String> employeeNames;
  final Future<void> Function() onRefresh;
  final Function() onDeleteSummarized;
  final Function() onDeleteAll;
  final Function(int) onDeleteLog;
  final Function(DeliveryLogItem) onEditLog;

  const DeliveryLogView({
    super.key,
    required this.isLoading,
    required this.logs,
    required this.totalLogs,
    required this.totalGallonsInLogs,
    required this.employeeNames,
    required this.onRefresh,
    required this.onDeleteSummarized,
    required this.onDeleteAll,
    required this.onDeleteLog,
    required this.onEditLog,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (isLoading)
                    const LinearProgressIndicator()
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pengantaran: $totalLogs kali'),
                        Text('Total Galon dari Log: $totalGallonsInLogs galon'),
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
                          onPressed: isLoading ? null : onDeleteSummarized,
                        ),
                      ),
                      Tooltip(
                        message: 'Hapus semua log pengantaran',
                        child: TextButton.icon(
                          icon: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                          label: const Text('Hapus Semua', style: TextStyle(color: Colors.red)),
                          onPressed: isLoading ? null : onDeleteAll,
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
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : logs.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            child: const Text('Tidak ada log pengantaran tersimpan.'),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: ListTile(
                              title: Text('Waktu: ${DateFormat('dd MMM kk:mm', 'id_ID').format(log.timestamp)}'),
                              subtitle: Text(
                                'Galon: ${log.gallons} - Karyawan: ${employeeNames[log.employeeUid] ?? "Memuat..."}\nStatus: ${log.isSummarized ? "Sudah Diringkas" : "Belum Diringkas"}'),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: Theme.of(context).primaryColor),
                                    onPressed: log.isSummarized ? null : () => onEditLog(log),
                                    tooltip: log.isSummarized ? "Tidak bisa edit log yang sudah diringkas" : "Edit Log",
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red[700]),
                                    onPressed: () => onDeleteLog(log.id!),
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
}