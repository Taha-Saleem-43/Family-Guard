import 'dart:async';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/push_envelope.dart';
import '../providers/push_coordinator.dart';
import 'push_registration_store.dart';

final pushCoordinatorProvider =
    StateNotifierProvider<PushCoordinator, PushState>((ref) {
      final runtime = PushRuntime();
      PushRuntime.active = runtime;
      ref.onDispose(runtime.dispose);
      return runtime.coordinator;
    });

class PushRuntime {
  static PushRuntime? active;
  late final PushCoordinator coordinator;
  final _store = PushRegistrationStore();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Future<void> _ready = Future.value();
  bool _started = false;
  Future<void>? _accountSetup;
  String? _accountSetupUid;
  PushRuntime() {
    coordinator = PushCoordinator(
      permission: () async {
        final settings = await FirebaseMessaging.instance
            .getNotificationSettings();
        return settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      },
      token: () async {
        await _ready;
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return null;
        await _prepareTokenAccount(uid);
        if (FirebaseAuth.instance.currentUser?.uid != uid) {
          throw StateError('Account changed');
        }
        return FirebaseMessaging.instance.getToken();
      },
      nextRegistration: _store.next,
      register: (session, revision, token) async {
        final result = await _call('registerPushDevice', {
          'expectedUid': session.uid,
          'installationSecret': revision.secret,
          'installationId': revision.installationId,
          'version': revision.version,
          'token': token,
          'platform': Platform.isAndroid ? 'android' : 'ios',
        });
        if (result['registered'] != true ||
            result['version'] != revision.version) {
          throw StateError('Registration not confirmed');
        }
      },
      unregister: (session, revision) async {
        await _call('unregisterPushDevice', {
          'expectedUid': session.uid,
          'installationSecret': revision.secret,
          'installationId': revision.installationId,
          'version': revision.version,
        });
      },
      deleteToken: () => FirebaseMessaging.instance.deleteToken(),
      currentUid: () =>
          Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser?.uid,
    );
  }

  Future<void> _prepareTokenAccount(String uid) {
    if (_accountSetupUid == uid && _accountSetup != null) return _accountSetup!;
    final previous = _accountSetup ?? Future<void>.value();
    final work = previous.catchError((Object _) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('fg_push_token_account_uid') == uid) return;
      await FirebaseMessaging.instance.deleteToken().timeout(
        const Duration(seconds: 15),
      );
      if (FirebaseAuth.instance.currentUser?.uid != uid) {
        throw StateError('Account changed');
      }
      if (!await prefs.setString('fg_push_token_account_uid', uid)) {
        throw StateError('Device account could not be saved');
      }
    });
    _accountSetupUid = uid;
    _accountSetup = work;
    work.catchError((Object _) {
      if (identical(_accountSetup, work)) {
        _accountSetup = null;
      }
    });
    return work;
  }

  static Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable(
          name,
          options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
        )
        .call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> start(void Function(PushEnvelope) onOpened) async {
    if (_started || Firebase.apps.isEmpty) return;
    _started = true;
    active = this;
    _subscriptions.add(
      FirebaseMessaging.instance.onTokenRefresh.listen((_) {
        unawaited(coordinator.refresh());
      }),
    );
    _subscriptions.add(
      FirebaseMessaging.onMessage.listen((message) {
        final envelope = PushEnvelope.parse(message.data);
        if (envelope != null) {
          unawaited(
            acknowledge(envelope, 'received').catchError((Object _) => false),
          );
        }
        // Foreground emergency presentation comes from confirmed Firestore state.
      }),
    );
    _subscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        final envelope = PushEnvelope.parse(message.data);
        if (envelope != null) onOpened(envelope);
      }),
    );
    _ready = _initialize();
    try {
      await _ready;
      final message = await FirebaseMessaging.instance.getInitialMessage();
      if (message != null) {
        final envelope = PushEnvelope.parse(message.data);
        if (envelope != null) onOpened(envelope);
      }
    } catch (_) {
      /* Registration exposes initialization failure and permits retry. */
    }
  }

  Future<void> _initialize() async {
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'family_guard_activity',
            'Place activity',
            description: 'Arrival and departure activity in your family circle',
            importance: Importance.defaultImportance,
          ),
        );
    final notifications = FlutterLocalNotificationsPlugin();
    await notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'family_guard_sos',
            'Family emergencies',
            description: 'Emergency notifications from your family circle',
            importance: Importance.high,
          ),
        );
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );
  }

  Future<void> retry() async {
    _ready = _initialize();
    try {
      await _ready;
    } catch (_) {}
    await coordinator.refresh();
  }

  static Future<bool> acknowledge(PushEnvelope envelope, String kind) async {
    if (Firebase.apps.isEmpty ||
        FirebaseAuth.instance.currentUser?.uid != envelope.recipientUid) {
      return false;
    }
    final result = await _call(
      envelope.type == 'place' ? 'acknowledgePlacePush' : 'acknowledgeSosPush',
      envelope.acknowledgement(kind),
    );
    return result['acknowledged'] == true &&
        result['active'] == true &&
        result['circleId'] == envelope.circleId;
  }

  void dispose() {
    if (identical(active, this)) active = null;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
  }
}
