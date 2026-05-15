import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/health/presentation/health_controller.dart';
import '../../features/scan/presentation/scan_controller.dart';
import '../../features/shared/data/mediguard_api_service.dart';
import '../storage/token_storage.dart';

const _defaultBaseUrl = 'https://maic-production-3798.up.railway.app';

final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(baseUrl: _defaultBaseUrl));
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
  );
  controller.bootstrap();
  return controller;
});

final dashboardControllerProvider = FutureProvider<DashboardViewData>((ref) async {
  return ref.watch(apiServiceProvider).loadDashboard();
});

final scanControllerProvider = ChangeNotifierProvider<ScanController>((ref) {
  return ScanController(ref.watch(apiServiceProvider));
});

final healthControllerProvider = ChangeNotifierProvider<HealthController>((ref) {
  return HealthController(ref.watch(apiServiceProvider));
});

final backendHealthProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(apiServiceProvider).healthCheck();
});
