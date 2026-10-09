// SDK references are mocked only to control asynchronous completion in tests.
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_guard/features/auth/services/auth_service.dart';

class TestUser implements User {
  @override
  final String uid;
  TestUser(this.uid);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestAuth implements FirebaseAuth {
  @override
  User? currentUser = TestUser('old');
  var signOutCalls = 0;
  @override
  Future<void> signOut() async {
    signOutCalls++;
    currentUser = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic> value;
  TestSnapshot(this.value);
  @override
  bool get exists => true;
  @override
  Map<String, dynamic> data() => value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestDocument implements DocumentReference<Map<String, dynamic>> {
  final Completer<DocumentSnapshot<Map<String, dynamic>>> pending;
  TestDocument(this.pending);
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) {
    expect(options?.source, Source.server);
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestCollection implements CollectionReference<Map<String, dynamic>> {
  final TestDocument document;
  TestCollection(this.document);
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    expect(path, 'old');
    return document;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestFirestore implements FirebaseFirestore {
  final TestCollection users;
  TestFirestore(this.users);
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) => users;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestFunctions implements FirebaseFunctions {
  final Completer<Map<String, dynamic>>? pending;
  TestFunctions([this.pending]);
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      TestCallable(pending!);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestCallable implements HttpsCallable {
  final Completer<Map<String, dynamic>> pending;
  TestCallable(this.pending);
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    expect(parameters['expectedUid'], 'old');
    return TestResult<T>(await pending.future as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestResult<T> implements HttpsCallableResult<T> {
  @override
  final T data;
  TestResult(this.data);
}

void main() {
  for (final action in ['create', 'join', 'rotate']) {
    test('late $action result is discarded after account switch', () async {
      final auth = TestAuth();
      final pending = Completer<Map<String, dynamic>>();
      final docs = Completer<DocumentSnapshot<Map<String, dynamic>>>();
      final service = AuthService(
        auth: auth,
        firestore: TestFirestore(TestCollection(TestDocument(docs))),
        functions: TestFunctions(pending),
      );
      final Future<Object> operation = switch (action) {
        'create' => service.createCircle(circleName: 'Family'),
        'join' => service.joinCircleByCode(inviteCode: 'CODE'),
        _ => service.rotateCircleInvites('circle'),
      };
      final rejected = expectLater(operation, throwsStateError);
      auth.currentUser = TestUser('new');
      pending.complete({});
      await rejected;
      expect(auth.currentUser?.uid, 'new');
      expect(docs.isCompleted, false);
    });
  }
  for (final deleted in [false, true]) {
    test(
      'late ${deleted ? "deleted" : "normal"} profile cannot affect a new account',
      () async {
        final auth = TestAuth();
        final pending = Completer<DocumentSnapshot<Map<String, dynamic>>>();
        final service = AuthService(
          auth: auth,
          firestore: TestFirestore(TestCollection(TestDocument(pending))),
          functions: TestFunctions(),
        );
        final load = service.loadCurrentAccount();
        final rejected = expectLater(load, throwsStateError);
        auth.currentUser = TestUser('new');
        pending.complete(TestSnapshot({'deletionRequested': deleted}));
        await rejected;
        expect(auth.currentUser?.uid, 'new');
        expect(auth.signOutCalls, 0);
      },
    );
  }
}
