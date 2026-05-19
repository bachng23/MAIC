import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/di/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  await container.read(medicationNotificationServiceProvider).initialize();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MediAgentApp(),
    ),
  );
}
