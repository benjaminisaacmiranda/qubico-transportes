import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/security_service.dart';

class UserProvider with ChangeNotifier {
  List<User> _users = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<User> get users => List.unmodifiable(_users);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchUsers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await DatabaseService.instance.queryAll('users');
      _users = data.map((map) => User.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error fetching users: $e');
      _errorMessage = 'Error al cargar usuarios: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addUser(User user, {String? password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userMap = user.toMap();

      // Hash password before storing if provided
      if (password != null && password.isNotEmpty) {
        userMap['password'] = SecurityService.hashPassword(password);
      }

      await DatabaseService.instance.insert('users', userMap);
      await fetchUsers();
    } catch (e) {
      debugPrint('Error adding user: $e');
      _errorMessage = 'Error al agregar usuario: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUser(User user, {String? newPassword}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userMap = user.toMap();

      // Hash the new password if provided
      if (newPassword != null && newPassword.isNotEmpty) {
        userMap['password'] = SecurityService.hashPassword(newPassword);
      }

      await DatabaseService.instance.update('users', userMap, 'id', user.id);
      await fetchUsers();
    } catch (e) {
      debugPrint('Error updating user: $e');
      _errorMessage = 'Error al actualizar usuario: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteUser(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await DatabaseService.instance.delete('users', 'id', id);
      await fetchUsers();
    } catch (e) {
      debugPrint('Error deleting user: $e');
      _errorMessage = 'Error al eliminar usuario: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleUserStatus(String id, bool currentStatus) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await DatabaseService.instance.update('users', {'is_active': currentStatus ? 0 : 1}, 'id', id);
      await fetchUsers();
    } catch (e) {
      debugPrint('Error toggling user status: $e');
      _errorMessage = 'Error al cambiar estado del usuario: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
}