// lib/main.dart
import 'dart:async';
import 'package:damiu/firebase_options.dart';
import 'package:damiu/models/user_model.dart';
import 'package:damiu/screens/auth/login_screen.dart';
import 'package:damiu/screens/auth/register_screen.dart';
import 'package:damiu/screens/home/admin_home_screen.dart';
import 'package:damiu/screens/home/karyawan_home_screen.dart';
import 'package:damiu/screens/home/pelanggan_home_screen.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:damiu/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    // Aktifkan Firestore persistence secara eksplisit.
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: true);
    FlutterError.onError = (details) => debugPrint('Flutter Error: ${details.exceptionAsString()}');
    runApp(const MainApp());
  }, (error, stack) => debugPrint('Zoned Error: $error'));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aylaqua',
      theme: ThemeData(primarySwatch: Colors.blue, visualDensity: VisualDensity.adaptivePlatformDensity),
      // --- TAMBAHKAN INI UNTUK MENGATASI ERROR ---
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'), // Mengatur bahasa Indonesia sebagai bahasa yang didukung
      ],
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
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<UserModel?>(
            future: AuthService().getUserModel(snapshot.data!.uid),
            builder: (context, userModelSnapshot) {
              if (userModelSnapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              if (userModelSnapshot.hasError || !userModelSnapshot.hasData || userModelSnapshot.data == null) return const AuthToggle();
              switch (userModelSnapshot.data!.role) {
                case 'admin': return const AdminHomeScreen();
                case 'karyawan': return const KaryawanHomeScreen();
                case 'pelanggan': return const PelangganHomeScreen();
                default: return const AuthToggle();
              }
            },
          );
        }
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
  void toggleScreens() => setState(() => showLoginPage = !showLoginPage);
  @override
  Widget build(BuildContext context) {
    if (showLoginPage) {
      return LoginScreen(showRegisterPage: toggleScreens);
    } else {
      return RegisterScreen(showLoginPage: toggleScreens);
    }
  }
}

Future<void> resetDailyStockIfNeeded({required bool isOnline, required String? employeeUid, required DateTime activeDate}) async {
  if (!isOnline || employeeUid == null) return;
  final firestoreService = FirestoreService();
  final todayStock = await firestoreService.getDailyStockOnce(activeDate);
  if (todayStock == null) {
    final yesterday = activeDate.subtract(const Duration(days: 1));
    final yesterdayStock = await firestoreService.getDailyStockOnce(yesterday);
    
    // Stok awal hari ini adalah sisa stok dari hari sebelumnya.
    // Galon kosong dari hari sebelumnya sudah ditambahkan ke stok tersedia secara real-time.
    final lastDayFilledStock = yesterdayStock?.currentStock ?? 0; 

    await firestoreService.setInitialStock(date: activeDate, filledStock: lastDayFilledStock, updatedByUid: employeeUid);
    await firestoreService.setInitialEmptyStock(date: activeDate, emptyStock: 0, updatedByUid: employeeUid);
  }
}