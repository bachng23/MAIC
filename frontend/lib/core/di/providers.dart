import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/health/presentation/health_controller.dart';
import '../../features/scan/presentation/scan_controller.dart';
import '../../features/shared/data/mediguard_api_service.dart';
import '../../features/profile/presentation/profile_controller.dart';
import '../notifications/medication_notification_service.dart';
import '../network/auth_interceptor.dart';
import '../storage/profile_storage.dart';
import '../storage/token_storage.dart';

const _defaultBaseUrl = 'https://maic-production-3798.up.railway.app';

/// Bumped on login/logout so user-scoped [FutureProvider]s refetch instead of reusing cache.
final authSessionIdProvider = StateProvider<int>((ref) => 0);

void invalidateUserScopedProviders(Ref ref) {
  ref.read(authSessionIdProvider.notifier).state++;
  ref.invalidate(dashboardControllerProvider);
  ref.read(scanControllerProvider).clearForNewEntry();
  ref.read(healthControllerProvider).reset();
  ref.read(profileControllerProvider).reset();
  ref.read(medicationNotificationServiceProvider).cancelAllMedicationReminders();
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: _defaultBaseUrl,
      headers: const {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(AuthInterceptor(ref.watch(tokenStorageProvider)));
  return dio;
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(ref.watch(secureStorageProvider));
});

final apiServiceProvider = Provider<MediGuardApiService>((ref) {
  return MediGuardApiService(
    ref.watch(dioProvider),
    ref.watch(tokenStorageProvider),
  );
});

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  final controller = AuthController(
    ref.watch(apiServiceProvider),
    ref.watch(tokenStorageProvider),
    onSessionChanged: () => invalidateUserScopedProviders(ref),
  );
  controller.bootstrap();
  return controller;
});

final dashboardControllerProvider = FutureProvider<DashboardViewData>((ref) async {
  ref.watch(authSessionIdProvider);
  final isAuthenticated = ref.watch(
    authControllerProvider.select((auth) => auth.isAuthenticated),
  );
  if (!isAuthenticated) {
    return DashboardViewData(medications: [], schedules: [], contacts: []);
  }
  return ref.watch(apiServiceProvider).loadDashboard();
});

final medicationNotificationServiceProvider = Provider<MedicationNotificationService>((ref) {
  return MedicationNotificationService();
});

final scanControllerProvider = ChangeNotifierProvider<ScanController>((ref) {
  return ScanController(
    ref.watch(apiServiceProvider),
    ref.watch(medicationNotificationServiceProvider),
  );
});

final healthControllerProvider = ChangeNotifierProvider<HealthController>((ref) {
  return HealthController(ref.watch(apiServiceProvider));
});

final profileStorageProvider = Provider<ProfileStorage>((ref) {
  return ProfileStorage(ref.watch(secureStorageProvider));
});

final profileControllerProvider = ChangeNotifierProvider<ProfileController>((ref) {
  final controller = ProfileController(
    ref.watch(profileStorageProvider),
    ref.watch(tokenStorageProvider),
  );
  ref.listen<int>(authSessionIdProvider, (previous, next) {
    if (previous != next) controller.bootstrap();
  });
  controller.bootstrap();
  return controller;
});

final backendHealthProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(apiServiceProvider).healthCheck();
});
