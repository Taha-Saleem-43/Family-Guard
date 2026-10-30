import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:family_guard/core/services/support_links.dart';
import 'package:family_guard/core/presentation/privacy_support_links.dart';

void main() {
  test(
    'support URLs use public policy pages and the owner-provided contact',
    () async {
      final calls = <Uri>[];
      for (final destination in SupportDestination.values) {
        expect(
          await SupportLinks.open(
            destination,
            launcher: (uri, mode) async {
              expect(mode, LaunchMode.externalApplication);
              calls.add(uri);
              return true;
            },
          ),
          isTrue,
        );
      }
      expect(calls[0].scheme, 'https');
      expect(calls[0].path, '/privacy/');
      expect(calls[1].path, '/delete-account/');
      expect(calls[2].scheme, 'mailto');
      expect(calls[2].path, 'tahasaleemdev@gmail.com');
      expect(
        await SupportLinks.open(
          SupportDestination.privacy,
          launcher: (_, _) async => false,
        ),
        isFalse,
      );
      expect(
        await SupportLinks.open(
          SupportDestination.privacy,
          launcher: (_, _) async => throw StateError('No browser'),
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'public links wrap at large text and failures provide a retry message',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: PrivacySupportLinks(launcher: (_, _) async => false),
          ),
        ),
      );
      await tester.tap(find.text('Privacy policy'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not open the page'), findsOneWidget);
      expect(find.text('Account deletion'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a failed email launch shows the address and disposal is safe', (
    tester,
  ) async {
    final pending = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrivacySupportLinks(launcher: (_, _) => pending.future),
        ),
      ),
    );
    await tester.tap(find.text('Contact support'));
    await tester.pumpWidget(const SizedBox());
    pending.complete(false);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrivacySupportLinks(launcher: (_, _) async => false),
        ),
      ),
    );
    await tester.tap(find.text('Contact support'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tahasaleemdev@gmail.com'), findsOneWidget);
  });
}
