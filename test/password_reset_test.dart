import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_guard/features/auth/presentation/password_reset_screen.dart';

void main() {
  testWidgets('validates email, trims it, and prevents duplicate requests', (
    tester,
  ) async {
    final pending = Completer<void>();
    final requests = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PasswordResetScreen(
          sendReset: (email) {
            requests.add(email);
            return pending.future;
          },
        ),
      ),
    );
    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(requests, isEmpty);
    await tester.enterText(find.byType(TextFormField), ' user@example.com ');
    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    await tester.tap(find.text('Requesting reset…'));
    expect(requests, ['user@example.com']);
    pending.complete();
    await tester.pumpAndSettle();
    expect(
      find.textContaining('If an account uses this email'),
      findsOneWidget,
    );
    expect(find.text('Send reset link'), findsNothing);
  });

  testWidgets('network failure permits retry and works with large text', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: PasswordResetScreen(
          initialEmail: 'user@example.com',
          sendReset: (_) async {
            if (++calls == 1) {
              throw FirebaseAuthException(code: 'network-request-failed');
            }
          },
        ),
      ),
    );
    await tester.ensureVisible(find.text('Send reset link'));
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(
      find.text('Check your internet connection and try again.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completion after leaving screen is safe', (tester) async {
    final pending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: PasswordResetScreen(
          initialEmail: 'user@example.com',
          sendReset: (_) => pending.future,
        ),
      ),
    );
    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
