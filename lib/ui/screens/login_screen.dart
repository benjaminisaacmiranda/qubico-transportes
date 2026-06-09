import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _canLogin = false;

  @override
  void initState() {
    super.initState();

    _emailController.addListener(_checkFields);
    _passwordController.addListener(_checkFields);
  }

  void _checkFields() {
    setState(() {
      _canLogin =
          _emailController.text.trim().isNotEmpty &&
          _passwordController.text.trim().isNotEmpty;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      // 🔐 Login con Firebase Auth
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      // 📦 Buscar datos en Firestore por UID
      final uid = cred.user!.uid;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuario no existe en Firestore'),
          ),
        );
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final rol = data['rol'];

      // Redirección por rol
      if (rol == 'admin') {
        context.go('/admin');
      } else {
        context.go('/home');
      }
    } on FirebaseAuthException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuario o contraseña incorrectos'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.local_shipping,
                size: 100,
                color: AppTheme.primaryBlue,
              ),
              const SizedBox(height: 16),
              const Text(
                'QÚBICO',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                  letterSpacing: 4,
                ),
              ),
              const Text(
                'TRANSPORTES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentOrange,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 48),

              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'Correo Institucional',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 32),

              ElevatedButton(
  onPressed: _canLogin ? _login : null,
  style: ElevatedButton.styleFrom(
    minimumSize: const Size(double.infinity, 50),
    backgroundColor: _canLogin
        ? const Color.fromARGB(255, 2, 50, 97)
        : Colors.grey.shade700,
    foregroundColor: Colors.white,
    disabledBackgroundColor: const Color.fromARGB(255, 70, 70, 71),
    disabledForegroundColor: Colors.white70,
    elevation: _canLogin ? 4 : 0,
  ),
  child: Text(
    'INGRESAR',
    style: TextStyle(
      fontWeight: FontWeight.bold,
      color: _canLogin ? Colors.white : Colors.white70,
    ),
  ),
),
            ],
          ),
        ),
      ),
    );
  }
}