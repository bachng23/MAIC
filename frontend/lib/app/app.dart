import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_sync_listener.dart';
import 'router.dart';

class MediAgentApp extends ConsumerWidget {
  const MediAgentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return NotificationSyncListener(
      child: MaterialApp.router(
        title: 'MediAgent',
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Lexend',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0066CC),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        ),
      ),
    );
  }
}
