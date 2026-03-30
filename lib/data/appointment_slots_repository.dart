import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppointmentSlotsRepository {
  AppointmentSlotsRepository._();

  static const int slotMinutes = 60;

  static String normalizeDoctorId(String doctorName, {String? explicitId}) {
    final direct = explicitId?.trim() ?? '';
    if (direct.isNotEmpty) return direct;

    final raw = doctorName.trim().toLowerCase();
    if (raw.isEmpty) return 'doctor_unknown';

    final slug = raw
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    if (slug.isNotEmpty) return slug;
    return 'doctor_${raw.hashCode.abs()}';
  }

  static String dayKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  static String slotKeyFromTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String slotKeyFromDateTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static DateTime combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  static TimeOfDay? parseHourMinute(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim();
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(normalized);
    if (match == null) return null;

    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  static List<TimeOfDay> buildDailySlots({
    required DateTime date,
    required String openHour,
    required String closeHour,
  }) {
    final open =
        parseHourMinute(openHour) ?? const TimeOfDay(hour: 8, minute: 0);
    final close =
        parseHourMinute(closeHour) ?? const TimeOfDay(hour: 17, minute: 0);

    var cursor = DateTime(
      date.year,
      date.month,
      date.day,
      open.hour,
      open.minute,
    );
    final end = DateTime(
      date.year,
      date.month,
      date.day,
      close.hour,
      close.minute,
    );

    final slots = <TimeOfDay>[];
    while (cursor.isBefore(end)) {
      slots.add(TimeOfDay(hour: cursor.hour, minute: cursor.minute));
      cursor = cursor.add(const Duration(minutes: slotMinutes));
    }

    return slots;
  }

  static bool isPastSlot(DateTime date, TimeOfDay time) {
    final slotDateTime = combineDateAndTime(date, time);
    return !slotDateTime.isAfter(DateTime.now());
  }

  static CollectionReference<Map<String, dynamic>> _slotCollection({
    required FirebaseFirestore firestore,
    required String doctorId,
    required DateTime date,
  }) {
    return firestore
        .collection('doctor_slots')
        .doc(doctorId)
        .collection('days')
        .doc(dayKey(date))
        .collection('slots');
  }

  static DocumentReference<Map<String, dynamic>> slotDocRef({
    required FirebaseFirestore firestore,
    required String doctorId,
    required DateTime date,
    required String slotKey,
  }) {
    return _slotCollection(
      firestore: firestore,
      doctorId: doctorId,
      date: date,
    ).doc(slotKey);
  }

  static Future<Set<String>> fetchBookedSlotKeys({
    required FirebaseFirestore firestore,
    required String doctorId,
    required DateTime date,
  }) async {
    final snapshot = await _slotCollection(
      firestore: firestore,
      doctorId: doctorId,
      date: date,
    ).get();

    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  static Future<Set<String>> fetchUserConfirmedSlotKeys({
    required FirebaseFirestore firestore,
    required String uid,
    required DateTime date,
  }) async {
    final snapshot = await firestore
        .collection('appointments')
        .doc(uid)
        .collection('pending')
        .where('dayKey', isEqualTo: dayKey(date))
        .where('status', isEqualTo: 'confirmed')
        .get();

    return snapshot.docs
        .map((doc) => doc.data()['slotKey']?.toString() ?? '')
        .where((slot) => slot.isNotEmpty)
        .toSet();
  }
}
