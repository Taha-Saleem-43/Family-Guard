import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_guard/features/sos/services/sos_service.dart';
import 'package:family_guard/features/sos/services/sos_request_store.dart';

class CleanupFailureStore implements SOSRequestStore {
  @override
  Future<String> getOrCreate(String uid, String circleId) async => 'a' * 32;
  @override
  Future<void> clear(String uid, String circleId) async =>
      throw StateError('disk failure');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'request IDs survive service recreation and stay scoped to account/circle',
    () async {
      final first = await PreferencesSOSRequestStore().getOrCreate(
        'user',
        'circle',
      );
      expect(first, matches(RegExp(r'^[a-f0-9]{32}$')));
      expect(
        await PreferencesSOSRequestStore().getOrCreate('user', 'circle'),
        first,
      );
      expect(
        await PreferencesSOSRequestStore().getOrCreate('other', 'circle'),
        isNot(first),
      );
      expect(
        await PreferencesSOSRequestStore().getOrCreate('user', 'other'),
        isNot(first),
      );
      await PreferencesSOSRequestStore().clear('user', 'circle');
      expect(
        await PreferencesSOSRequestStore().getOrCreate('user', 'circle'),
        isNot(first),
      );
    },
  );

  test(
    'ambiguous timeout retry sends the same ID after process-style recreation',
    () async {
      final ids = <String>[];
      Future<Map<String, dynamic>> call(
        String name,
        Map<String, dynamic> data,
      ) async {
        expect(name, 'triggerSos');
        expect(data.containsKey('senderId'), isFalse);
        expect(data.containsKey('senderName'), isFalse);
        ids.add(data['requestId'] as String);
        if (ids.length == 1) {
          throw TimeoutException('Response lost after commit');
        }
        return {'status': 'active', 'alertId': 'confirmed'};
      }

      final failed = SOSService(callable: call);
      expect(
        await failed.triggerSOS(
          circleId: 'circle',
          userId: 'user',
          userName: 'Name',
        ),
        isNull,
      );
      final retry = SOSService(callable: call);
      expect(
        await retry.triggerSOS(
          circleId: 'circle',
          userId: 'user',
          userName: 'Name',
        ),
        'confirmed',
      );
      expect(ids[0], ids[1]);
    },
  );

  test(
    'resolved old key starts one new request only on deliberate send',
    () async {
      final ids = <String>[];
      final service = SOSService(
        callable: (name, data) async {
          ids.add(data['requestId'] as String);
          return ids.length == 1
              ? {'status': 'resolved', 'alertId': 'old'}
              : {'status': 'active', 'alertId': 'new'};
        },
      );
      expect(
        await service.triggerSOS(
          circleId: 'circle',
          userId: 'user',
          userName: 'Name',
        ),
        'new',
      );
      expect(ids, hasLength(2));
      expect(ids[0], isNot(ids[1]));
    },
  );

  test(
    'failed resolution retains retry key; confirmed resolution clears it',
    () async {
      final store = PreferencesSOSRequestStore();
      final id = await store.getOrCreate('user', 'circle');
      var succeeds = false;
      final service = SOSService(
        requests: store,
        callable: (name, data) async {
          if (!succeeds) throw TimeoutException('Response lost');
          return {'resolved': true, 'alertId': data['alertId']};
        },
      );
      expect(
        await service.resolveSOS(
          alertId: 'alert',
          userId: 'user',
          circleId: 'circle',
        ),
        isFalse,
      );
      expect(await store.getOrCreate('user', 'circle'), id);
      succeeds = true;
      expect(
        await service.resolveSOS(
          alertId: 'alert',
          userId: 'user',
          circleId: 'circle',
        ),
        isTrue,
      );
      expect(await store.getOrCreate('user', 'circle'), isNot(id));
    },
  );

  test(
    'local cleanup failure cannot undo confirmed server resolution',
    () async {
      final service = SOSService(
        requests: CleanupFailureStore(),
        callable: (name, data) async => {
          'resolved': true,
          'alertId': data['alertId'],
        },
      );
      expect(
        await service.resolveSOS(
          alertId: 'alert',
          userId: 'user',
          circleId: 'circle',
        ),
        isTrue,
      );
    },
  );
}
