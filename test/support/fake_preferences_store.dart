import 'package:doctylia_app/core/storage/preferences_store.dart';

final class FakePreferencesStore implements PreferencesStore {
  FakePreferencesStore([Map<String, Object>? initialValues])
    : values = {...?initialValues};

  final Map<String, Object> values;

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;

  @override
  Future<void> setString(String key, String value) async => values[key] = value;
}
