import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/features/sync/services/firestore_sync_v2_service.dart';

void main() {
  group('withDocumentId', () {
    test('the document path wins over a spoofed id field', () {
      // An editor of trip_T sets its `id` field to another trip's ID.
      final out = withDocumentId('trip_T', {'id': 'victim_trip_X', 'title': 'Hijack'});
      expect(out['id'], 'trip_T');
      expect(out['title'], 'Hijack');
    });

    test('fills in a missing id and replaces non-string ids', () {
      expect(withDocumentId('trip_A', {'title': 'x'})['id'], 'trip_A');
      expect(withDocumentId('trip_B', {'id': 123})['id'], 'trip_B');
      expect(withDocumentId('trip_C', {'id': null})['id'], 'trip_C');
    });

    test('does not mutate the source map', () {
      final src = <String, dynamic>{'id': 'spoof'};
      withDocumentId('real', src);
      expect(src['id'], 'spoof');
    });

    test('keeps unicode and long ids exactly as Firestore reports them', () {
      const id = '旅行_🚃_x';
      expect(withDocumentId(id, {})['id'], id);
    });
  });
}
