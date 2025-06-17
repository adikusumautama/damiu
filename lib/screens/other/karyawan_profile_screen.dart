// d:\Skripsi\Studi Kasus AYLAQUA\Project\damiuapp\damiu\lib\screens\karyawan\karyawan_profile_screen.dart
import 'package:damiu/models/user_model.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:flutter/material.dart';

class KaryawanProfileScreen extends StatefulWidget {
  const KaryawanProfileScreen({super.key});

  @override
  State<KaryawanProfileScreen> createState() => _KaryawanProfileScreenState();
}

class _KaryawanProfileScreenState extends State<KaryawanProfileScreen> {
  final AuthService _authService = AuthService();
  UserModel? _currentUserModel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    setState(() {
      _isLoading = true;
    });
    final currentUser = _authService.getCurrentUser();
    if (currentUser != null) {
      final userModel = await _authService.getUserModel(currentUser.uid);
      if (mounted) {
        setState(() {
          _currentUserModel = userModel;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentUserModel == null) {
      return const Center(
          child: Text('Tidak dapat memuat data pengguna. Silakan coba lagi.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Icon(
                Icons.person,
                size: 50,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildProfileInfoRow(
              context, Icons.person_outline, 'Nama', _currentUserModel!.name ?? '-'),
          _buildProfileInfoRow(
              context, Icons.email_outlined, 'Email', _currentUserModel!.email),
          _buildProfileInfoRow(context, Icons.phone_outlined, 'Nomor Telepon',
              _currentUserModel!.phoneNumber ?? '-'),
          _buildProfileInfoRow(context, Icons.location_on_outlined, 'Alamat',
              _currentUserModel!.address ?? '-'),
          const SizedBox(height: 32),
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              onPressed: () async {
                await _authService.signOut();
                // AuthWrapper akan menangani navigasi
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoRow(
      BuildContext context, IconData icon, String label, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(label,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(value, style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}
