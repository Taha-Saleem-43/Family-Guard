// ignore_for_file: subtype_of_sealed_class
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_guard/features/auth/services/auth_service.dart';
import 'auth_session_boundaries_test.dart'
    show TestFirestore, TestCollection, TestDocument, TestFunctions;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class ResetAuth implements FirebaseAuth {
  String? address;
  String? failure;
  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    address = email;
    if (failure != null) throw FirebaseAuthException(code: failure!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'reset trims address, rejects invalid input, hides missing users and propagates network failures',
    () async {
      final auth = ResetAuth();
      final service = AuthService(
        auth: auth,
        firestore: TestFirestore(
          TestCollection(
            TestDocument(Completer<DocumentSnapshot<Map<String, dynamic>>>()),
          ),
        ),
        functions: TestFunctions(),
      );
      await expectLater(
        service.sendPasswordReset('invalid'),
        throwsArgumentError,
      );
      expect(auth.address, isNull);
      await service.sendPasswordReset(' user@example.com ');
      expect(auth.address, 'user@example.com');
      auth.failure = 'user-not-found';
      await service.sendPasswordReset('unknown@example.com');
      auth.failure = 'network-request-failed';
      await expectLater(
        service.sendPasswordReset('user@example.com'),
        throwsA(isA<FirebaseAuthException>()),
      );
    },
  );
}
