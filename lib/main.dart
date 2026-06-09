import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart'; // Importante importar tu AuthProvider
import 'providers/client_provider.dart';
import 'providers/order_provider.dart';
import 'providers/user_provider.dart';
import 'providers/vehicle_provider.dart';
import 'routes/app_router.dart';
import 'ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        // Se añade AuthProvider para controlar la sesión y el rol de forma global
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => VehicleProvider()),
        ChangeNotifierProvider(create: (_) => ClientProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Usamos context.watch para que la app se redibuje automáticamente cuando cambie el rol
    final authProvider = context.watch<AuthProvider>();

    // Selección de tema dinámico según el rol detectado en la sesión activa
    ThemeData selectedTheme;
    if (authProvider.isLoggedIn) {
      selectedTheme = authProvider.isAdmin ? AppTheme.lightTheme : AppTheme.driverTheme;
    } else {
      selectedTheme = AppTheme.lightTheme; // Tema por defecto para el Login
    }

    return MaterialApp.router(
      title: 'Qúbico',
      debugShowCheckedModeBanner: false,
      theme: selectedTheme, // Aplicando el tema dinámico calculado arriba
      routerConfig: AppRouter.router,
    );
  }
}