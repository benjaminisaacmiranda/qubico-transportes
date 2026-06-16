import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/vehicle_model.dart';

class VehicleProvider with ChangeNotifier {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

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

  /// 🔥 Escuchar vehículos en tiempo real desde Firestore
  void startListening() {
    _subscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = FirebaseFirestore.instance
        .collection('vehicles')
        .snapshots()
        .listen(
      (snapshot) {
        _vehicles = snapshot.docs
            .map((doc) => Vehicle.fromFirestore(doc))
            .toList();

        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Firestore vehicles error: $e');
        _errorMessage = 'Error al cargar vehículos: $e';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// (Opcional) compatibilidad si llamas fetchVehicles()
  Future<void> fetchVehicles() async {
    startListening();
  }

  /// ➕ Agregar vehículo
  Future<void> addVehicle(Vehicle vehicle) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(vehicle.patente) // 👈 patente como ID
          .set({
        'name': vehicle.name,
        'maxWeight': vehicle.maxWeight,
        'driverName': vehicle.driverName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error adding vehicle: $e');
      _errorMessage = 'Error al agregar vehículo: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Actualizar vehículo
Future<void> updateVehicle(Vehicle vehicle, String oldPatente) async {
  _isLoading = true;
  _errorMessage = null;
  notifyListeners();

  try {
    final collection = FirebaseFirestore.instance.collection('vehicles');

    if (vehicle.patente != oldPatente) {
      await collection.doc(vehicle.patente).set({
        'name': vehicle.name,
        'patente': vehicle.patente,
        'maxWeight': vehicle.maxWeight,
        'driverName': vehicle.driverName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await collection.doc(oldPatente).delete();
    } else {
      await collection.doc(vehicle.patente).update({
        'name': vehicle.name,
        'maxWeight': vehicle.maxWeight,
        'driverName': vehicle.driverName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  } catch (e) {
    debugPrint('Error updating vehicle: $e');
    _errorMessage = 'Error al actualizar vehículo: $e';
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
  /// ❌ Eliminar vehículo
  Future<void> deleteVehicle(String patente) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(patente)
          .delete();
    } catch (e) {
      debugPrint('Error deleting vehicle: $e');
      _errorMessage = 'Error al eliminar vehículo: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 🔍 Filtrar por conductor
  List<Vehicle> getVehiclesByDriver(String driverName) {
    return _vehicles.where((v) => v.driverName == driverName).toList();
  }

  /// 🔍 Filtrar por capacidad
  List<Vehicle> getVehiclesByMinCapacity(double minWeight) {
    return _vehicles.where((v) => v.maxWeight >= minWeight).toList();
  }

  /// 🔍 Buscar vehículos
  List<Vehicle> searchVehicles(String query) {
    if (query.isEmpty) return List.unmodifiable(_vehicles);

    final lowerQuery = query.toLowerCase();

    return _vehicles.where((v) {
      return v.name.toLowerCase().contains(lowerQuery) ||
          v.patente.toLowerCase().contains(lowerQuery) ||
          v.driverName.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}