import '../services/security_service.dart';

class Client {
  final String rut;
  final String name;
  final String phone;
  final String email;
  final String billingAddress;

  Client({
    required this.rut,
    required this.name,
    required this.phone,
    required this.email,
    required this.billingAddress,
  });

  Map<String, dynamic> toMap() {
    return {
      'rut': SecurityService.encrypt(rut),
      'name': name,
      'phone': SecurityService.encrypt(phone),
      'email': email,
      'billing_address': billingAddress,
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      rut: SecurityService.decrypt(map['rut']),
      name: map['name'],
      phone: SecurityService.decrypt(map['phone']),
      email: map['email'],
      billingAddress: map['billing_address'],
    );
  }
}
