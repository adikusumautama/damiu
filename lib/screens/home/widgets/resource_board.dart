import 'package:flutter/material.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:damiu/services/database_helper.dart';
import 'package:damiu/models/daily_stock_model.dart';

class ResourceBoard extends StatefulWidget {
  final bool isOnline;
  final String? employeeUid;
  final VoidCallback? onSetStock;
  const ResourceBoard({super.key, required this.isOnline, required this.employeeUid, this.onSetStock});

  @override
  State<ResourceBoard> createState() => _ResourceBoardState();
}

class _ResourceBoardState extends State<ResourceBoard> {
  int? _stock;
  int? _emptyStock;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStock();
  }

  Future<void> _loadStock() async {
    setState(() => _loading = true);
    if (widget.isOnline) {
      final stream = FirestoreService().getDailyStockStream(DateTime.now());
      stream.listen((stock) {
        setState(() {
          _stock = stock?.currentStock;
          _emptyStock = stock?.initialEmptyStock;
          _loading = false;
        });
      });
    } else {
      final db = DatabaseHelper();
      final stock = await db.getDailyStock(DateTime.now());
      setState(() {
        _stock = stock?.currentStock;
        _emptyStock = stock?.initialEmptyStock;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildResource('Galon Tersedia', _stock),
                  _buildResource('Galon Kosong', _emptyStock),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    tooltip: 'Set Persediaan',
                    onPressed: widget.onSetStock ?? () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.replay, size: 20),
                    tooltip: 'Set Galon Kosong Kembali',
                    onPressed: () async {
                      final result = await showDialog<int>(
                        context: context,
                        builder: (ctx) => _SetEmptyStockDialog(),
                      );
                      if (result != null) {
                        if (widget.isOnline) {
                          await FirestoreService().setInitialEmptyStock(
                            date: DateTime.now(),
                            emptyStock: result,
                            updatedByUid: widget.employeeUid ?? '-',
                          );
                          // Tambah stok isi juga
                          final stock = await FirestoreService().getDailyStockStream(DateTime.now()).first;
                          final newFilled = (stock?.currentStock ?? 0) + result;
                          await FirestoreService().setInitialStock(
                            date: DateTime.now(),
                            filledStock: newFilled,
                            updatedByUid: widget.employeeUid ?? '-',
                          );
                        } else {
                          await DatabaseHelper().setInitialEmptyStock(
                            date: DateTime.now(),
                            emptyStock: result,
                            updatedByUid: widget.employeeUid ?? '-',
                          );
                          // Tambah stok isi juga
                          final stock = await DatabaseHelper().getDailyStock(DateTime.now());
                          final newFilled = (stock?.initialStock ?? 0) + result;
                          await DatabaseHelper().setInitialStock(
                            date: DateTime.now(),
                            filledStock: newFilled,
                            updatedByUid: widget.employeeUid ?? '-',
                          );
                        }
                        if (mounted) setState(() {});
                      }
                    },
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildResource(String label, int? value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _SetEmptyStockDialog extends StatefulWidget {
  const _SetEmptyStockDialog({Key? key}) : super(key: key);

  @override
  State<_SetEmptyStockDialog> createState() => _SetEmptyStockDialogState();
}

class _SetEmptyStockDialogState extends State<_SetEmptyStockDialog> {
  final _emptyStockController = TextEditingController();
  @override
  void dispose() {
    _emptyStockController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Galon Kosong Kembali'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emptyStockController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Jumlah Galon Kosong'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, int.tryParse(_emptyStockController.text) ?? 0);
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
