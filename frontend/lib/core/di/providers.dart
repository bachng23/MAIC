import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../apple_native/apple_native_bridge.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/health/data/monitoring_service.dart';
import '../../features/health/presentation/health_controller.dart';
import '../../features/scan/presentation/medication_intake_controller.dart';
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
  ref.read(medicationIntakeControllerProvider).reset();
  ref.read(medicationNotificationServiceProvider).cancelAllMedicationReminders();
}

// Named function with explicit return type breaks the type-inference circularity
// that would occur if the lambda directly referenced authControllerProvider.
Dio _buildDio(Ref ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);

  // Bare Dio used only for token refresh — no auth interceptor to avoid re-entry.
  final refreshDio = Dio(BaseOptions(
    baseUrl: _defaultBaseUrl,
    headers: const {'Accept': 'application/json'},
  ));

  final dio = Dio(BaseOptions(
    baseUrl: _defaultBaseUrl,
    headers: const {'Accept': 'application/json'},
  ));

  Future<String?> doRefresh() async {
    final refreshToken = await tokenStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    final response = await refreshDio.post<Map<String, dynamic>>(
      '/api/v1/auth/refresh',
      data: {'refresh_token': refreshToken},
      options: Options(contentType: 'application/json'),
    );

    final data = (response.data?['data'] as Map?)?.cast<String, dynamic>();
    final newAccess = data?['access_token'] as String?;
    final newRefresh = data?['refresh_token'] as String?;

    if (newAccess != null) {
      await tokenStorage.writeToken(newAccess);
      if (newRefresh != null) await tokenStorage.writeRefreshToken(newRefresh);
    }
    return newAccess;
  }

  void doLogout() => ref.read(authControllerProvider).logout();

  dio.interceptors.add(AuthInterceptor(
    tokenStorage,
    onRefreshToken: doRefresh,
    onUnauthorized: doLogout,
  ));

  return dio;
}

final dioProvider = Provider<Dio>(_buildDio);

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

final medicationIntakeControllerProvider = ChangeNotifierProvider<MedicationIntakeController>((ref) {
  return MedicationIntakeController();
});

final scanControllerProvider = ChangeNotifierProvider<ScanController>((ref) {
  return ScanController(
    ref.watch(apiServiceProvider),
    ref.watch(medicationNotificationServiceProvider),
    ref.watch(medicationIntakeControllerProvider),
  );
});

final bridgeProvider = Provider<AppleNativeBridge>((_) => AppleNativeBridge());

/// Singleton monitoring service — survives tab navigation.
/// Starts polling Apple Watch HealthKit data every 3 min after medication taken.
final monitoringServiceProvider = ChangeNotifierProvider<MonitoringService>((ref) {
  return MonitoringService(
    ref.watch(bridgeProvider),
    ref.watch(apiServiceProvider),
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
