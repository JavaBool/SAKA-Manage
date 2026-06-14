// import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:client_flutter/main.dart';

void main() {
  testWidgets('App launches and shows Login Screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: SAKAManageApp(),
      ),
    );

    // Verify that the login text or buttons are present.
    expect(find.text('SAKA Manage'), findsOneWidget);
    expect(find.text('Customer Feedback Reporting'), findsOneWidget);
  });
}
