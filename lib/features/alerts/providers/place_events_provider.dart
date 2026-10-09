import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/alert_event.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/theme/app_colors.dart';

final circlePlaceEventsProvider = StreamProvider.autoDispose<List<AlertEvent>>((
  ref,
) {
  final circle = ref.watch(appStateProvider.select((state) => state.circleId));
  final uid = ref.watch(appStateProvider.select((state) => state.userId));
  final role = ref.watch(appStateProvider.select((state) => state.role));
  if (Firebase.apps.isEmpty || circle.isEmpty || uid.isEmpty) {
    return Stream.value([]);
  }
  Query<Map<String, dynamic>> query = FirebaseFirestore.instance
      .collection('placeEvents')
      .where('circleId', isEqualTo: circle);
  if (role != UserRole.parent) query = query.where('memberId', isEqualTo: uid);
  return query
      .orderBy('timestamp', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) {
        final events = <AlertEvent>[];
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final timestamp = data['timestamp'];
          if (timestamp is! Timestamp ||
              data['memberId'] is! String ||
              data['memberName'] is! String ||
              data['placeName'] is! String ||
              !['arrive', 'leave'].contains(data['type'])) {
            continue;
          }
          events.add(
            AlertEvent(
              id: doc.id,
              memberId: data['memberId'],
              memberName: data['memberName'],
              memberColor: AppColors.teal,
              placeName: data['placeName'],
              type: data['type'] == 'arrive'
                  ? AlertEventType.arrive
                  : AlertEventType.leave,
              timestamp: timestamp.toDate(),
            ),
          );
        }
        return events;
      });
});
