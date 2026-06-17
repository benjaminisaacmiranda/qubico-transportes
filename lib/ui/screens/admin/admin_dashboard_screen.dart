import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:qubico/models/order_model.dart';
import 'package:qubico/providers/order_provider.dart';
import 'package:qubico/ui/theme/app_theme.dart';
import 'package:qubico/ui/widgets/connectivity_banner.dart';

import 'tabs/inicio_tab.dart';
import 'tabs/monitor_tab.dart';
import 'tabs/nuevo_despacho_tab.dart';
import 'tabs/historial_tab.dart';
import 'tabs/ajustes_tab.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;

  final GlobalKey<NuevoDespachoTabState> _nuevoTabKey =
      GlobalKey<NuevoDespachoTabState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().startListening(isAdmin: true);
    });
  }

  void _navigateToInicio() {
    setState(() {
      _currentIndex = 0;
    });
  }

void _editOrder(Order order) {
    // 1. Primero cambiamos a la pestaña para garantizar que esté en el árbol visible y activa
    setState(() {
      _currentIndex = 2; // Navegamos a la pestaña "Nuevo"
    });
    // 2. Esperamos a que Flutter termine de dibujar el frame actual para pasar los datos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nuevoTabKey.currentState?.loadOrderForEdit(order);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.all(12.0),
          child: Icon(
            Icons.local_shipping,
            color: AppTheme.accentOrange,
            size: 28,
          ),
        ),
        title: const Text(
          'Qúbico Admin',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const ConnectivityBanner(),
          _buildAdminHeader(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                const InicioTab(),
                const MonitorTab(),
                NuevoDespachoTab(
                  key: _nuevoTabKey,
                  onOrderSaved: _navigateToInicio,
                ),
                HistorialTab(
                  onEditOrder: _editOrder,
                ),
                const AjustesTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.accentOrange,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Monitor',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Nuevo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }

  Widget _buildAdminHeader() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        String fullName = 'Usuario sin nombre registrado';
        String role = 'Administrador';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data();

          if (data != null) {
            fullName = (data['fullName']?.toString().trim().isNotEmpty ?? false)
                ? data['fullName']
                : 'Usuario sin nombre registrado';

            role = data['rol'] ?? 'Administrador';
          }
        }

        final initials = fullName
            .split(' ')
            .where((name) => name.isNotEmpty)
            .take(2)
            .map((name) => name[0].toUpperCase())
            .join();

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.accentOrange.withOpacity(0.1),
                child: Text(
                  initials.isNotEmpty ? initials : 'U',
                  style: const TextStyle(
                    color: AppTheme.accentOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      role == 'admin' ? 'Administrador' : role,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
