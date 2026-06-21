import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../models/order_model.dart';
import '../../models/vehicle_model.dart';
import '../../providers/order_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/connectivity_banner.dart';

import 'map_screen.dart';
import 'order_detail_screen.dart';

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
      _loadCurrentUser();
    });
  }

  Future<void> _loadCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists && mounted) {
      final data = doc.data()!;
      setState(() {
        _currentUserName = data['fullName'] as String?;
        _currentUserRut = data['rut'] as String?;
        _currentUserEmail = data['correo'] as String?;
      });
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    await launchUrl(launchUri);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface == Colors.white
          ? const Color(0xFFF2F2F2)
          : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Icon(
            Icons.local_shipping,
            color: colorScheme.secondary,
            size: 28,
          ),
        ),
        title: Text(
          'Qúbico Conductor',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: colorScheme.onPrimary,
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
          _buildConductorHeader(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildRutaTab(context),
                _buildCargasTab(context),
                _buildPerfilTab(context),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: colorScheme.secondary,
        unselectedItemColor: colorScheme.surface == Colors.white
            ? Colors.black54
            : Colors.grey,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on, size: 26),
            label: 'Ruta',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2, size: 26),
            label: 'Cargas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person, size: 26),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  Widget _buildConductorHeader() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        String fullName = 'Usuario sin nombre registrado';
        String role = 'Conductor';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data();

          if (data != null) {
            fullName = (data['fullName']?.toString().trim().isNotEmpty ?? false)
                ? data['fullName']
                : 'Usuario sin nombre registrado';

            role = data['rol'] ?? 'Conductor';
          }
        }

        final initials = fullName
            .split(' ')
            .where((name) => name.isNotEmpty)
            .take(2)
            .map((name) => name[0].toUpperCase())
            .join();

        final firstName = fullName.split(' ').first;

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
                    '¡Buen viaje, $firstName!',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role == 'conductor' ? 'Conductor de Ruta' : role,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRutaTab(BuildContext context) {
    return Column(
      children: [
        _buildHeader(
          context,
          title: 'Hoja de Ruta',
          subtitleBuilder: (orders) => '${orders.length} paradas programadas',
        ),
        Expanded(child: _buildRouteTimeline(context)),
      ],
    );
  }

  Widget _buildCargasTab(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    final today = DateTime.now();
    final todaysOrders = provider.orders
        .where(
          (o) =>
              o.scheduledDate.year == today.year &&
              o.scheduledDate.month == today.month &&
              o.scheduledDate.day == today.day,
        )
        .toList();

    final vehicleProvider = context.watch<VehicleProvider>();
    Vehicle assignedVehicle;
    try {
      assignedVehicle = vehicleProvider.vehicles.firstWhere(
        (v) => v.driverName == _currentUserName,
      );
    } catch (_) {
      assignedVehicle = Vehicle(
        name: 'Sin vehículo asignado',
        patente: '---',
        maxWeight: 0.0,
        driverName: _currentUserName ?? '',
      );
    }

    final activeOrders = todaysOrders
        .where((o) => o.status != 'Entregado')
        .toList();
    final totalWeight = activeOrders.fold<double>(
      0.0,
      (sum, order) => sum + order.weight,
    );
    final capacityPercentage = (totalWeight / assignedVehicle.maxWeight).clamp(
      0.0,
      1.0,
    );

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        _buildHeader(
          context,
          title: 'Mis Cargas',
          subtitleBuilder: (orders) =>
              'Carga actual: ${totalWeight.toStringAsFixed(1)} / ${assignedVehicle.maxWeight.toStringAsFixed(1)} kg',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.surface == Colors.white
                        ? Colors.black38
                        : Colors.grey[200]!,
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                assignedVehicle.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  assignedVehicle.patente,
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            Icons.local_shipping_outlined,
                            color: colorScheme.primary,
                            size: 36,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Capacidad Utilizada',
                            style: TextStyle(
                              color: colorScheme.surface == Colors.white
                                  ? Colors.black87
                                  : Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${(capacityPercentage * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: capacityPercentage > 0.9
                                  ? colorScheme.error
                                  : colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: capacityPercentage,
                          minHeight: 14,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            capacityPercentage > 0.9
                                ? colorScheme.error
                                : capacityPercentage > 0.7
                                ? colorScheme.secondary
                                : Colors.green[700]!,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Carga total actual: ${totalWeight.toStringAsFixed(1)} kg. Límite máximo: ${assignedVehicle.maxWeight.toStringAsFixed(1)} kg.',
                        style: TextStyle(
                          color: colorScheme.surface == Colors.white
                              ? Colors.black87
                              : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  'DETALLE DE CARGAS DEL DÍA',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.2,
                    color: colorScheme.surface == Colors.white
                        ? Colors.black
                        : Colors.grey,
                  ),
                ),
              ),
              if (todaysOrders.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No hay cargas registradas para hoy.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ...todaysOrders.map(
                  (order) => _buildCargoItemCard(context, order),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPerfilTab(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    final today = DateTime.now();
    final todaysOrders = provider.orders
        .where(
          (o) =>
              o.scheduledDate.year == today.year &&
              o.scheduledDate.month == today.month &&
              o.scheduledDate.day == today.day,
        )
        .toList();

    final deliveredCount = todaysOrders
        .where((o) => o.status == 'Entregado')
        .length;
    final inRouteCount = todaysOrders
        .where((o) => o.status == 'En camino')
        .length;
    final incidentsCount = todaysOrders
        .where((o) => o.status == 'Incidencia')
        .length;

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        _buildHeader(
          context,
          title: 'Mi Perfil',
          subtitleBuilder: (_) => 'Conductor de Ruta',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.surface == Colors.white
                        ? Colors.black38
                        : Colors.grey[200]!,
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: colorScheme.primary.withOpacity(0.12),
                        child: Text(
                          _currentUserName != null &&
                                  _currentUserName!.isNotEmpty
                              ? _currentUserName!
                                    .split(' ')
                                    .where((w) => w.isNotEmpty)
                                    .take(2)
                                    .map((w) => w[0].toUpperCase())
                                    .join()
                              : '?',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentUserName ?? 'Cargando...',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'RUT: ${_currentUserRut ?? '-'}',
                              style: TextStyle(
                                color: colorScheme.surface == Colors.white
                                    ? Colors.black87
                                    : Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currentUserEmail ?? '-',
                              style: TextStyle(
                                color: colorScheme.surface == Colors.white
                                    ? Colors.black87
                                    : Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  'RESUMEN OPERATIVO DE HOY',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.2,
                    color: colorScheme.surface == Colors.white
                        ? Colors.black
                        : Colors.grey,
                  ),
                ),
              ),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildStatItem(
                    context,
                    'Asignadas',
                    '${todaysOrders.length}',
                    Icons.assignment_outlined,
                    Colors.blue[800]!,
                  ),
                  _buildStatItem(
                    context,
                    'Entregadas',
                    '$deliveredCount',
                    Icons.check_circle_outline,
                    Colors.green[700]!,
                  ),
                  _buildStatItem(
                    context,
                    'En Tránsito',
                    '$inRouteCount',
                    Icons.local_shipping_outlined,
                    colorScheme.secondary,
                  ),
                  _buildStatItem(
                    context,
                    'Incidencias',
                    '$incidentsCount',
                    Icons.warning_amber_rounded,
                    colorScheme.error,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    'Cerrar Sesión',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required String title,
    required String Function(List<Order>) subtitleBuilder,
  }) {
    final provider = context.watch<OrderProvider>();
    final today = DateTime.now();
    final todaysOrders = provider.orders
        .where(
          (o) =>
              o.scheduledDate.year == today.year &&
              o.scheduledDate.month == today.month &&
              o.scheduledDate.day == today.day,
        )
        .toList();

    final List<String> months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    final dateStr = '${today.day} ${months[today.month - 1]}';
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 24),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 4.0,
                  ),
                  child: Text(
                    'Cerrar App',
                    style: TextStyle(
                      color: colorScheme.onPrimary.withOpacity(0.85),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.onPrimary.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Hoy, $dateStr',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitleBuilder(todaysOrders),
            style: TextStyle(
              color: colorScheme.onPrimary.withOpacity(0.85),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteTimeline(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    final today = DateTime.now();
    final todaysOrders = provider.orders
        .where(
          (o) =>
              o.scheduledDate.year == today.year &&
              o.scheduledDate.month == today.month &&
              o.scheduledDate.day == today.day,
        )
        .toList();

    if (provider.isLoading)
      return const Center(child: CircularProgressIndicator());
    if (todaysOrders.isEmpty) {
      return const Center(
        child: Text(
          'No hay paradas hoy.',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    int nextOrderIndex = todaysOrders.indexWhere(
      (o) => o.status == 'Pendiente' || o.status == 'En camino',
    );
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 24),
      itemCount: todaysOrders.length,
      itemBuilder: (context, index) {
        final order = todaysOrders[index];
        final isNext = index == nextOrderIndex;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.only(top: 16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isNext
                            ? colorScheme.secondary
                            : Colors.grey[400]!,
                        width: 4,
                      ),
                      color: Colors.white,
                    ),
                  ),
                  if (index < todaysOrders.length - 1)
                    Expanded(
                      child: Container(width: 2.5, color: Colors.grey[400]),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _buildOrderCard(context, order, isNext),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(BuildContext context, Order order, bool isNext) {
    final colorScheme = Theme.of(context).colorScheme;
    final isHighContrast = colorScheme.surface == Colors.white;

    return Card(
      margin: EdgeInsets.zero,
      elevation: isNext ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isNext
            ? BorderSide(color: colorScheme.secondary, width: 2.5)
            : BorderSide(
                color: isHighContrast ? Colors.black26 : Colors.transparent,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isNext)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: colorScheme.secondary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PRÓXIMO DESPACHO',
                    style: TextStyle(
                      color: colorScheme.secondary == Colors.black
                          ? Colors.white
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  const Icon(Icons.navigation, color: Colors.white, size: 16),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        order.clientName.isNotEmpty
                            ? order.clientName
                            : order.clientId,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    _buildStatusBadge(context, order.status),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        order.address,
                        style: TextStyle(
                          color: isHighContrast
                              ? Colors.black
                              : Colors.grey[800],
                          fontSize: 14,
                          fontWeight: isHighContrast
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isHighContrast
                        ? const Color(0xFFEAA100).withOpacity(0.15)
                        : Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: isHighContrast
                        ? Border.all(color: Colors.black45)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: isHighContrast
                            ? Colors.black
                            : colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        order.timeWindow,
                        style: TextStyle(
                          color: isHighContrast
                              ? Colors.black
                              : colorScheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _makePhoneCall(order.clientPhone),
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('Llamar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.onSurface,
                          side: BorderSide(
                            color: colorScheme.onSurface,
                            width: 2,
                          ),
                          backgroundColor: isHighContrast
                              ? Colors.white
                              : Colors.blue[50],
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (order.status == 'Entregado' ||
                              order.status == 'Incidencia') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderDetailScreen(order: order),
                              ),
                            );
                          } else if (order.status == 'Pendiente') {
                            context.read<OrderProvider>().updateOrderStatus(
                              order.id!,
                              'En camino',
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MapScreen(selectedOrder: order),
                              ),
                            );
                          } else if (order.status == 'En camino') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderDetailScreen(order: order),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isNext
                              ? colorScheme.secondary
                              : colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          minimumSize: const Size(0, 48),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          (order.status == 'Entregado' ||
                                  order.status == 'Incidencia')
                              ? 'Ver Resumen'
                              : (order.status == 'Pendiente')
                              ? 'Iniciar Entrega'
                              : 'Terminar Entrega',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCargoItemCard(BuildContext context, Order order) {
    final colorScheme = Theme.of(context).colorScheme;
    final isHighContrast = colorScheme.surface == Colors.white;

    Color badgeColor = colorScheme.primary;
    if (order.loadType == 'Construcción')
      badgeColor = isHighContrast ? Colors.black : AppTheme.accentOrange;
    if (order.loadType == 'Eventos')
      badgeColor = isHighContrast ? Colors.black : Colors.purple;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isHighContrast ? Colors.black45 : Colors.grey[200]!,
          width: isHighContrast ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Carga #${order.id}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: isHighContrast
                        ? Border.all(color: Colors.black)
                        : null,
                  ),
                  child: Text(
                    order.loadType,
                    style: TextStyle(
                      color: isHighContrast ? Colors.black : badgeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.fitness_center_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Peso: ',
                  style: TextStyle(
                    color: isHighContrast ? Colors.black87 : Colors.grey,
                  ),
                ),
                Text(
                  '${order.weight} kg',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.straighten_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Dim: ',
                  style: TextStyle(
                    color: isHighContrast ? Colors.black87 : Colors.grey,
                  ),
                ),
                Text(
                  '${order.length} x ${order.width} x ${order.height} m',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.address,
                    style: TextStyle(
                      color: isHighContrast ? Colors.black : Colors.grey[700],
                      fontSize: 13,
                      fontWeight: isHighContrast
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    final isHighContrast =
        Theme.of(context).colorScheme.surface == Colors.white;
    Color badgeColor;
    switch (status) {
      case 'Entregado':
        badgeColor = Colors.green[800]!;
        break;
      case 'Incidencia':
        badgeColor = const Color(0xFFB00020);
        break;
      case 'En camino':
        badgeColor = isHighContrast ? Colors.black : AppTheme.accentOrange;
        break;
      default:
        badgeColor = Colors.grey[800]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: badgeColor,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isHighContrast = colorScheme.surface == Colors.white;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isHighContrast ? Colors.black45 : Colors.grey[200]!,
          width: isHighContrast ? 1.5 : 1,
        ),
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isHighContrast ? Colors.black87 : Colors.grey[700],
                fontSize: 12,
                fontWeight: isHighContrast
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
