import '../services/security_service.dart';

class Order {
  final int? id;
  final String clientId;
  final double weight;
  final double height;
  final double length;
  final double width;
  final String loadType;
  final String timeWindow;
  final String address;
  final String status;
  final DateTime scheduledDate;
  final String? driverId;
  final String? evidencePath;
  final String? signaturePath;
  final String? incidentReason;
  final DateTime? deliveryTime;

  // NUEVO
  final bool pendingSync;
  final int syncAttempts;

  Order({
    this.id,
    required this.clientId,
    required this.weight,
    required this.height,
    required this.length,
    required this.width,
    required this.loadType,
    required this.timeWindow,
    required this.address,
    required this.status,
    required this.scheduledDate,
    this.driverId,
    this.evidencePath,
    this.signaturePath,
    this.incidentReason,
    this.deliveryTime,

    // NUEVO
    this.pendingSync = false,
    this.syncAttempts = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_id': SecurityService.encrypt(clientId),
      'weight': weight,
      'height': height,
      'length': length,
      'width': width,
      'load_type': loadType,
      'time_window': timeWindow,
      'address': address,
      'status': status,
      'scheduled_date': scheduledDate.toIso8601String(),
      'driver_id': driverId,
      'evidence_path': evidencePath,
      'signature_path': signaturePath,
      'incident_reason': incidentReason,
      'delivery_time': deliveryTime?.toIso8601String(),

      // NUEVO
      'pending_sync': pendingSync ? 1 : 0,
      'sync_attempts': syncAttempts,
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'],
      clientId: SecurityService.decrypt(map['client_id']),
      weight: map['weight'],
      height: map['height'],
      length: map['length'],
      width: map['width'],
      loadType: map['load_type'],
      timeWindow: map['time_window'],
      address: map['address'],
      status: map['status'],
      scheduledDate: DateTime.parse(map['scheduled_date']),
      driverId: map['driver_id'],
      evidencePath: map['evidence_path'],
      signaturePath: map['signature_path'],
      incidentReason: map['incident_reason'],
      deliveryTime: map['delivery_time'] != null
          ? DateTime.parse(map['delivery_time'])
          : null,

      // NUEVO
      pendingSync: map['pending_sync'] == 1,
      syncAttempts: map['sync_attempts'] ?? 0,
    );
  }
}
