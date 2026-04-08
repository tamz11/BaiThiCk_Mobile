import 'dart:convert';

import 'package:http/http.dart' as http;

class RealtimeDoctorsRepository {
  RealtimeDoctorsRepository._();

  static const String _databaseUrl = 'https://baithick-default-rtdb.firebaseio.com/';
  static Uri get _restRoot => Uri.parse('$_databaseUrl.json');

  static Stream<List<Map<String, dynamic>>> streamDoctors() async* {
    yield await fetchDoctors();
    yield* Stream<List<Map<String, dynamic>>>.periodic(
      const Duration(seconds: 20),
      (_) => const <Map<String, dynamic>>[],
    ).asyncMap((_) => fetchDoctors());
  }

  // API-like one-shot fetch.
  static Future<List<Map<String, dynamic>>> fetchDoctors() async {
    final response = await http.get(_restRoot);
    if (response.statusCode >= 400) {
      throw StateError('Realtime doctors fetch failed: ${response.statusCode}');
    }
    final raw = jsonDecode(response.body);

    if (raw is Map && raw['error'] != null) {
      throw StateError('Realtime doctors fetch failed: ${raw['error']}');
    }

    return _mapDoctorsFromRawValue(raw);
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

  static Future<Map<String, dynamic>?> fetchDoctorById(String id) async {
    final key = id.trim().toLowerCase();
    if (key.isEmpty) return null;
    final all = await fetchDoctors();
    for (final doctor in all) {
      final doctorId = (doctor['id'] ?? '').toString().trim().toLowerCase();
      if (doctorId == key) return doctor;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> fetchDoctorByNameFlexible(String name) async {
    final key = _normalizeVietnamese(name);
    if (key.isEmpty) return null;
    final all = await fetchDoctors();

    for (final doctor in all) {
      final doctorName = _normalizeVietnamese((doctor['name'] ?? '').toString());
      if (doctorName == key) return doctor;
    }

    for (final doctor in all) {
      final doctorName = _normalizeVietnamese((doctor['name'] ?? '').toString());
      if (doctorName.contains(key) || key.contains(doctorName)) return doctor;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> fetchDoctorByIdentity({
    String? id,
    String? name,
  }) async {
    if (id != null && id.trim().isNotEmpty) {
      final byId = await fetchDoctorById(id);
      if (byId != null) return byId;
    }
    if (name != null && name.trim().isNotEmpty) {
      final byName = await fetchDoctorByNameFlexible(name);
      if (byName != null) return byName;
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

  static List<Map<String, dynamic>> _mapDoctorsFromRawValue(Object? value) {
    if (value == null) return const [];

    List<Map<String, dynamic>> fromList(List<dynamic> list) {
      final result = <Map<String, dynamic>>[];
      for (var i = 0; i < list.length; i++) {
        final row = list[i];
        if (row is Map) {
          final item = Map<String, dynamic>.from(row);
          item.putIfAbsent('id', () => i.toString());
          result.add(item);
        }
      }
      return result;
    }

    List<Map<String, dynamic>> fromMap(Map<dynamic, dynamic> map) {
      final result = <Map<String, dynamic>>[];
      for (final entry in map.entries) {
        final row = entry.value;
        if (row is Map) {
          final item = Map<String, dynamic>.from(row);
          item.putIfAbsent('id', () => entry.key.toString());
          result.add(item);
        }
      }
      return result;
    }

    if (value is List) {
      return fromList(value);
    }

    if (value is Map) {
      final nestedKeys = ['doctors', 'data', 'items', 'list'];
      for (final key in nestedKeys) {
        if (value.containsKey(key)) {
          final nested = value[key];
          if (nested is List) return fromList(nested);
          if (nested is Map) return fromMap(nested);
        }
      }

      final mapped = fromMap(value);
      if (mapped.isNotEmpty) return mapped;

      for (final nested in value.values) {
        if (nested is List) {
          final nestedList = fromList(nested);
          if (nestedList.isNotEmpty) return nestedList;
        }
        if (nested is Map) {
          final nestedMap = fromMap(nested);
          if (nestedMap.isNotEmpty) return nestedMap;
        }
      }
    }

    return const [];
  }

  static String _normalizeVietnamese(String input) {
    final source = input.trim().toLowerCase();
    if (source.isEmpty) return '';
    const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    final buffer = StringBuffer();
    for (final rune in source.runes) {
      final ch = String.fromCharCode(rune);
      final idx = from.indexOf(ch);
      if (idx >= 0) {
        buffer.write(to[idx]);
      } else {
        buffer.write(ch);
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
