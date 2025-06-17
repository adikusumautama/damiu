// lib/screens/auth/login_screen.dart
import 'package:damiu/services/auth_service.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback showRegisterPage;
  const LoginScreen({super.key, required this.showRegisterPage});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      String? result = await AuthService().signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        if (result != null) { // Ada error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result)),
          );
        }
        // Jika sukses (result == null), AuthWrapper akan handle navigasi
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'), // Judul bisa dikosongkan jika tidak ingin ada teks
        elevation: 0, // Menghilangkan bayangan AppBar
        backgroundColor: Colors.transparent, // Membuat AppBar transparan
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Icon(
                    Icons.water_drop_outlined, // Anda bisa mengganti dengan Icons.opacity atau ikon lain
                    size: 100,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'APLIKASI DEPOT AIR MINUM',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor),
                  ),
                  const SizedBox(height: 8),
                  // Text(
                  //   'Silakan login untuk melanjutkan',
                  //   textAlign: TextAlign.center,
                  //   style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  // ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Email tidak boleh kosong';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Masukkan email yang valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Login', style: TextStyle(fontSize: 16)),
                        ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Belum punya akun?"),
                      TextButton(
                        onPressed: widget.showRegisterPage,
                        child: const Text('Daftar di sini'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
