import 'package:flutter/foundation.dart';
import '../models/client_model.dart';
import '../services/database_service.dart';

class ClientProvider with ChangeNotifier {
  List<Client> _clients = [];
  List<Client> get clients => _clients;

  Future<void> fetchClients() async {
    final data = await DatabaseService.instance.queryAll('clients');
    _clients = data.map((e) => Client.fromMap(e)).toList();
    if (_clients.isEmpty) {
      _clients = [
        Client(rut: '12.345.678-9', name: 'Empresa Alpha', phone: '912345678', email: 'contacto@alpha.cl', billingAddress: 'Providencia 123'),
        Client(rut: '98.765.432-1', name: 'Logística Beta', phone: '998765432', email: 'ventas@beta.cl', billingAddress: 'Las Condes 456'),
      ];
      for (var c in _clients) {
        await DatabaseService.instance.insert('clients', c.toMap());
      }
    }
    notifyListeners();
  }
}
