import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gap_radar/main.dart';
import 'package:gap_radar/screens/login_screen.dart';

void main() {
  testWidgets('SmartPrep App renders LoginScreen by default', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SmartPrepApp(),
      ),
    );

    // Initial pump & settle
    await tester.pumpAndSettle();

    // Verify Brand title & Login UI components
    expect(find.text('Smart Prep'), findsOneWidget);
    expect(find.text('RADAR ACCESS CONSOLE'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('LoginScreen form validation triggers on empty submit', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap "Log in" button directly without inputs
    final loginButton = find.widgetWithText(ElevatedButton, 'Log in');
    expect(loginButton, findsOneWidget);

    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    // Verify validation errors appear
    expect(find.text('Username is required'), findsOneWidget);
  });
}
