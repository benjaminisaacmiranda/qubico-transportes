import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Importa tus pantallas (ajusta las rutas según tu proyecto)
import 'login_screen.dart';
import 'admin_dashboard_screen.dart';
import 'home_screen.dart'; // Pantalla del dashboard del conductor

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Escuchamos si hay una sesión guardada en el dispositivo
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Mientras carga, mostramos una pantalla de espera
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Si no hay sesión, mostramos directamente el Login
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        // 2. Si HAY sesión, buscamos el rol en Firestore
        final userId = snapshot.data!.uid;

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Colors.white,
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final userData = userSnapshot.data!.data() as Map<String, dynamic>;
              final String rol = userData['rol'] ?? 'conductor';

              // 3. Devolvemos la pantalla correspondiente según el rol
              if (rol == 'admin') {
                return const AdminDashboardScreen();
              } else {
                return const HomeScreen(); // Pantalla del conductor
              }
            }

            // Si por alguna razón el usuario está autenticado pero no existe en Firestore
            FirebaseAuth.instance.signOut();
            return const LoginScreen();
          },
        );
      },
    );
  }
}