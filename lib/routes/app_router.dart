import 'package:go_router/go_router.dart';

import '../ui/screens/admin_dashboard_screen.dart';
import '../ui/screens/auth_wrapper.dart'; // <-- Nuevo import del Wrapper
import '../ui/screens/home_screen.dart';
import '../ui/screens/login_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/', // Ahora la app arranca en la raíz
    routes: [
      // 1. La ruta inicial ahora es el AuthWrapper que evalúa la sesión
      GoRoute(
        path: '/',
        builder: (context, state) => const AuthWrapper(),
      ),
      // 2. Ruta de Login (el AuthWrapper te mandará aquí si NO hay sesión)
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      // 3. Ruta del Conductor
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      // 4. Ruta del Administrador
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
    ],
  );
}