import 'dart:async';
import 'package:family_guard/core/services/latest_value_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a slow upload keeps only the newest waiting fix and shares its result',
    () async {
      final gate = Completer<void>();
      final processed = <int>[];
      final queue = LatestValueQueue<int>((value) async {
        processed.add(value);
        if (value == 0) await gate.future;
      });
      final first = queue.submit(0);
      final pending = queue.submit(1);
      for (var fix = 2; fix <= 500; fix++) {
        expect(identical(queue.submit(fix), pending), true);
      }
      expect(processed, [0]);
      gate.complete();
      await Future.wait([first, pending]);
      expect(processed, [0, 500]);
      await queue.submit(501);
      expect(processed, [0, 500, 501]);
    },
  );
  test(
    'a failed in-flight upload does not block the newest pending fix',
    () async {
      final gate = Completer<void>();
      final processed = <String>[];
      final queue = LatestValueQueue<String>((value) async {
        processed.add(value);
        if (value == 'old') {
          await gate.future;
          throw StateError('network failed');
        }
      });
      final failure = expectLater(queue.submit('old'), throwsStateError);
      final pending = queue.submit('new');
      gate.complete();
      await failure;
      await pending;
      expect(processed, ['old', 'new']);
    },
  );
}
