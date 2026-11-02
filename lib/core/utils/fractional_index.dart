import 'package:fractional_indexing_dart/fractional_indexing_dart.dart';

/// Utility class for generating and managing fractional index keys (`sort_key`).
///
/// Fractional indexing allows items to be inserted or reordered in a sequence
/// without mutating the keys of neighboring items, making it ideal for
/// concurrent editing and CRDT-friendly list operations in shared trips.
class FractionalIndexUtil {
  const FractionalIndexUtil._();

  /// Generates a single sort key strictly between [prev] and [next].
  ///
  /// - If both [prev] and [next] are null, generates the initial key (e.g. "a0").
  /// - If [prev] is null, generates a key before [next].
  /// - If [next] is null, generates a key after [prev].
  /// - If both are provided, generates a midpoint key strictly between them.
  static String generateKeyBetween(String? prev, String? next) {
    return FractionalIndexing.generateKeyBetween(prev, next);
  }

  /// Generates [n] consecutive sort keys strictly between [prev] and [next].
  static List<String> generateNKeysBetween(String? prev, String? next, int n) {
    if (n <= 0) return const [];
    return FractionalIndexing.generateNKeysBetween(prev, next, n);
  }

  /// Appends a new key after the last key in [existingKeys].
  ///
  /// Assumes [existingKeys] are sorted in ascending lexicographical order.
  static String append(List<String> existingKeys) {
    if (existingKeys.isEmpty) {
      return generateKeyBetween(null, null);
    }
    return generateKeyBetween(existingKeys.last, null);
  }

  /// Prepends a new key before the first key in [existingKeys].
  ///
  /// Assumes [existingKeys] are sorted in ascending lexicographical order.
  static String prepend(List<String> existingKeys) {
    if (existingKeys.isEmpty) {
      return generateKeyBetween(null, null);
    }
    return generateKeyBetween(null, existingKeys.first);
  }

  /// Inserts a new key at [index] in [existingKeys].
  ///
  /// Assumes [existingKeys] are sorted in ascending lexicographical order.
  static String insertAt(List<String> existingKeys, int index) {
    if (existingKeys.isEmpty || index <= 0) {
      return prepend(existingKeys);
    }
    if (index >= existingKeys.length) {
      return append(existingKeys);
    }
    return generateKeyBetween(existingKeys[index - 1], existingKeys[index]);
  }
}

