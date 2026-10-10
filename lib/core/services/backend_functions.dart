import 'package:cloud_functions/cloud_functions.dart';

/// Keep Firebase's callable envelope, Auth token and App Check handling while
/// running trusted operations on the free Workers backend.
class BackendFunctions {
  static const baseUrl = String.fromEnvironment(
    'FAMILY_GUARD_API_URL',
    defaultValue: 'https://family-guard-api.tahasaleem981.workers.dev',
  );

  static HttpsCallable callable(
    String name, {
    FirebaseFunctions? functions,
    HttpsCallableOptions? options,
  }) {
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9]*$').hasMatch(name)) {
      throw ArgumentError.value(name, 'name', 'Invalid backend operation');
    }
    final base = Uri.parse(baseUrl);
    if (base.scheme != 'https' ||
        base.host.isEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        base.userInfo.isNotEmpty) {
      throw StateError('The backend requires a secure HTTPS endpoint.');
    }
    return (functions ?? FirebaseFunctions.instance).httpsCallableFromUri(
      base.replace(path: '${base.path.replaceAll(RegExp(r"/+$"), "")}/$name'),
      options: options,
    );
  }
}
