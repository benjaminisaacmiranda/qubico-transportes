import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/order_provider.dart';
import 'providers/vehicle_provider.dart';
import 'providers/user_provider.dart';
import 'providers/client_provider.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OrderProvider()..fetchOrders()),
        ChangeNotifierProvider(create: (_) => VehicleProvider()..fetchVehicles()),
        ChangeNotifierProvider(create: (_) => UserProvider()..fetchUsers()),
        ChangeNotifierProvider(create: (_) => ClientProvider()..fetchClients()),
      ],
      child: MaterialApp(
        title: 'Qúbico Transportes',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const LoginScreen(),
      ),
    );
  }
}
