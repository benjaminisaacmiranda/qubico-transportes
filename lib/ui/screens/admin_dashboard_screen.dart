import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../providers/order_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../models/order_model.dart';
import '../../models/vehicle_model.dart';
import '../../utils/validators.dart';
import '../../services/pdf_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'fleet_management_screen.dart';
import 'order_detail_screen.dart';
import 'user_management_screen.dart';
import 'reports_screen.dart';
import '../../providers/client_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/client_model.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: AppTheme.primaryBlue),
              accountName: Text('Administrador Central', style: TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text('admin@qubico.com'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.admin_panel_settings, color: AppTheme.primaryBlue, size: 40),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.local_shipping),
              title: const Text('Gestión de Flota'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FleetManagementScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Usuarios'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Reportes'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.errorColor),
              title: const Text('Cerrar Sesión', style: TextStyle(color: AppTheme.errorColor)),
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopResumen(context),
            const SizedBox(height: 16),
            _buildInteractiveMap(context),
            const SizedBox(height: 16),
            _buildCriticalAlerts(context),
            const SizedBox(height: 32),
            const Text(
              'MÓDULO DE GESTIÓN DE PEDIDOS',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 18),
            ),
            const Divider(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddOrderDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('REGISTRAR NUEVO DESPACHO'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: AppTheme.accentOrange,
              ),
            ),
            const SizedBox(height: 16),
            _buildOrderList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopResumen(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    final delivered = provider.orders.where((o) => o.status == 'Entregado').length;
    final delayed = provider.orders.where((o) => provider.getPunctualityStatus(o).contains('Atrasado')).length;
    final totalFinished = provider.orders.where((o) => o.status == 'Entregado' || o.status == 'Incidencia').length;
    
    // KPI Puntualidad
    double kpi = 0;
    if (totalFinished > 0) {
      kpi = ((delivered - delayed) / totalFinished).clamp(0.0, 1.0) * 100;
    }

    final fleet = context.watch<VehicleProvider>().vehicles.length;
    final activeOrders = provider.orders.where((o) => o.status == 'En camino').length;
    
    return Row(
      children: [
        Expanded(
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('KPI Puntualidad Mensual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 60,
                        width: 60,
                        child: CircularProgressIndicator(
                          value: totalFinished == 0 ? 0 : kpi / 100,
                          strokeWidth: 8,
                          backgroundColor: Colors.grey[200],
                          color: kpi > 80 ? Colors.green : (kpi > 50 ? AppTheme.accentOrange : AppTheme.errorColor),
                        ),
                      ),
                      Text('${kpi.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Estado de la Flota', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  Text('$activeOrders / $fleet', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppTheme.primaryBlue)),
                  const Text('Camionetas en ruta', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInteractiveMap(BuildContext context) {
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Mapa Interactivo (Tiempo Real)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
          ),
          Container(
            height: 250,
            width: double.infinity,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: const ll.LatLng(-33.4489, -70.6693), // Santiago central
                initialZoom: 11.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.qubico',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: const ll.LatLng(-33.4489, -70.6693),
                      child: const Icon(Icons.local_shipping, color: AppTheme.accentOrange, size: 30),
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

  Widget _buildCriticalAlerts(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    final criticalOrders = provider.orders.where((o) {
      if (o.status == 'Entregado' || o.status == 'Anulado') return false;
      return provider.getPunctualityStatus(o).contains('Atrasado');
    }).toList();

    if (criticalOrders.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withOpacity(0.1),
        border: Border.all(color: AppTheme.errorColor),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning, color: AppTheme.errorColor),
              SizedBox(width: 8),
              Text('Panel de Alertas Críticas (>15 min atraso)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.errorColor)),
            ],
          ),
          const SizedBox(height: 8),
          ...criticalOrders.map((o) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• Pedido #${o.id} - ${o.address}', style: const TextStyle(color: Colors.red)),
          )).toList(),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, provider, child) {
        if (provider.orders.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('No hay registros disponibles.')),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: provider.orders.length,
          itemBuilder: (context, index) {
            final order = provider.orders[index];
            final status = provider.getPunctualityStatus(order);
            return ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderDetailScreen(order: order, isAdmin: true),
                  ),
                );
              },
              title: Text(order.address),
              subtitle: Text('Estado: ${order.status} | $status'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    size: 12,
                    color: order.status == 'Anulado' ? Colors.black : (status.contains('Atrasado') ? Colors.red : (order.status == 'Entregado' ? Colors.green : Colors.grey)),
                  ),
                  if (order.status == 'Pendiente' || order.status == 'Anulado')
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'Anular') {
                          context.read<OrderProvider>().updateOrderStatus(order.id!, 'Anulado');
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido anulado.')));
                        } else if (value == 'Eliminar') {
                          context.read<OrderProvider>().deleteOrder(order.id!);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido eliminado.')));
                        } else if (value == 'Editar') {
                          _showAddOrderDialog(context, orderToEdit: order);
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        if (order.status == 'Pendiente')
                          const PopupMenuItem<String>(
                            value: 'Editar',
                            child: Text('Editar Pedido'),
                          ),
                        if (order.status == 'Pendiente')
                          const PopupMenuItem<String>(
                            value: 'Anular',
                            child: Text('Anular Pedido'),
                          ),
                        if (order.status == 'Anulado')
                          const PopupMenuItem<String>(
                            value: 'Eliminar',
                            child: Text('Eliminar Pedido', style: TextStyle(color: Colors.red)),
                          ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddOrderDialog(BuildContext context, {Order? orderToEdit}) {
    final formKey = GlobalKey<FormState>();
    final clientNameController = TextEditingController();
    final rutController = TextEditingController(text: orderToEdit?.clientId ?? '');
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController(text: orderToEdit?.address ?? '');
    final weightController = TextEditingController(text: orderToEdit?.weight.toString() ?? '');
    final lengthController = TextEditingController(text: orderToEdit?.length.toString() ?? '');
    final widthController = TextEditingController(text: orderToEdit?.width.toString() ?? '');
    final heightController = TextEditingController(text: orderToEdit?.height.toString() ?? '');
    String selectedWindow = orderToEdit?.timeWindow ?? '08:00 - 10:00';
    String selectedLoad = orderToEdit?.loadType ?? 'Paquetería';

    final clients = context.read<ClientProvider>().clients;
    Client? selectedClient;
    if (orderToEdit != null) {
      try {
        selectedClient = clients.firstWhere((c) => c.rut == orderToEdit.clientId);
      } catch (e) {
        selectedClient = clients.isNotEmpty ? clients.first : null;
      }
    } else {
      selectedClient = clients.isNotEmpty ? clients.first : null;
    }
    rutController.text = selectedClient?.rut ?? '';

    final users = context.read<UserProvider>().users;
    final activeDriverNames = users.where((u) => u.isActive).map((u) => u.fullName).toSet();
    final vehicles = context.read<VehicleProvider>().vehicles.where((v) => activeDriverNames.contains(v.driverName)).toList();
    
    Vehicle? selectedVehicle;
    if (orderToEdit != null && orderToEdit.driverId != null) {
      try {
        selectedVehicle = vehicles.firstWhere((v) => v.driverName == orderToEdit.driverId);
      } catch (e) {
        selectedVehicle = vehicles.isNotEmpty ? vehicles.first : null;
      }
    } else {
      selectedVehicle = vehicles.isNotEmpty ? vehicles.first : null;
    }

    Timer? debounceTimer;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(orderToEdit == null ? 'Registrar Nuevo Despacho' : 'Editar Despacho'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('DATOS DEL CLIENTE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const Divider(),
                  DropdownButtonFormField<Client>(
                    value: selectedClient,
                    items: clients.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                    onChanged: (v) {
                      setDialogState(() {
                        selectedClient = v!;
                        rutController.text = v.rut;
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Cliente *'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: rutController,
                    decoration: const InputDecoration(labelText: 'RUT Cliente'),
                    validator: Validators.validateRut,
                    readOnly: true, // Auto-filled from Client Dropdown
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: phoneController,
                          decoration: const InputDecoration(labelText: 'Teléfono (9 dígitos)', prefixText: '+56 '),
                          keyboardType: TextInputType.phone,
                          validator: Validators.validatePhone,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(labelText: 'Correo'),
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.validateEmail,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('DATOS DEL PEDIDO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const Divider(),
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) async {
                      if (textEditingValue.text.length < 4) {
                        return const Iterable<String>.empty();
                      }
                      
                      final completer = Completer<Iterable<String>>();
                      debounceTimer?.cancel();
                      
                      debounceTimer = Timer(const Duration(milliseconds: 600), () async {
                        try {
                          final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(textEditingValue.text)}&format=json&countrycodes=cl&limit=5');
                          final response = await http.get(url, headers: {'User-Agent': 'QubicoApp/1.0'});
                          if (response.statusCode == 200) {
                            final List data = jsonDecode(response.body);
                            completer.complete(data.map((e) => e['display_name'].toString().split(', Chile')[0]).toList());
                            return;
                          }
                        } catch (e) {
                          // Ignore errors during typing
                        }
                        if (!completer.isCompleted) {
                          completer.complete(const Iterable<String>.empty());
                        }
                      });
                      
                      return completer.future;
                    },
                    onSelected: (String selection) {
                      addressController.text = selection;
                    },
                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                      // Sync controllers
                      controller.addListener(() {
                        addressController.text = controller.text;
                      });
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Dirección de Entrega',
                          hintText: 'Ej: Providencia 123, Santiago',
                          suffixIcon: Icon(Icons.search),
                        ),
                        validator: (v) => Validators.validateRequired(v, 'La dirección'),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: weightController,
                    decoration: const InputDecoration(labelText: 'Peso de la Carga (kg) *'),
                    keyboardType: TextInputType.number,
                    validator: (v) => Validators.validateRequired(v, 'El peso'),
                  ),
                  const SizedBox(height: 8),
                  const Text('Dimensiones (Opcional - cm)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: lengthController, decoration: const InputDecoration(labelText: 'Largo'), keyboardType: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(controller: widthController, decoration: const InputDecoration(labelText: 'Ancho'), keyboardType: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(controller: heightController, decoration: const InputDecoration(labelText: 'Alto'), keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedLoad,
                    items: ['Paquetería', 'Construcción', 'Eventos'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setDialogState(() => selectedLoad = v!),
                    decoration: const InputDecoration(labelText: 'Tipo de Carga *'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedWindow,
                    items: ['08:00 - 10:00', '10:00 - 12:00', '12:00 - 14:00', '14:00 - 16:00'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setDialogState(() => selectedWindow = v!),
                    decoration: const InputDecoration(labelText: 'Ventana Horaria (2 hrs) *'),
                  ),
                  const SizedBox(height: 16),
                  const Text('ASIGNACIÓN DE FLOTA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const Divider(),
                  if (vehicles.isEmpty)
                    const Text('Por favor, registre vehículos en la Gestión de Flota.', style: TextStyle(color: Colors.red))
                  else
                    DropdownButtonFormField<Vehicle>(
                      isExpanded: true,
                      value: selectedVehicle,
                      items: vehicles.map((v) => DropdownMenuItem(value: v, child: Text('${v.name} [${v.patente}] (Max: ${v.maxWeight} kg)', overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setDialogState(() => selectedVehicle = v!),
                      decoration: const InputDecoration(labelText: 'Vehículo Asignado *'),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                if (selectedVehicle == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Debe asignar un vehículo.')),
                  );
                  return;
                }

                final weight = double.tryParse(weightController.text) ?? 0.0;
                final maxWeight = selectedVehicle!.maxWeight;

                if (weight > maxWeight) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: El peso ingresado (${weight}kg) supera la capacidad máxima del vehículo asignado (${maxWeight}kg)'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                  return; // Don't save
                }

                final order = Order(
                  id: orderToEdit?.id,
                  clientId: rutController.text,
                  address: addressController.text,
                  weight: weight,
                  length: double.tryParse(lengthController.text) ?? 0.0,
                  width: double.tryParse(widthController.text) ?? 0.0,
                  height: double.tryParse(heightController.text) ?? 0.0,
                  loadType: selectedLoad,
                  timeWindow: selectedWindow,
                  status: orderToEdit?.status ?? 'Pendiente',
                  scheduledDate: orderToEdit?.scheduledDate ?? DateTime.now(),
                  driverId: selectedVehicle!.driverName,
                );

                if (orderToEdit == null) {
                  context.read<OrderProvider>().addOrder(order);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido registrado y asignado exitosamente')));
                } else {
                  context.read<OrderProvider>().updateOrder(order);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido editado exitosamente')));
                }
                
                Navigator.pop(context);
              }
            },
            child: Text(orderToEdit == null ? 'REGISTRAR Y ASIGNAR' : 'GUARDAR CAMBIOS'),
          ),
        ],
      ),
      ),
    );
  }
}
