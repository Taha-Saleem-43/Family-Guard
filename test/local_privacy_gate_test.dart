import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_guard/core/presentation/local_privacy_gate.dart';
import 'package:family_guard/core/services/firestore_privacy_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'migration clears old caches once and configures memory on every launch',
    () async {
      SharedPreferences.setMockInitialValues({});
      final calls = <String>[];
      final migration = FirestoreCacheMigration(
        configure: () => calls.add('memory'),
        clear: () async => calls.add('clear'),
      );
      await migration.prepare();
      await migration.prepare();
      expect(calls, ['memory', 'clear', 'memory']);
    },
  );
  test(
    'failed cache migration is retried rather than marked complete',
    () async {
      SharedPreferences.setMockInitialValues({});
      var attempts = 0;
      final migration = FirestoreCacheMigration(
        configure: () {},
        clear: () async {
          if (++attempts == 1) throw StateError('busy');
        },
      );
      await expectLater(migration.prepare(), throwsStateError);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(FirestoreCacheMigration.migrationKey), isNull);
      await migration.prepare();
      expect(attempts, 2);
    },
  );
  testWidgets('account UI mounts only after cache cleanup succeeds', (
    tester,
  ) async {
    final cleanup = Completer<void>();
    await tester.pumpWidget(
      LocalPrivacyGate(
        prepare: () => cleanup.future,
        child: const MaterialApp(home: Text('Account screen')),
      ),
    );
    expect(find.text('Account screen'), findsNothing);
    cleanup.complete();
    await tester.pumpAndSettle();
    expect(find.text('Account screen'), findsOneWidget);
  });
  testWidgets('failed cleanup blocks account UI and permits retry', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      LocalPrivacyGate(
        prepare: () async {
          if (++calls == 1) throw StateError('native cache busy');
        },
        child: const MaterialApp(home: Text('Account screen')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Account screen'), findsNothing);
    expect(find.text('Retry cleanup'), findsOneWidget);
    await tester.tap(find.text('Retry cleanup'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Account screen'), findsOneWidget);
  });
}
