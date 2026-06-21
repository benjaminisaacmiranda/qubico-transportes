import 'package:cloud_firestore/cloud_firestore.dart';

class Order {
  final String? id;
  final String clientId;
  final String clientName;
  final String clientPhone;
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
  final String driverName;
  final String? evidencePath;
  final String? signaturePath;
  final String? incidentReason;
  final DateTime? deliveryTime;

  Order({
    this.id,
    required this.clientId,
    this.clientName = '',
    this.clientPhone = '',
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
    this.driverName = '',
    this.evidencePath,
    this.signaturePath,
    this.incidentReason,
    this.deliveryTime,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'weight': weight,
      'height': height,
      'length': length,
      'width': width,
      'loadType': loadType,
      'timeWindow': timeWindow,
      'address': address,
      'status': status,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'driverId': driverId,
      'driverName': driverName,
      'evidencePath': evidencePath,
      'signaturePath': signaturePath,
      'incidentReason': incidentReason,
      'deliveryTime': deliveryTime != null
          ? Timestamp.fromDate(deliveryTime!)
          : null,
    };
  }

  factory Order.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data()!;
    return Order(
      id: doc.id,
      clientId: map['clientId'] ?? '',
      clientName: map['clientName'] ?? '',
      clientPhone: map['clientPhone'] ?? '',
      weight: (map['weight'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
      length: (map['length'] as num).toDouble(),
      width: (map['width'] as num).toDouble(),
      loadType: map['loadType'] ?? '',
      timeWindow: map['timeWindow'] ?? '',
      address: map['address'] ?? '',
      status: map['status'] ?? 'Pendiente',
      scheduledDate: (map['scheduledDate'] as Timestamp).toDate(),
      driverId: map['driverId'],
      driverName: map['driverName'] ?? '',
      evidencePath: map['evidencePath'],
      signaturePath: map['signaturePath'],
      incidentReason: map['incidentReason'],
      deliveryTime: map['deliveryTime'] != null
          ? (map['deliveryTime'] as Timestamp).toDate()
          : null,
    );
  }
}
