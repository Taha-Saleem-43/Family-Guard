class CircleRoster {
  static List<String> memberIds(Map<String, dynamic>? data, String currentUid) {
    if (data == null) return const [];
    final raw = data['memberIds'];
    if (raw is! List ||
        raw.length > 20 ||
        raw.any(
          (id) =>
              id is! String ||
              id.isEmpty ||
              id.length > 128 ||
              id.contains('/'),
        )) {
      throw StateError(
        'Circle membership is invalid or exceeds twenty members.',
      );
    }
    final ids = raw.cast<String>().toSet().toList()..sort();
    return ids.contains(currentUid) ? ids : const [];
  }
}
