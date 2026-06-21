import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/order_model.dart';
import '../../providers/order_provider.dart';
import '../theme/app_theme.dart';

class MapScreen extends StatefulWidget {
  final Order? selectedOrder;

  const MapScreen({super.key, this.selectedOrder});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final ll.LatLng _santiago = const ll.LatLng(-33.4489, -70.6693);

  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRealRoute();
    });
  }

  Future<void> _loadRealRoute() async {
    setState(() => _isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Los servicios de ubicación están desactivados.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Los permisos de ubicación fueron denegados.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Los permisos de ubicación están denegados permanentemente.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final currentLatLng = ll.LatLng(position.latitude, position.longitude);

      final today = DateTime.now();
      var orders = Provider.of<OrderProvider>(context, listen: false).orders
          .where(
            (o) =>
                o.scheduledDate.year == today.year &&
                o.scheduledDate.month == today.month &&
                o.scheduledDate.day == today.day,
          )
          .toList();

      if (widget.selectedOrder != null) {
        orders = [widget.selectedOrder!];
      }

      final List<Marker> markersList = [];
      final List<ll.LatLng> waypoints = [currentLatLng];

      markersList.add(
        Marker(
          point: currentLatLng,
          width: 80.0,
          height: 80.0,
          child: const Icon(
            Icons.local_shipping,
            color: AppTheme.primaryBlue,
            size: 45.0,
          ),
        ),
      );

      for (int i = 0; i < orders.length; i++) {
        final order = orders[i];
        try {
          final locations = await locationFromAddress(
            '${order.address}, Santiago, Chile',
          );
          if (locations.isNotEmpty) {
            final loc = locations.first;
            final coord = ll.LatLng(loc.latitude, loc.longitude);
            waypoints.add(coord);

            markersList.add(
              Marker(
                point: coord,
                width: 80.0,
                height: 80.0,
                child: GestureDetector(
                  onTap: () => _showStopInfo(order, i + 1),
                  child: Icon(
                    Icons.location_on,
                    color: order.status == 'Entregado'
                        ? Colors.green
                        : AppTheme.accentOrange,
                    size: 40.0,
                  ),
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint('No se pudo geocodificar: ${order.address}');
        }
      }

      List<ll.LatLng> polylinePoints = [];
      if (waypoints.length > 1) {
        final coordsString = waypoints
            .map((p) => '${p.longitude},${p.latitude}')
            .join(';');
        final url = Uri.parse(
          'http://router.project-osrm.org/route/v1/driving/$coordsString?overview=full&geometries=geojson',
        );

        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['routes'] != null && data['routes'].isNotEmpty) {
            final coords = data['routes'][0]['geometry']['coordinates'] as List;
            polylinePoints = coords.map((c) => ll.LatLng(c[1], c[0])).toList();
          }
        } else {
          polylinePoints = waypoints;
        }
      }

      setState(() {
        _markers = markersList;
        if (polylinePoints.isNotEmpty) {
          _polylines = [
            Polyline(
              points: polylinePoints,
              color: AppTheme.primaryBlue,
              strokeWidth: 5.0,
            ),
          ];
        }
        _isLoading = false;
      });

      _mapController.move(currentLatLng, 13.0);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
        );
      }
    }
  }

  void _showStopInfo(Order order, int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PARADA #$index',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              order.address,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            Text(
              'Ventana: ${order.timeWindow}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Estado: '),
                Text(
                  order.status.toUpperCase(),
                  style: TextStyle(
                    color: order.status == 'Entregado'
                        ? Colors.green
                        : AppTheme.accentOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _currentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      _mapController.move(
        ll.LatLng(position.latitude, position.longitude),
        15.0,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener la ubicación')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruta Qúbico Inteligente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _currentLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _santiago,
              initialZoom: 12.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.qubico',
                maxZoom: 18.0,
              ),
              PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: _markers),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.white.withAlpha(200),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Calculando ruta por las calles...'),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (widget.selectedOrder != null)
            FloatingActionButton.extended(
              heroTag: 'btn_gmaps',
              onPressed: () async {
                final url = Uri.parse(
                  'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent("${widget.selectedOrder!.address}, Santiago, Chile")}',
                );
                await launchUrl(url, mode: LaunchMode.externalApplication);
              },
              label: const Text(
                'Navegar con Google Maps',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              icon: const Icon(Icons.directions, color: Colors.white),
              backgroundColor: Colors.blue,
            ),
          if (widget.selectedOrder != null) const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: 'btn_back',
            onPressed: () => Navigator.pop(context),
            label: const Text(
              'VOLVER A LISTA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            icon: const Icon(Icons.list, color: Colors.white),
            backgroundColor: AppTheme.accentOrange,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
