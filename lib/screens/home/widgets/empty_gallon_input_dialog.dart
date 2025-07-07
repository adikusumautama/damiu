// lib/screens/home/widgets/empty_gallon_input_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EmptyGallonInputDialog extends StatefulWidget {
  final Function(int quantity) onSubmit;

  const EmptyGallonInputDialog({
    super.key,
    required this.onSubmit,
  });

  @override
  State<EmptyGallonInputDialog> createState() => _EmptyGallonInputDialogState();
}

class _EmptyGallonInputDialogState extends State<EmptyGallonInputDialog> {
  final _formKey = GlobalKey<FormState>();
  final _gallonQuantityController = TextEditingController();

  @override
  void dispose() {
    _gallonQuantityController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final quantity = int.parse(_gallonQuantityController.text);
      widget.onSubmit(quantity);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Input Galon Kosong Kembali'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _gallonQuantityController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Jumlah Galon',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.hourglass_empty_outlined),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == null || int.parse(v) <= 0)
              ? 'Masukkan jumlah valid'
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _submitForm,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

