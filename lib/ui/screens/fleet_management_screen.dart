import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/vehicle_model.dart';
import '../../providers/vehicle_provider.dart';
import '../theme/app_theme.dart';

class FleetManagementScreen extends StatefulWidget {
  const FleetManagementScreen({super.key});

  @override
  State<FleetManagementScreen> createState() => _FleetManagementScreenState();
}

class _FleetManagementScreenState extends State<FleetManagementScreen> {
  Future<void> _showVehicleDialog(
    BuildContext context, {
    Vehicle? vehicle,
  }) async {
    List<Map<String, String>> conductores = [];
    bool loadError = false;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('rol', isEqualTo: 'conductor')
          .where('isActive', isEqualTo: true)
          .get();

      conductores =
          snap.docs
              .map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  'name': (data['fullName'] as String? ?? '').trim(),
                };
              })
              .where((c) => c['name']!.isNotEmpty)
              .toList()
            ..sort((a, b) => a['name']!.compareTo(b['name']!));
    } catch (_) {
      loadError = true;
    }

    if (!context.mounted) return;

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: vehicle?.name ?? '');
    final patenteController = TextEditingController(
      text: vehicle?.patente ?? '',
    );
    final weightController = TextEditingController(
      text: vehicle?.maxWeight.toString() ?? '',
    );

    String? selectedDriverName = vehicle?.driverName.isNotEmpty == true
        ? vehicle!.driverName
        : null;

    if (selectedDriverName != null &&
        !conductores.any((c) => c['name'] == selectedDriverName)) {
      selectedDriverName = null;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(
              vehicle == null ? 'Registrar Vehiculo' : 'Editar Vehiculo',
            ),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre (Ej: Furgon A)',
                          prefixIcon: Icon(Icons.local_shipping_outlined),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Requerido'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: patenteController,
                        decoration: const InputDecoration(
                          labelText: 'Patente',
                          prefixIcon: Icon(Icons.numbers_outlined),
                          hintText: 'AB-CD-12',
                        ),
                        onChanged: (value) {
                          String text = value
                              .toUpperCase()
                              .replaceAll(RegExp(r'[^A-Z0-9]'), '');

                          if (text.length > 6) {
                            text = text.substring(0, 6);
                          }

                          var formatted = '';

                          for (var i = 0; i < text.length; i++) {
                            if (i == 2 || i == 4) formatted += '-';
                            formatted += text[i];
                          }

                          patenteController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                              offset: formatted.length,
                            ),
                          );
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Requerido';
                          }
                          if (!RegExp(
                            r'^[A-Z]{2}-[A-Z]{2}-\d{2}$',
                          ).hasMatch(value)) {
                            return 'Formato invalido (AB-CD-12)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: weightController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Capacidad Maxima (kg)',
                          prefixIcon: Icon(Icons.scale_outlined),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Requerido'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      if (loadError)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No se pudo cargar la lista de conductores. Verifica tu conexion.',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: selectedDriverName,
                          decoration: const InputDecoration(
                            labelText: 'Conductor Asignado',
                            prefixIcon: Icon(Icons.drive_eta_outlined),
                          ),
                          hint: Text(
                            conductores.isEmpty
                                ? 'No hay conductores registrados'
                                : 'Seleccione un conductor',
                            style: TextStyle(
                              color: conductores.isEmpty
                                  ? Colors.red[400]
                                  : Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                          items: conductores.isEmpty
                              ? null
                              : conductores
                                    .map(
                                      (conductor) => DropdownMenuItem<String>(
                                        value: conductor['name'],
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.drive_eta,
                                              size: 18,
                                              color: AppTheme.accentOrange,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(conductor['name']!),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                          onChanged: conductores.isEmpty
                              ? null
                              : (value) => setDialogState(
                                  () => selectedDriverName = value,
                                ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Debe asignar un conductor'
                              : null,
                        ),
                      if (!loadError && conductores.isEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppTheme.accentOrange,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Crea un conductor en Gestion de Usuarios primero.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('CANCELAR'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;

                  final newVehicle = Vehicle(
                    id: vehicle?.id,
                    name: nameController.text.trim(),
                    patente: patenteController.text.trim().toUpperCase(),
                    maxWeight: double.tryParse(weightController.text) ?? 0.0,
                    driverName: selectedDriverName ?? '',
                  );

                  final provider = context.read<VehicleProvider>();
                  if (vehicle == null) {
                    provider.addVehicle(newVehicle);
                  } else {
                    provider.updateVehicle(newVehicle, vehicle.patente);
                  }

                  Navigator.pop(dialogContext);
                },
                child: const Text('GUARDAR'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestion de Flota')),
      body: Consumer<VehicleProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.vehicles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay vehiculos registrados.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Presiona + para agregar el primero',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.vehicles.length,
            itemBuilder: (context, index) {
              final vehicle = provider.vehicles[index];
              final hasDriver = vehicle.driverName.isNotEmpty;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_shipping,
                      color: AppTheme.primaryBlue,
                      size: 28,
                    ),
                  ),
                  title: Text(
                    '${vehicle.name} - ${vehicle.patente}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Capacidad: ${vehicle.maxWeight} kg'),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.drive_eta,
                            size: 14,
                            color: hasDriver
                                ? AppTheme.accentOrange
                                : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasDriver
                                ? vehicle.driverName
                                : 'Sin conductor asignado',
                            style: TextStyle(
                              color: hasDriver
                                  ? AppTheme.accentOrange
                                  : Colors.grey,
                              fontWeight: hasDriver
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                    onPressed: () =>
                        _showVehicleDialog(context, vehicle: vehicle),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showVehicleDialog(context),
        backgroundColor: AppTheme.primaryBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
