import 'package:damiu/services/auth_service.dart';
import 'package:flutter/material.dart';

class PelangganHomeScreen extends StatelessWidget {
  const PelangganHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pelanggan Area'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Selamat datang, Pelanggan!'),
      ),
    );
  }
}
