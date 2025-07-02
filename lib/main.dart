import 'package:damiu/models/user_model.dart';
import 'package:damiu/screens/auth/login_screen.dart';
import 'package:damiu/screens/auth/register_screen.dart';
import 'package:damiu/screens/home/admin_home_screen.dart';
import 'package:damiu/screens/home/karyawan_home_screen.dart';
import 'package:damiu/screens/home/pelanggan_home_screen.dart';
import 'package:damiu/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart'; // Impor untuk initializeDateFormatting
import 'firebase_options.dart'; // Pastikan file ini ada setelah flutterfire configure

// Consider defining roles as constants or an enum
class UserRoles {
  static const String admin = 'admin';
  static const String karyawan = 'karyawan';
  static const String pelanggan = 'pelanggan';
}

// Widget untuk mengelola tampilan Login atau Register
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

// Widget untuk memeriksa status autentikasi dan mengarahkan pengguna
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        // Pengguna sudah login
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user != null) {
            // Ambil data peran dari Firestore
            return FutureBuilder<UserModel?>(
              future: AuthService().getUserModel(user.uid),
              builder: (context, userModelSnapshot) {
                if (userModelSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Scaffold(
                      body: Center(child: CircularProgressIndicator()));
                }
                if (userModelSnapshot.hasError ||
                    !userModelSnapshot.hasData ||
                    userModelSnapshot.data == null) {
                  // Error atau tidak ada data user, mungkin logout atau arahkan ke error page
                  // Jika terjadi error atau data pengguna tidak ditemukan, arahkan kembali ke halaman login/register
                  print("Error fetching user model or no data: ${userModelSnapshot.error}. Redirecting to AuthToggle.");
                  // Sebaiknya logout jika data user tidak ditemukan
                  // Future.microtask(() => AuthService().signOut()); // Hindari setState selama build
                  return const AuthToggle(); // Kembali ke halaman login/register
                }

                final userModel = userModelSnapshot.data!;
                switch (userModel.role) {
                  case UserRoles.admin:
                    return const AdminHomeScreen();
                  case UserRoles.karyawan:
                    return const KaryawanHomeScreen();
                  case UserRoles.pelanggan:
                    return const PelangganHomeScreen();
                  default:
                    print("Unknown role: ${userModel.role}. Redirecting to AuthToggle.");
                    return const AuthToggle(); // Peran tidak diketahui, kembali ke login/register
                }
              },
            );
          } else {
            // Pengguna belum login, tampilkan halaman login/register
            return const AuthToggle();
          }
        }
        // Menunggu koneksi stream
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null); // Tambahkan ini untuk format tanggal Indonesia
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Depot Air Minum',
      home: AuthWrapper(),
      debugShowCheckedModeBanner: false, // Opsional
    );
  }
}
