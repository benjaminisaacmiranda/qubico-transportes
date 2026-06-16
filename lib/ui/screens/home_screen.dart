//Hoja de ruta (Pantalla conductor)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:go_router/go_router.dart';

// RUTAS RELATIVAS QUE SÍ RECONOCE TU ENTORNO
import '../../models/order_model.dart';
import '../../models/vehicle_model.dart';
import '../../providers/order_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/connectivity_banner.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  String? _currentUserName;
  String? _currentUserRut;
  String? _currentUserEmail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().startListening(isAdmin: false);
      context.read<VehicleProvider>().fetchVehicles();
      _loadCurrentUser();
    });
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() {
            _currentUserName = doc.data()?['name'] ?? 'Conductor';
            _currentUserRut = doc.data()?['rut'] ?? '';
            _currentUserEmail = doc.data()?['email'] ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('Error al cargar datos de usuario: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final isHighContrast = colorScheme.surface == Colors.white;

    final List<Widget> tabs = [
      _buildHojaRutaTab(context, orderProvider, isHighContrast),
      _buildEstadisticasTab(context, orderProvider),
      _buildPerfilTab(context, isHighContrast),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentIndex == 0 
              ? 'Mi Hoja de Ruta' 
              : _currentIndex == 1 
                  ? 'Estadísticas del Día' 
                  : 'Mi Perfil',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
                if (mounted) context.go('/login');
              } catch (e) {
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const ConnectivityBanner(),
          Expanded(child: tabs[_currentIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: isHighContrast ? Colors.black : AppTheme.primaryBlue,
        unselectedItemColor: Colors.grey,
        backgroundColor: colorScheme.surface,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.route), label: 'Ruta'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reporte'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }

  Widget _buildHojaRutaTab(BuildContext context, OrderProvider orderProvider, bool isHighContrast) {
    if (orderProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orderProvider.orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No tienes despachos asignados para hoy.',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    final sortedOrders = List<Order>.from(orderProvider.orders);
    sortedOrders.sort((a, b) {
      if (a.status == 'Pendiente' && b.status != 'Pendiente') return -1;
      if (a.status != 'Pendiente' && b.status == 'Pendiente') return 1;
      return 0;
    });

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sortedOrders.length,
      itemBuilder: (context, index) {
        final order = sortedOrders[index];
        final statusColor = _getStatusColor(order.status);

        return LayoutBuilder(
          builder: (context, constraints) {
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isHighContrast ? Colors.black : Colors.grey[200]!,
                  width: isHighContrast ? 1.5 : 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  context.push('/order-detail', extra: order);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 14.0), // Reducido un poco horizontalmente para evitar desborde
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 6,
                        height: 85,
                        decoration: BoxDecoration(
                          color: isHighContrast ? Colors.black : statusColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // El Expanded obliga a los textos a ajustarse y no empujar los íconos fuera de la pantalla
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'ID: ${order.id?.substring(0, 8) ?? 'N/A'}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isHighContrast ? Colors.black : statusColor).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    order.status,
                                    style: TextStyle(
                                      color: isHighContrast ? Colors.black : statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Cliente: ${order.clientId}',
                              style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w500, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Dirección: ${order.address}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Ventana: ${order.timeWindow}',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4), // Espacio mínimo seguro antes de los botones

                      // BOTONES REDISEÑADOS CON PADDING INTERNO OPTIMIZADO CONTRA DESBORDES
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.map_outlined, color: Colors.blueAccent),
                            iconSize: 26, // Ajuste milimétrico óptimo
                            constraints: const BoxConstraints(), 
                            padding: const EdgeInsets.all(6), // Padding interno balanceado
                            onPressed: () {
                              context.push('/map', extra: order);
                            },
                          ),
                          const SizedBox(height: 4), // Separación vertical limpia
                          IconButton(
                            icon: const Icon(Icons.chevron_right, color: Colors.grey),
                            iconSize: 28, // Ajuste milimétrico óptimo
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(6), // Padding interno balanceado
                            onPressed: () {
                              context.push('/order-detail', extra: order);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEstadisticasTab(BuildContext context, OrderProvider orderProvider) {
    final entregados = orderProvider.orders.where((o) => o.status == 'Entregado').length;
    final pendientes = orderProvider.orders.where((o) => o.status == 'Pendiente' || o.status == 'En camino').length;
    final incidencias = orderProvider.orders.where((o) => o.status == 'Incidencia').length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen de Entregas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatItem(context, 'Entregados', entregados.toString(), Icons.check_circle, Colors.green)),
              Expanded(child: _buildStatItem(context, 'Pendientes', pendientes.toString(), Icons.schedule, Colors.orange)),
              Expanded(child: _buildStatItem(context, 'Alertas', incidencias.toString(), Icons.warning, Colors.red)),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.analytics_outlined, size: 48, color: Colors.blue),
                    const SizedBox(height: 12),
                    const Text(
                      'Rendimiento Diario',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Los datos de tiempos de entrega e incidencias se actualizarán de forma automática conforme se complete la ruta.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerfilTab(BuildContext context, bool isHighContrast) {
    final vehicleProvider = context.watch<VehicleProvider>();
    
    Vehicle? myVehicle;
    if (_currentUserName != null && vehicleProvider.vehicles.isNotEmpty) {
      final matches = vehicleProvider.vehicles.where(
        (v) => v.driverName.toLowerCase() == _currentUserName!.toLowerCase()
      );
      if (matches.isNotEmpty) {
        myVehicle = matches.first;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isHighContrast ? Colors.black45 : Colors.grey[200]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: (isHighContrast ? Colors.black : AppTheme.primaryBlue).withOpacity(0.1),
                    child: Icon(Icons.person, size: 32, color: isHighContrast ? Colors.black : AppTheme.primaryBlue),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUserName ?? 'Cargando...',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('RUT: ${_currentUserRut ?? 'N/A'}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        Text('Email: ${_currentUserEmail ?? 'N/A'}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isHighContrast ? Colors.black45 : Colors.grey[200]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.local_shipping, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Vehículo Asignado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 24),
                  if (vehicleProvider.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (myVehicle == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          'No tienes un vehículo vinculado para hoy.',
                          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        _buildVehicleRow('Nombre:', myVehicle.name),
                        _buildVehicleRow('Patente:', myVehicle.patente),
                        _buildVehicleRow('Capacidad Máx:', '${myVehicle.maxWeight} kg'),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: valueColor)),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    final isHighContrast = colorScheme.surface == Colors.white;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isHighContrast ? Colors.black45 : Colors.grey[200]!, width: isHighContrast ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isHighContrast ? Colors.black : color, size: 26),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isHighContrast ? Colors.black87 : Colors.grey[700], 
                fontSize: 12,
                fontWeight: isHighContrast ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pendiente': return Colors.orange;
      case 'En camino': return Colors.purple;
      case 'Entregado': return Colors.green;
      case 'Incidencia': return Colors.red;
      default: return Colors.grey;
    }
  }
}