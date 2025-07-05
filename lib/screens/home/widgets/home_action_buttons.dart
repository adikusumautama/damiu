// ======================================================================
// FILE: lib/screens/home/widgets/home_action_buttons.dart
// ======================================================================
// FOKUS: Hanya berisi tombol-tombol aksi utama.

import 'package:damiu/screens/other/empty_gallon_input_screen.dart';
import 'package:damiu/screens/other/order_input_screen.dart';
import 'package:flutter/material.dart';

class HomeActionButtons extends StatelessWidget {
  const HomeActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('Catat Pesanan Masuk'),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const OrderInputScreen()));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Input Galon Kosong Kembali'),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const EmptyGallonInputScreen()));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}
