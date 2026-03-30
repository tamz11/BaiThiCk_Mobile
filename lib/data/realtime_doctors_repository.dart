import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class RealtimeDoctorsRepository {
  RealtimeDoctorsRepository._();

  static const String _databaseUrl = 'https://noteapp-5ea9b-default-rtdb.asia-southeast1.firebasedatabase.app/';

  static FirebaseDatabase get _db =>
      FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: _databaseUrl);

  static DatabaseReference get _ref => _db.ref();

  static Stream<List<Map<String, dynamic>>> streamDoctors() {
    return _ref.onValue.map(_mapDoctorsFromEvent);
  }

  // API-like one-shot fetch.
  static Future<List<Map<String, dynamic>>> fetchDoctors() async {
    final snapshot = await _ref.get();
    return _mapDoctorsFromSnapshot(snapshot);
  }

  static Future<List<Map<String, dynamic>>> searchDoctors(String keyword) async {
    final key = keyword.trim().toLowerCase();
    final all = await fetchDoctors();
    if (key.isEmpty) return all;
    return all.where((d) {
      final name = (d['name'] ?? '').toString().toLowerCase();
      return name.contains(key);
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchDoctorsByType(String type) async {
    final t = type.trim().toLowerCase();
    final all = await fetchDoctors();
    if (t.isEmpty) return all;
    return all.where((d) {
      final doctorType = (d['type'] ?? '').toString().trim().toLowerCase();
      return doctorType == t;
    }).toList();
  }

  static Future<Map<String, dynamic>?> fetchDoctorByExactName(String name) async {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return null;
    final all = await fetchDoctors();
    for (final doctor in all) {
      final doctorName = (doctor['name'] ?? '').toString().trim().toLowerCase();
      if (doctorName == key) return doctor;
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> fetchTopRatedDoctors([int limit = 5]) async {
    final all = await fetchDoctors();
    all.sort((a, b) {
      final ar = (a['rating'] is num) ? (a['rating'] as num).toDouble() : 0;
      final br = (b['rating'] is num) ? (b['rating'] as num).toDouble() : 0;
      return br.compareTo(ar);
    });
    final safeLimit = limit < 1 ? 1 : limit;
    return all.take(safeLimit).toList();
  }

  static List<Map<String, dynamic>> _mapDoctorsFromEvent(DatabaseEvent event) {
    return _mapDoctorsFromRawValue(event.snapshot.value);
  }

  static List<Map<String, dynamic>> _mapDoctorsFromSnapshot(DataSnapshot snapshot) {
    return _mapDoctorsFromRawValue(snapshot.value);
  }

  static List<Map<String, dynamic>> _mapDoctorsFromRawValue(Object? value) {

    if (value is Map) {
      return value.entries
          .where((entry) => entry.value is Map)
          .map((entry) {
            final item = Map<String, dynamic>.from(entry.value as Map);
            item['id'] = entry.key.toString();
            return item;
          })
          .toList();
    }

    if (value is List) {
      final result = <Map<String, dynamic>>[];
      for (var i = 0; i < value.length; i++) {
        final row = value[i];
        if (row is Map) {
          final item = Map<String, dynamic>.from(row);
          item['id'] = i.toString();
          result.add(item);
        }
      }
      return result;
    }

    return const [];
  }
}
