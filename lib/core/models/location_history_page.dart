import 'location_history_point.dart';

class HistoryCursor {
  final DateTime timestamp;
  final String documentId;
  const HistoryCursor(this.timestamp, this.documentId);
}

class LocationHistoryPage {
  final List<LocationHistoryPoint> points;
  final HistoryCursor? nextCursor;
  const LocationHistoryPage({this.points = const [], this.nextCursor});
  bool get hasMore => nextCursor != null;
}
