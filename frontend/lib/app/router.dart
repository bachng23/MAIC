import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/di/providers.dart';
import 'navigation_shell_scaffold.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/phone_entry_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/auth/presentation/verify_phone_page.dart';
import '../features/dashboard/presentation/home_page.dart';
import '../features/health/presentation/health_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/scan/presentation/scan_page.dart';
import '../features/compliance/presentation/compliance_page.dart';

String _maskPhoneForDisplay(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return 'your mobile number';
  final digits = t.replaceAll(RegExp(r'\D'), '');
  if (digits.length <= 4) return '••••';
  final tail = digits.substring(digits.length - 4);
  return '+•• ••• •• $tail';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  return GoRouter(
    initialLocation: '/welcome',
    refreshListenable: auth,
    redirect: (context, state) {
      final isAuth = auth.isAuthenticated;
      final loc = state.matchedLocation;
      final authRoutes = {'/welcome', '/login', '/register', '/phone', '/verify-phone'};
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
        path: '/phone',
        builder: (context, state) => const PhoneEntryPage(),
      ),
      GoRoute(
        path: '/verify-phone',
        builder: (context, state) {
          final raw = state.uri.queryParameters['phone'] ?? '';
          return VerifyPhonePage(maskedPhone: _maskPhoneForDisplay(raw));
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return NavigationShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/scan',
                builder: (context, state) => const ScanPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/health',
                builder: (context, state) => const HealthPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/compliance',
                builder: (context, state) => const CompliancePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
