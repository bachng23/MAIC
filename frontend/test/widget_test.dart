import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/app.dart';

void main() {
  testWidgets('MediAgentApp renders without crashing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MediAgentApp()),
    );
    // App renders the router scaffold — just verify no exceptions thrown.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
