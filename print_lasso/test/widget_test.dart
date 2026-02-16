import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';

import 'package:print_lasso/features/home/home.dart';

void main() {
  testWidgets('Shows service discovery controls', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      const MaterialApp(home: HomePage(autoInitialize: false)),
    );

    expect(find.text('Service Connection'), findsOneWidget);
    expect(find.text('Find Local Service'), findsOneWidget);
    expect(find.text('Connect Manually'), findsOneWidget);
  });
}
