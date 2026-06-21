import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // FIX: Usamos el objeto Client directamente en lugar del RUT como key,
  // evitando cualquier re-búsqueda que dependa de rut como identificador.
  // null = modo manual; objeto Client = cliente seleccionado del listado.
  Client? _selectedClient;
  bool _isManualClient = true;
  
  // 🕒 Bandera para controlar la pantalla de carga
  bool _isLoading = true;

  Vehicle? _selectedVehicle;
  String? _selectedWindow;
  String _selectedLoad = 'Paquetería';
  Timer? _debounceTimer;

  Order? _editingOrder;
  bool _isEditing = false;

  String? _selectedDriverId;
  String _selectedDriverName = '';

  @override
  void initState() {
    super.initState();
    // 🛑 HOTFIX: Esperar a que el frame termine de construirse antes de llamar al Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRequiredData();
    });
  }
Future<String?> getDriverIdByName(String driverName) async {
  final snap = await FirebaseFirestore.instance
      .collection('users')
      .where('fullName', isEqualTo: driverName)
      .limit(1)
      .get();

  if (snap.docs.isEmpty) return null;

  return snap.docs.first.id;
}
  // 🚀 Método que dispara todas las consultas a Firebase
  Future<void> _fetchRequiredData() async {
    try {
      // Usamos Future.wait para ejecutar todas las consultas en paralelo y ganar velocidad
      await Future.wait([
        context.read<ClientProvider>().fetchClients(),
        context.read<UserProvider>().fetchUsers(),
        context.read<VehicleProvider>().fetchVehicles(),
      ]);
    } catch (e) {
      // Manejo silencioso de errores o puedes agregar un log aquí
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Apagamos el ícono de carga
        });
      }
    }
  }

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

  void loadOrderForEdit(Order order) {
    setState(() {
      _editingOrder = order;
      _isEditing = true;
      _selectedClient = null;
      _isManualClient = true;
      _selectedDriverId = order.driverId;
      _selectedDriverName = order.driverName;
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
    });
  }

  void _resetForm() {
    setState(() {
      _editingOrder = null;
      _isEditing = false;
      _selectedClient = null;
      _isManualClient = true;
      _selectedVehicle = null;
      _selectedDriverId = null;
      _selectedDriverName = '';
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
      _selectedWindow = null;
      _selectedLoad = 'Paquetería';
    });
  }

  Future<void> _saveOrder() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedWindow == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debe seleccionar una ventana horaria.')),
        );
        return;
      }

      

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
            // FIX: Re-fetch para asegurar que el cliente recién guardado
            // pase por fromMap() (con decrypt) antes de aparecer en el dropdown.
            // Evita mostrar RUT/teléfono encriptados al seleccionar el cliente
            // inmediatamente después de crearlo en la misma sesión.
            await context.read<ClientProvider>().fetchClients();
          } catch (_) {}
        }
      }

      final order = Order(
  id: _isEditing ? _editingOrder!.id : null,
  clientId: _rutController.text.trim().isNotEmpty
      ? _rutController.text.trim()
      : _clientNameController.text.trim(),
  clientName: _clientNameController.text.trim(),
  clientPhone: _phoneController.text.trim(),
  address: fullAddress,
  weight: weight,
  length: double.tryParse(_lengthController.text) ?? 0.0,
  width: double.tryParse(_widthController.text) ?? 0.0,
  height: double.tryParse(_heightController.text) ?? 0.0,
  loadType: _selectedLoad,
  timeWindow: _selectedWindow!,
  status: _isEditing ? _editingOrder!.status : 'Pendiente',
  scheduledDate: _isEditing ? _editingOrder!.scheduledDate : DateTime.now(),
  driverId: _selectedDriverId!,
driverName: _selectedDriverName,
);

      if (!mounted) return;
      if (_isEditing) {
        await context.read<OrderProvider>().updateOrder(order);
      } else {
        await context.read<OrderProvider>().addOrder(order);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Pedido actualizado exitosamente'
                : 'Pedido registrado y asignado exitosamente'),
          ),
        );
        _resetForm();
        widget.onOrderSaved();
      }
    }
  }

  @override
Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.accentOrange),
            SizedBox(height: 16),
            Text(
              'Cargando flota y clientes...',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final clients = context.watch<ClientProvider>().clients;

    // Mostrar todos los vehículos que tienen conductor asignado
    final vehicles = context
        .watch<VehicleProvider>()
        .vehicles
        .where((v) => v.driverName.trim().isNotEmpty)
        .toList();

    // 🛑 BUGFIX 2: Sincronizar referencias de memoria para evitar crasheo
    if (_selectedVehicle != null) {
      final matchedIndex = vehicles.indexWhere((v) => v.patente == _selectedVehicle!.patente);
      if (matchedIndex != -1) {
        // El vehículo sigue en la lista, actualizamos el puntero de memoria
        _selectedVehicle = vehicles[matchedIndex];
      } else {
        // El vehículo ya no cumple los requisitos (ej. conductor inactivo), se limpia la selección
        _selectedVehicle = null;
      }
    }

    // HU02.1: conductores con un pedido activo (no Entregado/Anulado) no deben
    // aparecer disponibles para un nuevo despacho, salvo que sea el conductor
    // ya asignado al pedido que se está editando actualmente.
    final busyDriverIds = context
        .watch<OrderProvider>()
        .orders
        .where((o) => o.status != 'Entregado' && o.status != 'Anulado')
        .map((o) => o.driverId)
        .toSet();

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
                  // FIX: Dropdown tipado como Client? para trabajar directamente
                  // con el objeto en memoria — sin re-búsqueda por rut.
                  DropdownButtonFormField<Client>(
                    isExpanded: true,
                    value: _selectedClient,
                    items: [
                      const DropdownMenuItem<Client>(
                        value: null,
                        child: Text(
                          'Ingresar nuevo cliente manualmente',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...clients.map(
                        (c) => DropdownMenuItem<Client>(
                          value: c,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (Client? selected) {
                      setState(() {
                        _selectedClient = selected;
                        if (selected == null) {
                          _isManualClient = true;
                          _clientNameController.clear();
                          _rutController.clear();
                          _phoneController.clear();
                          _emailController.clear();
                          _calleController.clear();
                          _numeroController.clear();
                          _comunaController.clear();
                        } else {
                          _isManualClient = false;
                          // Datos directamente del objeto en memoria (ya desencriptados por fromMap)
                          _clientNameController.text = selected.name;
                          _rutController.text = selected.rut;
                          _phoneController.text = selected.phone;
                          _emailController.text = selected.email;

                          // Autocompletar dirección desde billingAddress
                          final address = selected.billingAddress.trim();
                          if (address.isNotEmpty) {
                            final commaIdx = address.lastIndexOf(',');
                            if (commaIdx != -1) {
                              final streetPart = address.substring(0, commaIdx).trim();
                              _comunaController.text = address.substring(commaIdx + 1).trim();
                              final lastSpaceIdx = streetPart.lastIndexOf(' ');
                              if (lastSpaceIdx != -1) {
                                _calleController.text = streetPart.substring(0, lastSpaceIdx).trim();
                                _numeroController.text = streetPart.substring(lastSpaceIdx + 1).trim();
                              } else {
                                _calleController.text = streetPart;
                                _numeroController.clear();
                              }
                            } else {
                              _calleController.text = address;
                              _numeroController.clear();
                              _comunaController.clear();
                            }
                          }
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
                  // RUT
TextFormField(
  controller: _rutController,
  keyboardType: TextInputType.text,
  inputFormatters: [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9kK]')),
    LengthLimitingTextInputFormatter(9),
  ],
  onChanged: (value) {
    final limpio = value.replaceAll('-', '');

    if (limpio.length >= 2) {
      final nuevo =
          '${limpio.substring(0, limpio.length - 1)}-${limpio.substring(limpio.length - 1)}';

      if (nuevo != _rutController.text) {
        _rutController.value = TextEditingValue(
          text: nuevo,
          selection: TextSelection.collapsed(
            offset: nuevo.length,
          ),
        );
      }
    }
  },
  decoration: const InputDecoration(
    labelText: 'RUT *',
    hintText: '12345678-5',
  ),
  validator: (value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingrese un RUT';
    }

    final rut = value.trim().toUpperCase();

    if (!rut.contains('-')) {
      return 'El RUT debe incluir guion';
    }

    final partes = rut.split('-');

    if (partes.length != 2) {
      return 'Formato inválido';
    }

    final cuerpo = partes[0];
    final dvIngresado = partes[1];

    if (cuerpo.length < 7 || cuerpo.length > 8) {
      return 'RUT inválido';
    }

    int suma = 0;
    int multiplicador = 2;

    for (int i = cuerpo.length - 1; i >= 0; i--) {
      suma += int.parse(cuerpo[i]) * multiplicador;
      multiplicador = multiplicador == 7 ? 2 : multiplicador + 1;
    }

    final resto = 11 - (suma % 11);

    String dvCorrecto;

    if (resto == 11) {
      dvCorrecto = '0';
    } else if (resto == 10) {
      dvCorrecto = 'K';
    } else {
      dvCorrecto = resto.toString();
    }

    if (dvIngresado != dvCorrecto) {
      return 'RUT no válido';
    }

    return null;
  },
),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      prefixText: '+56 ',
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    readOnly: !_isManualClient,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      if (v.trim().length != 9) return 'Debe tener 9 dígitos';
                      if (!v.trim().startsWith('9')) return 'Debe comenzar con 9';
                      return null;
                    },
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
                    readOnly: !_isManualClient,
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
                    readOnly: !_isManualClient,
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
                    readOnly: !_isManualClient,
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
                    hint: const Text('Seleccione una ventana horaria'),
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
                    onChanged: (v) => setState(() => _selectedWindow = v),
                    decoration: const InputDecoration(
                      labelText: 'Ventana Horaria *',
                    ),
                    validator: (v) =>
                        v == null ? 'Seleccione una ventana horaria' : null,
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
  onChanged: (value) {
    setState(() {}); // 
  },
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
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _widthController,
                          decoration: const InputDecoration(labelText: 'Ancho'),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _heightController,
                          decoration: const InputDecoration(labelText: 'Alto'),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
         
                  
// ── Selector de vehículo ───────────────────────
Builder(
  builder: (context) {
    final peso = double.tryParse(_weightController.text) ?? 0;

    final vehiculosFiltrados = vehicles
        .where((v) => v.maxWeight >= peso)
        .toList();

    if (vehicles.isEmpty) {
      return const Text(
        'No hay vehículos registrados. Agregue uno en Ajustes > Gestión de Flota.',
        style: TextStyle(color: Colors.red, fontSize: 13),
      );
    }

    if (vehiculosFiltrados.isEmpty) {
      return const Text(
        'No hay vehículos disponibles para ese peso.',
        style: TextStyle(color: Colors.red, fontSize: 13),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<Vehicle>(
          isExpanded: true,
          value: vehiculosFiltrados.contains(_selectedVehicle)
              ? _selectedVehicle
              : null,
          items: vehiculosFiltrados
              .map(
                (v) => DropdownMenuItem<Vehicle>(
                  value: v,
                  child: Text(
                    '${v.name} [${v.patente}] (Max: ${v.maxWeight} kg)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
         onChanged: (v) async {
  if (v == null) return;

  final driverId = await getDriverIdByName(v.driverName);

  setState(() {
    _selectedVehicle = v;
    _selectedDriverName = v.driverName;
    _selectedDriverId = driverId; 
  });
},
          decoration: const InputDecoration(
            labelText: 'Vehículo *',
            prefixIcon: Icon(Icons.local_shipping_outlined),
          ),
          validator: (v) => v == null ? 'Requerido' : null,
        ),

        const SizedBox(height: 10),

        if (_selectedDriverName != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Conductor asignado: $_selectedDriverName',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  },
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
            ),
          ),
        ],
      ),
    );
  }
}