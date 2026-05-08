import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/di/providers.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/dashboard/presentation/home_page.dart';
import '../features/health/presentation/health_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/scan/presentation/scan_page.dart';
import '../features/compliance/presentation/compliance_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  return GoRouter(
    initialLocation: '/welcome',
    refreshListenable: auth,
    redirect: (context, state) {
      final isAuth = auth.isAuthenticated;
      final loc = state.fullPath ?? '/welcome';
      final authRoutes = {'/welcome', '/login', '/register'};
      if (!isAuth && !authRoutes.contains(loc)) return '/login';
      if (isAuth && authRoutes.contains(loc)) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const LoginPage(isWelcome: true),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) => const ScanPage(),
      ),
      GoRoute(
        path: '/health',
        builder: (context, state) => const HealthPage(),
      ),
      GoRoute(
        path: '/compliance',
        builder: (context, state) => const CompliancePage(),
      ),
    ],
  );
});
