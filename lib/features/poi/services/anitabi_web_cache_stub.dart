abstract class AnitabiWebCache {
  static Future<String?> get(String key) async => null;
  static Future<void> put(String key, String value, DateTime timestamp) async {}
  static Future<DateTime?> timestamp(String key) async => null;
}
