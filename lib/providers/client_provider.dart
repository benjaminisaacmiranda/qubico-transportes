import 'package:flutter/foundation.dart';
import '../models/client_model.dart';
import '../services/database_service.dart';

class ClientProvider with ChangeNotifier {
  List<Client> _clients = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Client> get clients => List.unmodifiable(_clients);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchClients() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await DatabaseService.instance.queryAll('clients');
      _clients = data.map((e) => Client.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error fetching clients: $e');
      _errorMessage = 'Error al cargar clientes: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addClient(Client client) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await DatabaseService.instance.insert('clients', client.toMap());
      await fetchClients();
    } catch (e) {
      debugPrint('Error adding client: $e');
      _errorMessage = 'Error al agregar cliente: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateClient(Client client) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await DatabaseService.instance.update('clients', client.toMap(), 'rut', client.toMap()['rut']);
      await fetchClients();
    } catch (e) {
      debugPrint('Error updating client: $e');
      _errorMessage = 'Error al actualizar cliente: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteClient(String rut) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // The rut stored in DB is encrypted, so we need to encrypt before querying
      await DatabaseService.instance.delete('clients', 'rut', rut);
      await fetchClients();
    } catch (e) {
      debugPrint('Error deleting client: $e');
      _errorMessage = 'Error al eliminar cliente: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Search clients by name, email, or RUT (case-insensitive)
  List<Client> searchClients(String query) {
    if (query.isEmpty) return List.unmodifiable(_clients);
    final lowerQuery = query.toLowerCase();
    return _clients.where((client) {
      return client.name.toLowerCase().contains(lowerQuery) ||
          client.email.toLowerCase().contains(lowerQuery) ||
          client.rut.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}
