import 'package:go_router/go_router.dart';

import '../ui/screens/admin/admin_dashboard_screen.dart';
import '../ui/screens/auth_wrapper.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/login_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const AuthWrapper()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
    ],
  );
}
