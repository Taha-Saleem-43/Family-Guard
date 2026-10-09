import 'package:flutter_test/flutter_test.dart';
import 'package:family_guard/core/models/circle_roster.dart';

void main() {
  test(
    'removed requesters cannot derive a profile query from stale circle data',
    () {
      expect(
        CircleRoster.memberIds({
          'memberIds': ['parent', 'child'],
        }, 'removed'),
        isEmpty,
      );
      expect(CircleRoster.memberIds(null, 'parent'), isEmpty);
    },
  );
  test('rosters are bounded, typed and safe to use as document IDs', () {
    expect(
      CircleRoster.memberIds({
        'memberIds': ['parent', 'child', 'child'],
      }, 'parent'),
      ['child', 'parent'],
    );
    for (final ids in [
      null,
      'parent',
      ['parent', null],
      ['parent', 'other/child'],
      ['parent', ...List.generate(20, (i) => 'child-$i')],
    ]) {
      expect(
        () => CircleRoster.memberIds({'memberIds': ids}, 'parent'),
        throwsStateError,
      );
    }
  });
}
