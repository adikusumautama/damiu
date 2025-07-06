// lib/screens/home/admin_home_screen.dart

import 'package:damiu/screens/admin/admin_dashboard_screen.dart';
import 'package:flutter/material.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      // Menampilkan konten dashboard admin secara langsung
      body: AdminDashboardScreen(),
    );
  }
}