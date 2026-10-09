import 'dart:async';
import 'package:family_guard/features/sos/services/sos_dismissal_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'successive writes across provider recreation cannot overwrite newer dismissals',
    () async {
      final firstGate = Completer<void>();
      final started = <List<String>>[];
      Future<bool> write(String key, List<String> ids) async {
        started.add(ids);
        if (started.length == 1) await firstGate.future;
        final prefs = await SharedPreferences.getInstance();
        return prefs.setStringList(key, ids);
      }

      final first = PreferencesSOSDismissalStore(write: write);
      final second = PreferencesSOSDismissalStore(write: write);
      final old = first.save('uid', 'circle', {'one'});
      final ids = {'one', 'two'};
      final newer = second.save('uid', 'circle', ids);
      ids.clear(); // Saving captures the caller's state immediately.
      var loaded = false;
      final restoration = PreferencesSOSDismissalStore()
          .load('uid', 'circle')
          .then((value) {
            loaded = true;
            return value;
          });
      await Future<void>.delayed(Duration.zero);
      expect(started, [
        ['one'],
      ]);
      expect(loaded, true); // Restoration must not wait for a slow disk write.
      expect(await restoration, {'one', 'two'});
      firstGate.complete();
      await Future.wait([old, newer]);
      expect(await restoration, {'one', 'two'});
      expect(await first.load('other', 'circle'), isEmpty);
    },
  );
  test(
    'failed disk write does not prevent a later dismissal from being persisted',
    () async {
      final failing = PreferencesSOSDismissalStore(
        write: (_, _) async => false,
      );
      await expectLater(
        failing.save('uid', 'circle', {'old'}),
        throwsStateError,
      );
      final succeeding = PreferencesSOSDismissalStore();
      await succeeding.save('uid', 'circle', {'old', 'new'});
      expect(await succeeding.load('uid', 'circle'), {'old', 'new'});
    },
  );
  test(
    'bounded dismissal history preserves active emergencies before older resolved IDs',
    () {
      final ids = List.generate(150, (index) => 'alert-$index');
      final bounded = PreferencesSOSDismissalStore.bounded(
        ids,
        activeIds: {'alert-0', 'alert-1'},
      );
      expect(bounded.length, 100);
      expect(bounded, containsAll(['alert-0', 'alert-1', 'alert-149']));
      expect(bounded, isNot(contains('alert-2')));
    },
  );
}
