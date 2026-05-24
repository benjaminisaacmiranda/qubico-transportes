import 'package:flutter/foundation.dart';
import 'package:qubico/models/user_model.dart';
import 'package:qubico/services/database_service.dart';
import 'package:qubico/services/security_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  int _failedAttempts = 0;
  static const int _maxAttempts = 5;
  DateTime? _lockoutUntil;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  String get currentUserId => _currentUser?.id ?? 'Sistema';
  String get currentUserName => _currentUser?.fullName ?? 'Usuario';
  String get currentUserRole => _currentUser?.role.toString().split('.').last ?? '';
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get isLocked => _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);

  Future<bool> login(String email, String password) async {
    // Check lockout
    if (isLocked) {
      _errorMessage = 'Cuenta bloqueada. Intente en ${_lockoutUntil!.difference(DateTime.now()).inMinutes + 1} minutos.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userData = await DatabaseService.instance.getUserByEmail(email);
      if (userData == null) {
        _handleFailedAttempt();
        return false;
      }

      final user = User.fromMap(userData);

      // Verify password using SecurityService
      final storedPassword = userData['password'] as String? ?? '';
      if (!SecurityService.verifyPassword(password, storedPassword)) {
        _handleFailedAttempt();
        return false;
      }

      _currentUser = user;
      _failedAttempts = 0;
      _lockoutUntil = null;
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al iniciar sesión: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void _handleFailedAttempt() {
    _failedAttempts++;
    if (_failedAttempts >= _maxAttempts) {
      _lockoutUntil = DateTime.now().add(const Duration(minutes: 5));
      _errorMessage = 'Demasiados intentos fallidos. Cuenta bloqueada por 5 minutos.';
    } else {
      _errorMessage = 'Credenciales incorrectas. Intentos restantes: ${_maxAttempts - _failedAttempts}';
    }
    _isLoading = false;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
