import 'package:flutter/material.dart';

class SetStockDialog extends StatefulWidget {
  const SetStockDialog({super.key});
  @override
  State<SetStockDialog> createState() => _SetStockDialogState();
}

class _SetStockDialogState extends State<SetStockDialog> {
  final _stockController = TextEditingController();
  @override
  void dispose() {
    _stockController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Persediaan Galon'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _stockController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Galon Tersedia'),
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
            Navigator.pop(context, {
              'stock': int.tryParse(_stockController.text) ?? 0,
            });
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
