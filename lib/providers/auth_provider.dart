import 'package:flutter/foundation.dart';

// 🎯 ENLACES RELATIVOS
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/security_service.dart';

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

  // 🔄 Agregamos el parámetro opcional 'isFirebaseVerified'
  Future<bool> login(String email, String password, {bool isFirebaseVerified = false}) async {
    if (isLocked) {
      _errorMessage = 'Cuenta bloqueada. Intente en ${_lockoutUntil!.difference(DateTime.now()).inMinutes + 1} minutos.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 🔍 Buscar usuario en la base de datos local SQLite
      final userData = await DatabaseService.instance.getUserByEmail(email);

      if (userData == null) {
        _handleFailedAttempt();
        return false;
      }

      final user = User.fromMap(userData);
      final storedPassword = userData['password'] as String? ?? '';

      // Verificar si la contraseña coincide localmente
      bool isPasswordValid = SecurityService.verifyPassword(password, storedPassword);

      if (!isPasswordValid) {
        // 🛠️ SI FIREBASE YA DIJO QUE SÍ, CORREGIMOS EL HASH LOCAL DE INMEDIATO
        if (isFirebaseVerified) {
          final newHash = SecurityService.hashPassword(password);
          await DatabaseService.instance.update('users', {'password': newHash}, 'id', user.id);
          isPasswordValid = true; // Forzamos la aprobación local
        } else {
          _handleFailedAttempt();
          return false;
        }
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