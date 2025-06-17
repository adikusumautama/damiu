// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:damiu/models/user_model.dart'; // Sesuaikan path jika berbeda

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream untuk status autentikasi pengguna
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Mendapatkan UserModel dari Firestore
  Future<UserModel?> getUserModel(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting user model: $e');
      return null;
    }
  }

  // Registrasi dengan Email & Password
  Future<String?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    // required String role, // Dihapus, akan di-set default
    String? phoneNumber,
    String? address,
  }) async {
    const String defaultRole = "pelanggan"; // Peran default untuk pengguna baru
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      User? user = userCredential.user;

      if (user != null) {
        // Simpan informasi tambahan ke Firestore
        UserModel newUser = UserModel(
          uid: user.uid,
          email: email,
          name: name,
          role: defaultRole, // Menggunakan peran default
          phoneNumber: phoneNumber,
          address: address,
        );
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(newUser.toMap());
        return null; // Sukses, tidak ada pesan error
      }
      return "Gagal membuat pengguna."; // Seharusnya tidak terjadi jika userCredential berhasil
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        return 'Password yang diberikan terlalu lemah.';
      } else if (e.code == 'email-already-in-use') {
        return 'Akun sudah ada untuk email tersebut.';
      } else if (e.code == 'invalid-email') {
        return 'Format email tidak valid.';
      }
      print('FirebaseAuthException on register: ${e.toString()}');
      return 'Terjadi kesalahan saat registrasi: ${e.message}';
    } catch (e) {
      print('Error on register: ${e.toString()}');
      return 'Terjadi kesalahan yang tidak diketahui.';
    }
  }

  // Login dengan Email & Password
  Future<String?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // Sukses
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'Email atau password salah.';
      } else if (e.code == 'invalid-email') {
        return 'Format email tidak valid.';
      }
      print('FirebaseAuthException on login: ${e.toString()}');
      return 'Terjadi kesalahan saat login: ${e.message}';
    } catch (e) {
      print('Error on login: ${e.toString()}');
      return 'Terjadi kesalahan yang tidak diketahui.';
    }
  }

  // Logout
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Mendapatkan pengguna saat ini
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
