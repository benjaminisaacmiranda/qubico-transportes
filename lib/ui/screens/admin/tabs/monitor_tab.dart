import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';

import 'package:qubico/providers/order_provider.dart';
import 'package:qubico/providers/vehicle_provider.dart';
import 'package:qubico/ui/theme/app_theme.dart';
import 'package:qubico/ui/screens/home_screen.dart';

class MonitorTab extends StatelessWidget {
  const MonitorTab({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      final orderProvider = context.watch<OrderProvider>();
      final vehicleProvider = context.watch<VehicleProvider>();

      final today = DateTime.now();
      final todayOrders = orderProvider.orders.where((o) {
        final localDate = o.scheduledDate.toLocal();
        return localDate.year == today.year &&
            localDate.month == today.month &&
            localDate.day == today.day;
      }).toList();

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
                    options: const MapOptions(
                      initialCenter: ll.LatLng(-33.4489, -70.6693),
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
                              (o) => const Marker(
                                point: ll.LatLng(-33.4489, -70.6693),
                                child: Icon(
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
            'Estado de la Flota',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          
          if (vehicleProvider.vehicles.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('No hay vehículos registrados para monitorear.'),
              ),
            )
          else
            ...vehicleProvider.vehicles.map((vehicle) {
              final driverOrders = todayOrders
                  .where((o) => o.driverName == vehicle.driverName)
                  .toList();

              final hasActiveOrders = driverOrders.any((o) => 
                o.status != 'Entregado' && o.status != 'Anulado'
              );
              final statusText = hasActiveOrders ? 'En ruta' : 'En reposo';
              final statusColor = hasActiveOrders ? Colors.green[600] : Colors.grey[500];
              final statusBgColor = hasActiveOrders ? Colors.green[50] : Colors.grey[100];

              String lastOrderText = 'Ninguno';
              if (driverOrders.isNotEmpty) {
                final enCamino = driverOrders.where((o) => o.status == 'En camino').toList();
                if (enCamino.isNotEmpty) {
                  lastOrderText = 'Pedido #${enCamino.first.id} (En curso)';
                } else {
                  final entregados = driverOrders.where((o) => o.status == 'Entregado').toList();
                  if (entregados.isNotEmpty) {
                    entregados.sort((a, b) => (b.id ?? '').compareTo(a.id ?? ''));
                    lastOrderText = 'Pedido #${entregados.first.id} (Entregado)';
                  } else {
                    lastOrderText = 'Pedido #${driverOrders.first.id} (Próximo)';
                  }
                }
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.local_shipping,
                          color: statusColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${vehicle.name} · ${vehicle.patente}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Conductor: ${vehicle.driverName.isEmpty ? "Sin asignar" : vehicle.driverName}',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusBgColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Último: $lastOrderText',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      );
    } catch (e, stack) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text('Error: $e\n$stack'),
        ),
      );
    }
  }
}