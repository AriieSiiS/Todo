import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import 'local_store.dart';

class SharedPreferencesLocalStore implements LocalStore {
  static const String _snapshotKey = 'todo.snapshot.v1';
  static const String _calendarSessionKey = 'todo.calendar.session.v1';

  @override
  Future<AppStateSnapshot?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_snapshotKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return AppStateSnapshot.fromEncodedJson(raw);
  }

  @override
  Future<void> save(AppStateSnapshot snapshot) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_snapshotKey, snapshot.toEncodedJson());
  }

  @override
  Future<String?> loadCalendarSession() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_calendarSessionKey);
  }

  @override
  Future<void> saveCalendarSession(String encodedSession) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_calendarSessionKey, encodedSession);
  }

  @override
  Future<void> clearCalendarSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_calendarSessionKey);
  }
}

LocalStore createLocalStore() => SharedPreferencesLocalStore();
