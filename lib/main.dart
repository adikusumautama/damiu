// lib/main.dart

import 'dart:async'; // <-- Tambahkan impor ini
import 'package:damiu/firebase_options.dart';
import 'package:damiu/models/user_model.dart';
import 'package:damiu/screens/auth/login_screen.dart';
import 'package:damiu/screens/auth/register_screen.dart';
import 'package:damiu/screens/home/admin_home_screen.dart';
import 'package:damiu/screens/home/karyawan_home_screen.dart';
import 'package:damiu/screens/home/pelanggan_home_screen.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

// ======================================================================
// PERBAIKAN FINAL: Menggunakan runZonedGuarded untuk menangkap silent crash
// ======================================================================
void main() {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Menangkap error spesifik dari framework Flutter
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('--- Flutter Error ---');
      debugPrint(details.exceptionAsString());
      if (details.stack != null) {
        debugPrint(details.stack.toString());
      }
      debugPrint('---------------------');
    };

    runApp(const MainApp());
  }, (error, stack) {
    // Menangkap SEMUA error lain yang tidak tertangani (penyebab silent crash)
    debugPrint('--- Uncaught Zoned Error ---');
    debugPrint(error.toString());
    debugPrint(stack.toString());
    debugPrint('----------------------------');
  });
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aylaqua',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        // Menunggu koneksi stream
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Pengguna sudah login
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<UserModel?>(
            future: AuthService().getUserModel(snapshot.data!.uid),
            builder: (context, userModelSnapshot) {
              if (userModelSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (userModelSnapshot.hasError || !userModelSnapshot.hasData || userModelSnapshot.data == null) {
                // Jika terjadi error atau data pengguna tidak ditemukan, arahkan kembali ke halaman login
                // Ini juga mencegah crash jika dokumen user dihapus dari Firestore
                return const AuthToggle();
              }

              final userModel = userModelSnapshot.data!;
              switch (userModel.role) {
                case 'admin':
                  return const AdminHomeScreen();
                case 'karyawan':
                  return const KaryawanHomeScreen();
                case 'pelanggan':
                  return const PelangganHomeScreen();
                default:
                  return const AuthToggle();
              }
            },
          );
        }

        // Pengguna belum login
        return const AuthToggle();
      },
    );
  }
}

class AuthToggle extends StatefulWidget {
  const AuthToggle({super.key});

  @override
  State<AuthToggle> createState() => _AuthToggleState();
}

class _AuthToggleState extends State<AuthToggle> {
  bool showLoginPage = true;

  void toggleScreens() {
    setState(() {
      showLoginPage = !showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (showLoginPage) {
      return LoginScreen(showRegisterPage: toggleScreens);
    } else {
      return RegisterScreen(showLoginPage: toggleScreens);
    }
  }
}

// Fungsi ini sekarang lebih baik dipanggil dari dalam ViewModel setelah login,
// bukan dari main.dart, agar lebih aman.
// Saya membiarkannya di sini jika Anda membutuhkannya di tempat lain.
Future<void> resetDailyStockIfNeeded({
  required bool isOnline,
  required String? employeeUid,
  required DateTime activeDate,
}) async {
  if (!isOnline || employeeUid == null) {
    return;
  }
  
  final firestoreService = FirestoreService();
  final todayStock = await firestoreService.getDailyStockOnce(activeDate);

  // Hanya reset jika dokumen stok untuk hari ini belum ada
  if (todayStock == null) {
    final yesterday = activeDate.subtract(const Duration(days: 1));
    final yesterdayStock = await firestoreService.getDailyStockOnce(yesterday);
    
    // Stok awal hari ini adalah sisa stok dari hari kemarin
    final initialStockToday = yesterdayStock?.currentStock ?? 0;

    await firestoreService.setInitialStock(
      date: activeDate,
      filledStock: initialStockToday,
      updatedByUid: employeeUid,
    );
    // Set stok galon kosong ke 0
    await firestoreService.setInitialEmptyStock(
      date: activeDate,
      emptyStock: 0,
      updatedByUid: employeeUid,
    );
  }
}