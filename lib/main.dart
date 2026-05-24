import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/client_provider.dart';
import 'providers/order_provider.dart';
import 'providers/user_provider.dart';
import 'providers/vehicle_provider.dart';
import 'routes/app_router.dart'; //
import 'ui/theme/app_theme.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
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
    // AQUÍ ESTÁ LA MAGIA: Usamos .router y le pasamos la configuración
    return MaterialApp.router(
      title: 'Qúbico',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: AppTheme.backgroundColor),
      routerConfig: AppRouter.router, // <-- CONECTAMOS EL GOROUTER
    );
  }
}
