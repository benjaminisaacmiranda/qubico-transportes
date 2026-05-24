import 'package:flutter/foundation.dart';
import '../models/vehicle_model.dart';
import '../services/database_service.dart';

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
      final id = await DatabaseService.instance.insert('vehicles', vehicle.toMap());
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
      await DatabaseService.instance.update('vehicles', vehicle.toMap(), 'id', vehicle.id);
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

  Future<void> deleteVehicle(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await DatabaseService.instance.delete('vehicles', 'id', id);
      _vehicles.removeWhere((v) => v.id == id);
    } catch (e) {
      debugPrint('Error deleting vehicle: $e');
      _errorMessage = 'Error al eliminar vehículo: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Filter vehicles by driver name
  List<Vehicle> getVehiclesByDriver(String driverName) {
    return _vehicles.where((v) => v.driverName == driverName).toList();
  }

  /// Filter vehicles that can carry the given weight
  List<Vehicle> getVehiclesByMinCapacity(double minWeight) {
    return _vehicles.where((v) => v.maxWeight >= minWeight).toList();
  }

  /// Search vehicles by name, patente, or driver
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
