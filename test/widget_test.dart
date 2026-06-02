import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:qubico/main.dart';

import 'package:qubico/providers/client_provider.dart';
import 'package:qubico/providers/order_provider.dart';
import 'package:qubico/providers/user_provider.dart';
import 'package:qubico/providers/vehicle_provider.dart';

void main() {
  testWidgets('MyApp loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
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

    // Espera a que GoRouter termine de construir
    await tester.pumpAndSettle();

    // Verifica que la app cargó
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
