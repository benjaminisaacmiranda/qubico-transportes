import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/client_model.dart';
import '../../../../models/order_model.dart';
import '../../../../models/vehicle_model.dart';
import '../../../../providers/client_provider.dart';
import '../../../../providers/order_provider.dart';
import '../../../../providers/user_provider.dart';
import '../../../../providers/vehicle_provider.dart';
import '../../../../utils/validators.dart';
import '../../../theme/app_theme.dart';

class NuevoDespachoTab extends StatefulWidget {
  final VoidCallback onOrderSaved;

  const NuevoDespachoTab({
    super.key,
    required this.onOrderSaved,
  });

  @override
  State<NuevoDespachoTab> createState() => NuevoDespachoTabState();
}

class NuevoDespachoTabState extends State<NuevoDespachoTab> {
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

  // Método público para ser llamado mediante GlobalKey cuando se requiere editar
  void loadOrderForEdit(Order order) {
    setState(() {
      _selectedClientOption = 'manual';
      _isManualClient = true;
      _rutController.text = order.clientId;
      _clientNameController.text = '';

      final parts = order.address.split(',');
      if (parts.length >= 2) {
        final streetNum = parts[0].trim();
        _comunaController.text = parts[1].trim();
        final lastSpaceIdx = streetNum.lastIndexOf(' ');
        if (lastSpaceIdx != -1) {
          _calleController.text = streetNum.substring(0, lastSpaceIdx).trim();
          _numeroController.text = streetNum.substring(lastSpaceIdx).trim();
        } else {
          _calleController.text = streetNum;
          _numeroController.clear();
        }
      } else {
        _calleController.text = order.address;
        _numeroController.clear();
        _comunaController.clear();
      }

      _weightController.text = order.weight.toString();
      _lengthController.text = order.length.toString();
      _widthController.text = order.width.toString();
      _heightController.text = order.height.toString();
      _selectedWindow = order.timeWindow;
      _selectedLoad = order.loadType;
      // Vehiculo y otras validaciones podrian setearse acá
    });
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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido registrado y asignado exitosamente'),
          ),
        );
        _resetForm();
        widget.onOrderSaved(); // Navegamos de vuelta
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  const Row(
                    children: [
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
                  const Row(
                    children: [
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
                  const Row(
                    children: [
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
                  const Row(
                    children: [
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
}