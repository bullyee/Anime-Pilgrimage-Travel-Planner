import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/utils/fractional_index.dart';

void main() {
  group('FractionalIndexUtil', () {
    test('generateKeyBetween with nulls returns valid initial key', () {
      final key = FractionalIndexUtil.generateKeyBetween(null, null);
      expect(key, isNotEmpty);
      expect(key, equals('a0'));
    });

    test('sequential appends maintain strictly increasing order', () {
      final keys = <String>[];
      for (int i = 0; i < 20; i++) {
        final nextKey = FractionalIndexUtil.append(keys);
        if (keys.isNotEmpty) {
          expect(nextKey.compareTo(keys.last), greaterThan(0));
        }
        keys.add(nextKey);
      }

      final sorted = List<String>.from(keys)..sort();
      expect(keys, equals(sorted));
    });

    test('sequential prepends maintain strictly increasing order in list', () {
      final keys = <String>[];
      for (int i = 0; i < 20; i++) {
        final prevKey = FractionalIndexUtil.prepend(keys);
        if (keys.isNotEmpty) {
          expect(prevKey.compareTo(keys.first), lessThan(0));
        }
        keys.insert(0, prevKey);
      }

      final sorted = List<String>.from(keys)..sort();
      expect(keys, equals(sorted));
    });

    test('insertAt inserts between existing keys correctly', () {
      final keys = <String>['a0', 'a2'];
      final midKey = FractionalIndexUtil.insertAt(keys, 1);

      expect(midKey.compareTo('a0'), greaterThan(0));
      expect(midKey.compareTo('a2'), lessThan(0));

      keys.insert(1, midKey);
      final sorted = List<String>.from(keys)..sort();
      expect(keys, equals(sorted));
    });

    test('repeated binary subdivision between adjacent keys preserves ordering', () {
      String first = 'a0';
      String second = 'a1';
      final inserted = <String>[first, second];

      // Insert 30 times between the two closest elements
      for (int i = 0; i < 30; i++) {
        final mid = FractionalIndexUtil.generateKeyBetween(first, second);
        expect(mid.compareTo(first), greaterThan(0));
        expect(mid.compareTo(second), lessThan(0));

        inserted.add(mid);
        inserted.sort();

        // Narrow interval to mid and second
        first = mid;
      }

      final sorted = List<String>.from(inserted)..sort();
      expect(inserted, equals(sorted));
      // Ensure no duplicates were generated
      expect(inserted.toSet().length, equals(inserted.length));
    });

    test('generateNKeysBetween generates n sorted keys', () {
      final keys = FractionalIndexUtil.generateNKeysBetween(null, null, 5);
      expect(keys.length, equals(5));

      for (int i = 1; i < keys.length; i++) {
        expect(keys[i].compareTo(keys[i - 1]), greaterThan(0));
      }

      // Between two keys
      final subKeys = FractionalIndexUtil.generateNKeysBetween(keys[1], keys[2], 3);
      expect(subKeys.length, equals(3));
      expect(subKeys.first.compareTo(keys[1]), greaterThan(0));
      expect(subKeys.last.compareTo(keys[2]), lessThan(0));

      for (int i = 1; i < subKeys.length; i++) {
        expect(subKeys[i].compareTo(subKeys[i - 1]), greaterThan(0));
      }
    });
  });
}

