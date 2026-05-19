import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/app.dart';

void main() {
  testWidgets('MediAgentApp mounts', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MediAgentApp()),
    );

    expect(find.byType(MediAgentApp), findsOneWidget);
  });
}
