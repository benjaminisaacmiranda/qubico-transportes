import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/client_model.dart';
import '../../models/order_model.dart';
import '../../models/vehicle_model.dart';
import '../../providers/client_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../services/pdf_service.dart';
import '../../utils/validators.dart';
import '../theme/app_theme.dart';
import 'admin_order_detail_screen.dart';
import 'fleet_management_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'reports_screen.dart';
import 'user_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;

  // New Order Form state
  final _formKey = GlobalKey<FormState>();
  final _rutController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _calleController = TextEditingController();
  final _numeroController = TextEditingController();
  final _comunaController = TextEditingController();
  final _weightController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();

  String? _selectedClientOption = 'manual';
  bool _isManualClient = true;

  Vehicle? _selectedVehicle;
  String _selectedWindow = '08:00 - 10:00';
  String _selectedLoad = 'Paquetería';
  Timer? _debounceTimer;

  @override
  void dispose() {
    _rutController.dispose();
    _clientNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _calleController.dispose();
    _numeroController.dispose();
    _comunaController.dispose();
    _weightController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      _selectedClientOption = 'manual';
      _isManualClient = true;
      _selectedVehicle = null;
      _rutController.clear();
      _clientNameController.clear();
      _phoneController.clear();
      _emailController.clear();
      _calleController.clear();
      _numeroController.clear();
      _comunaController.clear();
      _weightController.clear();
      _lengthController.clear();
      _widthController.clear();
      _heightController.clear();
      _selectedWindow = '08:00 - 10:00';
      _selectedLoad = 'Paquetería';
    });
  }

  Future<void> _saveOrder() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedVehicle == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debe asignar un vehículo.')),
        );
        return;
      }

      final weight = double.tryParse(_weightController.text) ?? 0.0;
      final maxWeight = _selectedVehicle!.maxWeight;

      if (weight > maxWeight) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: El peso ingresado (${weight}kg) supera la capacidad máxima del vehículo (${maxWeight}kg)',
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      final fullAddress =
          "${_calleController.text.trim()} ${_numeroController.text.trim()}, ${_comunaController.text.trim()}";

      // Guardar como cliente frecuente si es manual y la casilla está marcada
      if (_isManualClient) {
        final clientRut = _rutController.text.trim();
        final clientName = _clientNameController.text.trim();
        final clientPhone = _phoneController.text.trim();
        final clientEmail = _emailController.text.trim();

        if (clientRut.isNotEmpty && clientName.isNotEmpty) {
          final newClient = Client(
            rut: clientRut,
            name: clientName,
            phone: clientPhone,
            email: clientEmail,
            billingAddress: fullAddress,
          );

          try {
            await context.read<ClientProvider>().addClient(newClient);
          } catch (_) {
            // Ignorar si ya existe
          }
        }
      }

      final order = Order(
        clientId: _rutController.text.trim().isNotEmpty
            ? _rutController.text.trim()
            : _clientNameController.text.trim(),
        address: fullAddress,
        weight: weight,
        length: double.tryParse(_lengthController.text) ?? 0.0,
        width: double.tryParse(_widthController.text) ?? 0.0,
        height: double.tryParse(_heightController.text) ?? 0.0,
        loadType: _selectedLoad,
        timeWindow: _selectedWindow,
        status: 'Pendiente',
        scheduledDate: DateTime.now(),
        driverId: _selectedVehicle!.driverName,
      );

      await context.read<OrderProvider>().addOrder(order);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pedido registrado y asignado exitosamente'),
        ),
      );

      _resetForm();
      setState(() {
        _currentIndex = 0; // Volver a la pestaña Inicio
      });
    }
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
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildAdminHeader(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildInicioTab(),
                _buildMonitorTab(),
                _buildNuevoTab(),
                _buildHistorialTab(),
                _buildAjustesTab(),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppTheme.accentOrange.withOpacity(0.1),
                child: Text(
                  initials.isNotEmpty ? initials : 'U',
                  style: const TextStyle(
                    color: AppTheme.accentOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    role == 'admin' ? 'Administrador' : role,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ================= TAB 1: INICIO =================
  Widget _buildInicioTab() {
    final orderProvider = context.watch<OrderProvider>();
    final total = orderProvider.orders.length;
    final enRuta = orderProvider.orders
        .where((o) => o.status == 'En camino')
        .length;
    final entregados = orderProvider.orders
        .where((o) => o.status == 'Entregado')
        .length;
    final incidencias = orderProvider.orders
        .where((o) => o.status == 'Incidencia')
        .length;

    final criticalOrders = orderProvider.orders.where((o) {
      if (o.status == 'Entregado' || o.status == 'Anulado') return false;
      return orderProvider.getPunctualityStatus(o).contains('Atrasado');
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Resumen Hoy',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: [
            _buildResumenCard(
              icon: Icons.inventory_2_outlined,
              label: 'Total',
              value: total.toString(),
              color: const Color(0xFF1967D2),
              bgColor: const Color(0xFFE8F0FE),
            ),
            _buildResumenCard(
              icon: Icons.access_time,
              label: 'En Ruta',
              value: enRuta.toString(),
              color: const Color(0xFFE65100),
              bgColor: const Color(0xFFFFF4E5),
            ),
            _buildResumenCard(
              icon: Icons.check_circle_outline,
              label: 'Entregados',
              value: entregados.toString(),
              color: const Color(0xFF137333),
              bgColor: const Color(0xFFE6F4EA),
            ),
            _buildResumenCard(
              icon: Icons.error_outline,
              label: 'Incidencias',
              value: incidencias.toString(),
              color: const Color(0xFFC5221F),
              bgColor: const Color(0xFFFCE8E6),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Alertas de Operación',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade100),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: criticalOrders.isEmpty
                ? Column(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFE6F4EA),
                        child: Icon(Icons.check, color: Colors.green[700]),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Sin alertas críticas.',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.warning, color: AppTheme.errorColor),
                          SizedBox(width: 8),
                          Text(
                            'Retraso Crítico (>15 min)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.errorColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...criticalOrders.map(
                        (o) => Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.arrow_right,
                                color: AppTheme.errorColor,
                                size: 20,
                              ),
                              Expanded(
                                child: Text(
                                  'Pedido #${o.id} - ${o.address}',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildResumenCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: bgColor,
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ================= TAB 2: MONITOR =================
  Widget _buildMonitorTab() {
    try {
      final orderProvider = context.watch<OrderProvider>();
      final vehicleProvider = context.watch<VehicleProvider>();

      // Filtrar pedidos correspondientes al día de hoy (compatible con husos horarios)
      final today = DateTime.now();
      final todayOrders = orderProvider.orders.where((o) {
        final localDate = o.scheduledDate.toLocal();
        return localDate.year == today.year &&
            localDate.month == today.month &&
            localDate.day == today.day;
      }).toList();

      // Pedidos en ruta para el mapa (Flota en vivo)
      final enRutaOrders = todayOrders
          .where((o) => o.status == 'En camino' || o.status == 'En Ruta')
          .toList();

      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Flota en Vivo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                },
                icon: const Icon(Icons.person_pin_circle_outlined, size: 18),
                label: const Text(
                  'App Conductor',
                  style: TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryBlue,
                  side: const BorderSide(color: AppTheme.primaryBlue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  minimumSize: const Size(120, 36),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Live OSM Map - Muestra exclusivamente camiones en ruta
          Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade100),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: const ll.LatLng(-33.4489, -70.6693),
                      initialZoom: 11.0,
                      maxZoom: 18.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.qubico',
                      ),
                      MarkerLayer(
                        markers: enRutaOrders
                            .map(
                              (o) => Marker(
                                point: const ll.LatLng(
                                  -33.4489,
                                  -70.6693,
                                ), // Ubicación simulada en Santiago
                                child: const Icon(
                                  Icons.local_shipping,
                                  color: AppTheme.accentOrange,
                                  size: 28,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Despachos de Hoy',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          // Agrupar pedidos de hoy por vehículo (Hoja de Ruta del Conductor)
          if (vehicleProvider.vehicles.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('No hay vehículos registrados para monitorear.'),
              ),
            )
          else if (todayOrders.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'No se han generado despachos para el día de hoy.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else
            ...vehicleProvider.vehicles.map((vehicle) {
              final ordersForVehicle = todayOrders
                  .where((o) => o.driverId == vehicle.driverName)
                  .toList();
              if (ordersForVehicle.isEmpty) return const SizedBox.shrink();

              return Card(
                margin: const EdgeInsets.only(bottom: 20),
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    // Cabecera azul de la Ruta del Vehículo
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryBlue,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ruta: R-${vehicle.id} (Centro)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${vehicle.patente} • ${vehicle.driverName}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const CircleAvatar(
                            backgroundColor: Colors.white24,
                            child: Icon(
                              Icons.local_shipping,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Lista de Pedidos
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: ordersForVehicle.map((order) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade100),
                            ),
                            child: ListTile(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AdminOrderDetailScreen(order: order),
                                  ),
                                );
                              },
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              title: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'PEDIDO #${order.id ?? "N/A"}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: order.status == 'Entregado'
                                          ? const Color(0xFFE6F4EA)
                                          : (order.status == 'Incidencia'
                                                ? const Color(0xFFFCE8E6)
                                                : (order.status ==
                                                              'En camino' ||
                                                          order.status ==
                                                              'En Ruta'
                                                      ? const Color(0xFFFFF4E5)
                                                      : Colors.grey.shade100)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      order.status == 'En camino' ||
                                              order.status == 'En Ruta'
                                          ? 'PRÓXIMO'
                                          : order.status.toUpperCase(),
                                      style: TextStyle(
                                        color: order.status == 'Entregado'
                                            ? const Color(0xFF137333)
                                            : (order.status == 'Incidencia'
                                                  ? const Color(0xFFC5221F)
                                                  : (order.status ==
                                                                'En camino' ||
                                                            order.status ==
                                                                'En Ruta'
                                                        ? const Color(
                                                            0xFFE65100,
                                                          )
                                                        : Colors
                                                              .grey
                                                              .shade700)),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Text(
                                    'Cliente: ${order.clientId}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          order.address,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time_outlined,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        order.timeWindow,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      );
    } catch (e, stack) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error al cargar el Monitor: $e',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    stack.toString(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // ================= TAB 3: NUEVO =================
  Widget _buildNuevoTab() {
    final clients = context.watch<ClientProvider>().clients;
    final users = context.watch<UserProvider>().users;
    final activeDriverNames = users
        .where((u) => u.isActive)
        .map((u) => u.fullName)
        .toSet();
    final vehicles = context
        .watch<VehicleProvider>()
        .vehicles
        .where((v) => activeDriverNames.contains(v.driverName))
        .toList();

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Nuevo Despacho',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          // CARD 1: CLIENTE & DIRECCIÓN
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade100),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.person_outline, color: AppTheme.primaryBlue),
                      SizedBox(width: 8),
                      Text(
                        'Cliente y Dirección',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedClientOption,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(
                        value: 'manual',
                        child: Text(
                          'Ingresar nuevo cliente manualmente',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...clients.map(
                        (c) => DropdownMenuItem<String>(
                          value: c.rut,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedClientOption = v;
                        if (v == 'manual' || v == null) {
                          _isManualClient = true;
                          _clientNameController.clear();
                          _rutController.clear();
                          _phoneController.clear();
                          _emailController.clear();
                        } else {
                          _isManualClient = false;
                          final selected = clients.firstWhere(
                            (c) => c.rut == v,
                          );
                          _clientNameController.text = selected.name;
                          _rutController.text = selected.rut;
                          _phoneController.text = selected.phone;
                          _emailController.text = selected.email;
                        }
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Selección de Cliente (Autocompletar)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _clientNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Cliente *',
                    ),
                    readOnly: !_isManualClient,
                    validator: (v) =>
                        Validators.validateRequired(v, 'El nombre del cliente'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _rutController,
                    decoration: const InputDecoration(
                      labelText: 'RUT *',
                      hintText: 'Ej: 12345678-9',
                    ),
                    validator: Validators.validateRut,
                    readOnly: !_isManualClient,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      prefixText: '+56 ',
                    ),
                    keyboardType: TextInputType.phone,
                    readOnly: !_isManualClient,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Correo'),
                    keyboardType: TextInputType.emailAddress,
                    readOnly: !_isManualClient,
                  ),

                  const Divider(height: 24),
                  Row(
                    children: const [
                      Icon(
                        Icons.location_on_outlined,
                        color: AppTheme.primaryBlue,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Dirección de Entrega',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _calleController,
                    decoration: const InputDecoration(
                      labelText: 'Calle *',
                      hintText: 'Ej: Av. Providencia',
                    ),
                    validator: (v) =>
                        Validators.validateRequired(v, 'La calle'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _numeroController,
                    decoration: const InputDecoration(
                      labelText: 'Número *',
                      hintText: 'Ej: 1234 o 56-A',
                    ),
                    validator: (v) =>
                        Validators.validateRequired(v, 'El número'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _comunaController,
                    decoration: const InputDecoration(
                      labelText: 'Comuna *',
                      hintText: 'Ej: Providencia',
                    ),
                    validator: (v) =>
                        Validators.validateRequired(v, 'La comuna'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // CARD 2: CARGA & PROGRAMACION
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade100),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.access_time_outlined,
                        color: AppTheme.primaryBlue,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Programación y Carga',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedWindow,
                    items:
                        [
                              '08:00 - 10:00',
                              '10:00 - 12:00',
                              '12:00 - 14:00',
                              '14:00 - 16:00',
                            ]
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => _selectedWindow = v!),
                    decoration: const InputDecoration(
                      labelText: 'Ventana Horaria *',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLoad,
                    items: ['Paquetería', 'Construcción', 'Eventos']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedLoad = v!),
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Carga *',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _weightController,
                    decoration: const InputDecoration(
                      labelText: 'Peso de la Carga (kg) *',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => Validators.validateRequired(v, 'El peso'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Dimensiones (Opcional - cm)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _lengthController,
                          decoration: const InputDecoration(labelText: 'Largo'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _widthController,
                          decoration: const InputDecoration(labelText: 'Ancho'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _heightController,
                          decoration: const InputDecoration(labelText: 'Alto'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // CARD 3: VEHICULO
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade100),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.local_shipping_outlined,
                        color: AppTheme.primaryBlue,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Asignación de Flota',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (vehicles.isEmpty)
                    const Text(
                      'No hay vehículos activos con conductores activos. Registre uno en Ajustes > Gestión de Flota.',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    )
                  else
                    DropdownButtonFormField<Vehicle>(
                      isExpanded: true,
                      initialValue: _selectedVehicle,
                      items: vehicles
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(
                                '${v.name} [${v.patente}] (Max: ${v.maxWeight} kg)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedVehicle = v!),
                      decoration: const InputDecoration(
                        labelText: 'Vehículo Asignado *',
                      ),
                      validator: (v) => v == null ? 'Requerido' : null,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _saveOrder,
            icon: const Icon(Icons.save_outlined, color: Colors.white),
            label: const Text(
              'GUARDAR DESPACHO',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: AppTheme.accentOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ================= TAB 4: HISTORIAL =================
  Widget _buildHistorialTab() {
    return Consumer<OrderProvider>(
      builder: (context, provider, child) {
        if (provider.orders.isEmpty) {
          return const Center(child: Text('No hay registros de despachos.'));
        }

        // Agrupar pedidos por fecha de programación
        final Map<String, List<Order>> groupedOrders = {};
        for (var order in provider.orders) {
          final dateStr = DateFormat('dd/MM/yyyy').format(order.scheduledDate);
          groupedOrders.putIfAbsent(dateStr, () => []).add(order);
        }

        // Ordenar fechas en orden descendente (más recientes primero)
        final sortedDates = groupedOrders.keys.toList()
          ..sort((a, b) {
            final dateA = DateFormat('dd/MM/yyyy').parse(a);
            final dateB = DateFormat('dd/MM/yyyy').parse(b);
            return dateB.compareTo(dateA);
          });

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: sortedDates.length,
          itemBuilder: (context, dateIndex) {
            final dateStr = sortedDates[dateIndex];
            final ordersForDate = groupedOrders[dateStr]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado de la Fecha con Botones de Exportación
                Card(
                  elevation: 0,
                  color: AppTheme.primaryBlue.withOpacity(0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${ordersForDate.length} pedidos',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Botón Exportar PDF
                        IconButton(
                          icon: const Icon(
                            Icons.picture_as_pdf,
                            color: Colors.red,
                            size: 22,
                          ),
                          onPressed: () async {
                            final path = await PdfService.generateDailyReport(
                              ordersForDate,
                            );
                            provider.addGeneratedReport(dateStr, 'PDF', path);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Reporte PDF generado exitosamente',
                                ),
                              ),
                            );
                          },
                          tooltip: 'Exportar PDF',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                        // Botón Exportar Excel
                        IconButton(
                          icon: const Icon(
                            Icons.table_view,
                            color: Colors.green,
                            size: 22,
                          ),
                          onPressed: () async {
                            final path = await PdfService.generateCSVReport(
                              ordersForDate,
                              dateStr,
                            );
                            provider.addGeneratedReport(dateStr, 'Excel', path);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Reporte Excel (CSV) generado exitosamente',
                                ),
                              ),
                            );
                          },
                          tooltip: 'Exportar Excel (CSV)',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Lista de pedidos para esta fecha
                ...ordersForDate.map((order) {
                  final punctuality = provider.getPunctualityStatus(order);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade100),
                    ),
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AdminOrderDetailScreen(order: order),
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        backgroundColor: order.status == 'Entregado'
                            ? const Color(0xFFE6F4EA)
                            : (order.status == 'Incidencia'
                                  ? const Color(0xFFFCE8E6)
                                  : Colors.grey.shade100),
                        child: Icon(
                          order.status == 'Entregado'
                              ? Icons.check
                              : (order.status == 'Incidencia'
                                    ? Icons.warning
                                    : Icons.local_shipping),
                          color: order.status == 'Entregado'
                              ? Colors.green
                              : (order.status == 'Incidencia'
                                    ? Colors.red
                                    : Colors.blue),
                        ),
                      ),
                      title: Text(
                        'Pedido #${order.id}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${order.address}\nEstado: ${order.status} | $punctuality',
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (order.status == 'Pendiente' ||
                              order.status == 'Anulado')
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'Anular') {
                                  provider.updateOrderStatus(
                                    order.id!,
                                    'Anulado',
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Pedido anulado.'),
                                    ),
                                  );
                                } else if (value == 'Eliminar') {
                                  provider.deleteOrder(order.id!);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Pedido eliminado.'),
                                    ),
                                  );
                                } else if (value == 'Editar') {
                                  // Pre-fill fields and move to form tab
                                  setState(() {
                                    _selectedClientOption = 'manual';
                                    _isManualClient = true;
                                    _rutController.text = order.clientId;
                                    _clientNameController.text =
                                        ''; // Pre-fill name can be manually typed

                                    // Parse street/number/comuna from address if possible
                                    final parts = order.address.split(',');
                                    if (parts.length >= 2) {
                                      final streetNum = parts[0].trim();
                                      _comunaController.text = parts[1].trim();
                                      final lastSpaceIdx = streetNum
                                          .lastIndexOf(' ');
                                      if (lastSpaceIdx != -1) {
                                        _calleController.text = streetNum
                                            .substring(0, lastSpaceIdx)
                                            .trim();
                                        _numeroController.text = streetNum
                                            .substring(lastSpaceIdx)
                                            .trim();
                                      } else {
                                        _calleController.text = streetNum;
                                        _numeroController.clear();
                                      }
                                    } else {
                                      _calleController.text = order.address;
                                      _numeroController.clear();
                                      _comunaController.clear();
                                    }

                                    _weightController.text = order.weight
                                        .toString();
                                    _lengthController.text = order.length
                                        .toString();
                                    _widthController.text = order.width
                                        .toString();
                                    _heightController.text = order.height
                                        .toString();
                                    _selectedWindow = order.timeWindow;
                                    _selectedLoad = order.loadType;
                                    _currentIndex = 2; // Jump to New/Edit tab
                                  });
                                }
                              },
                              itemBuilder: (BuildContext context) =>
                                  <PopupMenuEntry<String>>[
                                    if (order.status == 'Pendiente')
                                      const PopupMenuItem<String>(
                                        value: 'Editar',
                                        child: Text('Editar'),
                                      ),
                                    if (order.status == 'Pendiente')
                                      const PopupMenuItem<String>(
                                        value: 'Anular',
                                        child: Text(
                                          'Anular',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    if (order.status == 'Anulado')
                                      const PopupMenuItem<String>(
                                        value: 'Eliminar',
                                        child: Text(
                                          'Eliminar',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                  ],
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
    );
  }

  // ================= TAB 5: AJUSTES =================
  Widget _buildAjustesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Configuraciones y Módulos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        _buildAjustesTile(
          icon: Icons.local_shipping_outlined,
          title: 'Gestión de Flota',
          subtitle: 'Monitorear, agregar y editar vehículos corporativos',
          onTap: () {
            context
                .read<VehicleProvider>()
                .fetchVehicles(); //Llama a los camiones que estan guardados en Firestore
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FleetManagementScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildAjustesTile(
          icon: Icons.people_outline,
          title: 'Gestión de Usuarios y Seguridad',
          subtitle: 'Controlar accesos, roles y bitácora de auditoría',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserManagementScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildAjustesTile(
          icon: Icons.analytics_outlined,
          title: 'Reportes y Exportaciones',
          subtitle: 'Exportación de datos de despachos en PDF y Excel',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAjustesTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: AppTheme.primaryBlue.withOpacity(0.08),
          child: Icon(icon, color: AppTheme.primaryBlue),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}
