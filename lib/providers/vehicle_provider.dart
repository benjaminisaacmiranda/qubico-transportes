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

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('vehicles');

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void startListening() {
    _subscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription = _collection.snapshots().listen(
      (snapshot) {
        _vehicles =
            snapshot.docs.map((doc) => Vehicle.fromFirestore(doc)).toList()
              ..sort((a, b) => a.name.compareTo(b.name));

        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Firestore vehicles error: $e');
        _errorMessage = 'Error al cargar vehiculos: $e';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> fetchVehicles() async {
    startListening();
  }

  Future<void> addVehicle(Vehicle vehicle) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _collection.doc(vehicle.patente).set({
        'name': vehicle.name,
        'patente': vehicle.patente,
        'maxWeight': vehicle.maxWeight,
        'driverName': vehicle.driverName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _errorMessage = 'Error al agregar vehiculo: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateVehicle(Vehicle vehicle, String oldPatente) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = {
        'name': vehicle.name,
        'patente': vehicle.patente,
        'maxWeight': vehicle.maxWeight,
        'driverName': vehicle.driverName,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (vehicle.patente != oldPatente) {
        await _collection.doc(vehicle.patente).set(data);
        await _collection.doc(oldPatente).delete();
      } else {
        await _collection.doc(vehicle.patente).update(data);
      }
    } catch (e) {
      debugPrint('Error updating vehicle: $e');
      _errorMessage = 'Error al actualizar vehiculo: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteVehicle(String patente) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _collection.doc(patente).delete();
    } catch (e) {
      _errorMessage = 'Error al eliminar vehiculo: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<Vehicle> getVehiclesByDriver(String driverName) {
    return _vehicles.where((v) => v.driverName == driverName).toList();
  }

  List<Vehicle> getVehiclesByMinCapacity(double minWeight) {
    return _vehicles.where((v) => v.maxWeight >= minWeight).toList();
  }

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
