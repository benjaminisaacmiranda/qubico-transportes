import 'package:cloud_firestore/cloud_firestore.dart';

class Vehicle {
  final int? id;
  final String name;
  final String patente;
  final double maxWeight;
  final String driverName;

  Vehicle({
    this.id,
    required this.name,
    required this.patente,
    required this.maxWeight,
    required this.driverName,
  });

  // ───── SQLITE ─────
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'patente': patente,
      'max_weight': maxWeight,
      'driver_name': driverName,
    };
  }

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'],
      name: map['name'] ?? '',
      patente: map['patente'] ?? '',
      maxWeight: (map['maxWeight'] ?? map['max_weight'] ?? 0).toDouble(),
      driverName: map['driverName'] ?? map['driver_name'] ?? '',
    );
  }

  // ───── FIRESTORE ─────
  factory Vehicle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Vehicle(
      id: null,
      name: data['name'] ?? '',
      patente: doc.id, // 
      maxWeight: (data['maxWeight'] ?? 0).toDouble(),
      driverName: data['driverName'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'maxWeight': maxWeight,
      'driverName': driverName,
    };
  }
}