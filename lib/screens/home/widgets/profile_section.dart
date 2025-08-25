import 'package:flutter/material.dart';
import 'package:damiu/models/user_model.dart';

class ProfileSection extends StatelessWidget {
  final UserModel? user;
  final VoidCallback onLogout;
  const ProfileSection({super.key, required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 40,
              child: Icon(Icons.person, size: 48),
            ),
            const SizedBox(height: 16),
            Text(user?.name ?? '-', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(user?.email ?? '-', style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(user?.address ?? '-', style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(user?.phoneNumber ?? '-', style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text('Logout', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: onLogout,
            ),
          ],
        ),
      ),
    );
  }
}
