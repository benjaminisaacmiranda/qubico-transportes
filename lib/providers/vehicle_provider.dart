import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/vehicle_model.dart';
import '../services/database_service.dart';

import '../services/connectivity_service.dart';

class VehicleProvider with ChangeNotifier {
  List<Vehicle> _vehicles = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchVehicles() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await DatabaseService.instance.queryAll('vehicles');
      _vehicles = data.map((e) => Vehicle.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error fetching vehicles: $e');
      _errorMessage = 'Error al cargar vehículos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addVehicle(Vehicle vehicle) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Siempre guardar localmente
      final id = await DatabaseService.instance.insert(
        'vehicles',
        vehicle.toMap(),
      );

      // Verificar conexión
      final isConnected = await ConnectivityService().isConnected();

      if (isConnected) {
        try {
          await FirebaseFirestore.instance
              .collection('vehicles')
              .doc(vehicle.patente)
              .set({
                'name': vehicle.name,
                'patente': vehicle.patente,
                'maxWeight': vehicle.maxWeight,
                'driverName': vehicle.driverName,
                'createdAt': FieldValue.serverTimestamp(),
              });
        } catch (e) {
          debugPrint('Error sincronizando vehículo con Firestore: $e');
        }
      }

      final newVehicle = Vehicle(
        id: id,
        name: vehicle.name,
        patente: vehicle.patente,
        maxWeight: vehicle.maxWeight,
        driverName: vehicle.driverName,
      );

      _vehicles.add(newVehicle);
    } catch (e) {
      debugPrint('Error adding vehicle: $e');
      _errorMessage = 'Error al agregar vehículo: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    if (vehicle.id == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Siempre actualizar SQLite
      await DatabaseService.instance.update(
        'vehicles',
        vehicle.toMap(),
        'id',
        vehicle.id,
      );

      final isConnected = await ConnectivityService().isConnected();

      if (isConnected) {
        try {
          await FirebaseFirestore.instance
              .collection('vehicles')
              .doc(vehicle.patente)
              .set({
                'name': vehicle.name,
                'patente': vehicle.patente,
                'maxWeight': vehicle.maxWeight,
                'driverName': vehicle.driverName,
                'updatedAt': FieldValue.serverTimestamp(),
              });
        } catch (e) {
          debugPrint('Error sincronizando actualización: $e');
        }
      }

      final index = _vehicles.indexWhere((v) => v.id == vehicle.id);

      if (index != -1) {
        _vehicles[index] = vehicle;
      }
    } catch (e) {
      debugPrint('Error updating vehicle: $e');
      _errorMessage = 'Error al actualizar vehículo: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteVehicle(int id, String patente) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Siempre eliminar localmente
      await DatabaseService.instance.delete('vehicles', 'id', id);

      final isConnected = await ConnectivityService().isConnected();

      if (isConnected) {
        try {
          await FirebaseFirestore.instance
              .collection('vehicles')
              .doc(patente)
              .delete();
        } catch (e) {
          debugPrint('Error eliminando en Firestore: $e');
        }
      }

      _vehicles.removeWhere((v) => v.id == id);
    } catch (e) {
      debugPrint('Error deleting vehicle: $e');
      _errorMessage = 'Error al eliminar vehículo: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Filtrar vehículos por conductor
  List<Vehicle> getVehiclesByDriver(String driverName) {
    return _vehicles.where((v) => v.driverName == driverName).toList();
  }

  /// Filtrar vehículos que soporten cierto peso
  List<Vehicle> getVehiclesByMinCapacity(double minWeight) {
    return _vehicles.where((v) => v.maxWeight >= minWeight).toList();
  }

  /// Buscar por nombre, patente o conductor
  List<Vehicle> searchVehicles(String query) {
    if (query.isEmpty) return List.unmodifiable(_vehicles);

    final lowerQuery = query.toLowerCase();

    return _vehicles.where((v) {
      return v.name.toLowerCase().contains(lowerQuery) ||
          v.patente.toLowerCase().contains(lowerQuery) ||
          v.driverName.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}
