import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../data/app_notification_repository.dart';
import '../data/appointment_slots_repository.dart';
import '../data/google_calendar_api_client.dart';
import '../data/google_calendar_sync_repository.dart';
import '../data/local_notification_service.dart';
import '../model/appointment_status.dart';

class MyAppointmentList extends StatefulWidget {
  const MyAppointmentList({super.key});

  @override
  State<MyAppointmentList> createState() => _MyAppointmentListState();
}

class _MyAppointmentListState extends State<MyAppointmentList> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Color get _primary => const Color(0xFF4B5AB5);
  final Set<String> _syncingIds = {};
  final List<String> _statusOrder = ['Pending', 'Confirmed', 'Completed', 'Cancelled'];
  final Color _lightCard = Colors.white;
  // Hàm bổ trợ để lấy màu nền card phù hợp với mode
  Color _getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1E1E1E) // Màu card tối
        : const Color(0xFFE4F2FD); // Màu card sáng (_lightCard cũ)
  }

  void _showTopBanner(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: const Color(0xFFE8F0FE),
        content: Text(message),
        leading: const Icon(Icons.notifications_active_rounded),
        actions: [
          TextButton(
            onPressed: () => messenger.hideCurrentMaterialBanner(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      messenger.hideCurrentMaterialBanner();
    });
  }

  String _formatDate(dynamic value) {
    DateTime date;
    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else {
      date = DateTime.now();
    }
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _formatTime(Map<String, dynamic> data) {
    final rawDate = data['date'];
    if (rawDate is Timestamp) {
      return DateFormat('HH:mm').format(rawDate.toDate());
    }
    if (rawDate is DateTime) {
      return DateFormat('HH:mm').format(rawDate);
    }

    final slotKey = data['slotKey']?.toString().trim() ?? '';
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(slotKey);
    if (match == null) return '--:--';

    final hour = match.group(1)!.padLeft(2, '0');
    final minute = match.group(2)!;
    return '$hour:$minute';
  }

  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  bool _canManualSyncToGoogleCalendar(String status) {
    final normalized = AppointmentStatus.normalize(status);
    return normalized == AppointmentStatus.pending ||
        normalized == AppointmentStatus.confirmed;
  }

  Map<String, dynamic> _buildManualSyncCalendarEventPayload({
    required Map<String, dynamic> data,
    required DateTime start,
    required String status,
  }) {
    final end = start.add(const Duration(hours: 1));
    final doctor = data['doctor']?.toString().trim() ?? 'Bác sĩ';
    final patient = data['name']?.toString().trim() ?? 'Bệnh nhân';
    final phone = data['phone']?.toString().trim() ?? 'Chưa có';
    final note = data['description']?.toString().trim();
    final descriptionLines = <String>[
      'Lịch hẹn từ ứng dụng đặt lịch khám',
      'Trạng thái: ${AppointmentStatus.label(status)}',
      'Bác sĩ: $doctor',
      'Bệnh nhân: $patient',
      'SĐT: $phone',
      if (note != null && note.isNotEmpty) 'Ghi chú: $note',
    ];

    return {
      'summary': '[$status] Khám với $doctor - $patient',
      'description': descriptionLines.join('\n'),
      'start': {
        'dateTime': start.toUtc().toIso8601String(),
        'timeZone': 'Asia/Ho_Chi_Minh',
      },
      'end': {
        'dateTime': end.toUtc().toIso8601String(),
        'timeZone': 'Asia/Ho_Chi_Minh',
      },
    };
  }

  Future<void> _manualSyncAppointmentToGoogleCalendar({
    required String uid,
    required String id,
    required String status,
    required Map<String, dynamic> data,
  }) async {
    final normalizedStatus = AppointmentStatus.normalize(status);
    if (!_canManualSyncToGoogleCalendar(normalizedStatus)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chỉ lịch Pending hoặc Confirmed mới đồng bộ được với Google Calendar.',
          ),
        ),
      );
      return;
    }

    if (_syncingIds.contains(id)) {
      return;
    }

    setState(() {
      _syncingIds.add(id);
    });

    final firestore = FirebaseFirestore.instance;
    final pendingRef = firestore
        .collection('appointments')
        .doc(uid)
        .collection('pending')
        .doc(id);
    final allRef = await _resolveAllRef(
      firestore: firestore,
      uid: uid,
      pendingId: id,
    );

    try {
      final calendarRepo = GoogleCalendarSyncRepository.instance;
      final linked = await calendarRepo.isCalendarLinkedForCurrentUser();
      if (!linked) {
        await pendingRef.set({
          'calendarSyncState': 'skipped',
          'calendarSyncError': 'calendar-not-linked',
        }, SetOptions(merge: true));
        await allRef.set({
          'calendarSyncState': 'skipped',
          'calendarSyncError': 'calendar-not-linked',
        }, SetOptions(merge: true));
        throw Exception(
          'Bạn chưa liên kết Google Calendar trong phần Cài đặt.',
        );
      }

      final accessToken = await calendarRepo.getCalendarAccessToken(
        interactive: true,
      );
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Không lấy được access token Google Calendar.');
      }

      final calendarId = await calendarRepo.getCalendarIdForCurrentUser();
      final start = _parseDate(data['date']);
      final payload = _buildManualSyncCalendarEventPayload(
        data: data,
        start: start,
        status: normalizedStatus,
      );

      final currentEventId = data['googleEventId']?.toString().trim() ?? '';
      var finalEventId = currentEventId;
      if (finalEventId.isEmpty) {
        finalEventId = await GoogleCalendarApiClient.instance.createEvent(
          accessToken: accessToken,
          calendarId: calendarId,
          event: payload,
        );
      } else {
        await GoogleCalendarApiClient.instance.updateEvent(
          accessToken: accessToken,
          calendarId: calendarId,
          eventId: finalEventId,
          event: payload,
        );
      }

      await pendingRef.set({
        'googleEventId': finalEventId,
        'calendarSyncState': 'synced',
        'calendarSyncError': null,
        'calendarSyncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await allRef.set({
        'googleEventId': finalEventId,
        'calendarSyncState': 'synced',
        'calendarSyncError': null,
        'calendarSyncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã đồng bộ lịch hẹn lên Google Calendar.'),
        ),
      );
    } catch (error) {
      await pendingRef.set({
        'calendarSyncState': 'error',
        'calendarSyncError': error.toString(),
      }, SetOptions(merge: true));
      await allRef.set({
        'calendarSyncState': 'error',
        'calendarSyncError': error.toString(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đồng bộ Calendar thất bại: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _syncingIds.remove(id);
        });
      }
    }
  }

  Future<DocumentReference<Map<String, dynamic>>> _resolveAllRef({
    required FirebaseFirestore firestore,
    required String uid,
    required String pendingId,
  }) async {
    final directRef = firestore
        .collection('appointments')
        .doc(uid)
        .collection('all')
        .doc(pendingId);

    final directSnap = await directRef.get();
    if (directSnap.exists) return directRef;

    final query = await firestore
        .collection('appointments')
        .doc(uid)
        .collection('all')
        .where('sourcePendingId', isEqualTo: pendingId)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.reference;
    }

    return directRef;
  }

  Future<void> _setStatus({
    required String uid,
    required String id,
    required Map<String, dynamic> data,
    required String nextStatus,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final pendingRef = firestore
        .collection('appointments')
        .doc(uid)
        .collection('pending')
        .doc(id);
    final allRef = await _resolveAllRef(
      firestore: firestore,
      uid: uid,
      pendingId: id,
    );

    final date = _parseDate(data['date']);

    final doctorName = data['doctor']?.toString() ?? '';
    final doctorId = (data['doctorId']?.toString().trim().isNotEmpty ?? false)
        ? data['doctorId'].toString().trim()
        : AppointmentSlotsRepository.normalizeDoctorId(doctorName);
    final dayKey = (data['dayKey']?.toString().trim().isNotEmpty ?? false)
        ? data['dayKey'].toString().trim()
        : AppointmentSlotsRepository.dayKey(date);
    final slotKey = (data['slotKey']?.toString().trim().isNotEmpty ?? false)
        ? data['slotKey'].toString().trim()
        : AppointmentSlotsRepository.slotKeyFromDateTime(date);

    final userSlotRef = firestore
        .collection('appointments')
        .doc(uid)
        .collection('pending_slots')
        .doc('${dayKey}_$slotKey');

    final slotRef = AppointmentSlotsRepository.slotDocRef(
      firestore: firestore,
      doctorId: doctorId,
      date: date,
      slotKey: slotKey,
    );

    final status = AppointmentStatus.normalize(nextStatus);

    await firestore.runTransaction((tx) async {
      final currentSnap = await tx.get(pendingRef);
      if (!currentSnap.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Không tìm thấy lịch hẹn để cập nhật.',
        );
      }

      final currentData = currentSnap.data() ?? const <String, dynamic>{};
      final currentStatus = AppointmentStatus.normalize(
        currentData['status']?.toString(),
      );
      if (!AppointmentStatus.canTransition(from: currentStatus, to: status)) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'invalid-transition',
          message: 'Không thể chuyển trạng thái này.',
        );
      }

      if (status == AppointmentStatus.confirmed) {
        final userSlotSnap = await tx.get(userSlotRef);
        if (userSlotSnap.exists &&
            userSlotSnap.data()?['appointmentPendingId'] != id) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'patient-conflict',
            message: 'Bạn đã có một lịch confirmed trong khung giờ này.',
          );
        }

        tx.set(userSlotRef, {
          'uid': uid,
          'doctorId': doctorId,
          'dayKey': dayKey,
          'slotKey': slotKey,
          'date': Timestamp.fromDate(date),
          'appointmentPendingId': id,
          'status': AppointmentStatus.confirmed,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': userSlotSnap.exists
              ? (userSlotSnap.data()?['createdAt'] ??
                    FieldValue.serverTimestamp())
              : FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        tx.delete(userSlotRef);
        tx.delete(slotRef);
      }

      final statusPayload = <String, dynamic>{
        'status': status,
        'slotLockState': status == AppointmentStatus.confirmed
            ? 'locked'
            : 'released',
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      };

      if (status == AppointmentStatus.confirmed) {
        statusPayload['confirmedAt'] = FieldValue.serverTimestamp();
      }
      if (status == AppointmentStatus.completed) {
        statusPayload['completedAt'] = FieldValue.serverTimestamp();
      }
      if (status == AppointmentStatus.cancelled) {
        statusPayload['cancelledAt'] = FieldValue.serverTimestamp();
      }

      tx.set(pendingRef, statusPayload, SetOptions(merge: true));
      tx.set(allRef, {
        ...statusPayload,
        'sourcePendingId': id,
      }, SetOptions(merge: true));
    });

    await _syncCalendarAfterStatusChange(
      pendingRef: pendingRef,
      allRef: allRef,
      data: data,
      nextStatus: status,
      date: date,
    );

    try {
      final doctorLabel = data['doctor']?.toString().trim();
      final doctor = (doctorLabel == null || doctorLabel.isEmpty)
          ? 'Bác sĩ'
          : doctorLabel;
      final statusTitle = _statusNotificationTitle(status);
      final statusType = _statusNotificationType(status);

      try {
        await AppNotificationRepository.instance.createForUser(
          uid: uid,
          title: statusTitle,
          message:
              'Lịch với $doctor lúc ${DateFormat('HH:mm - dd/MM/yyyy').format(date)} đã chuyển sang ${AppointmentStatus.label(status)}.',
          type: statusType,
          extra: <String, dynamic>{
            'appointmentId': id,
            'status': status,
            'doctor': doctor,
          },
        );
      } catch (_) {
        // Firestore notification failure should not block status updates.
      }

      try {
        await LocalNotificationService.instance.showNow(
          title: statusTitle,
          body:
              'Lịch với $doctor lúc ${DateFormat('HH:mm - dd/MM/yyyy').format(date)} đã chuyển sang ${AppointmentStatus.label(status)}.',
          appointmentId: id,
        );

        if (status == AppointmentStatus.confirmed) {
          await LocalNotificationService.instance.scheduleReminder30MinBefore(
            appointmentId: id,
            doctorName: doctor,
            appointmentTime: date,
          );
        } else {
          await LocalNotificationService.instance.cancelReminder(
            appointmentId: id,
          );
        }
      } catch (_) {
        // Local notification failure should not block status updates.
      }
    } catch (_) {
      // Ignore non-critical notification composition failures.
    }
  }

  String _statusNotificationTitle(String status) {
    switch (AppointmentStatus.normalize(status)) {
      case AppointmentStatus.confirmed:
        return 'Lịch hẹn đã xác nhận';
      case AppointmentStatus.cancelled:
        return 'Lịch hẹn đã hủy';
      case AppointmentStatus.completed:
        return 'Lịch hẹn đã hoàn tất';
      case AppointmentStatus.pending:
      default:
        return 'Lịch hẹn đang chờ xử lý';
    }
  }

  String _statusNotificationType(String status) {
    switch (AppointmentStatus.normalize(status)) {
      case AppointmentStatus.confirmed:
        return 'appointment_confirmed';
      case AppointmentStatus.cancelled:
        return 'appointment_cancelled';
      case AppointmentStatus.completed:
        return 'appointment_completed';
      case AppointmentStatus.pending:
      default:
        return 'appointment_pending';
    }
  }

  Future<void> _syncCalendarAfterStatusChange({
    required DocumentReference<Map<String, dynamic>> pendingRef,
    required DocumentReference<Map<String, dynamic>> allRef,
    required Map<String, dynamic> data,
    required String nextStatus,
    required DateTime date,
  }) async {
    final calendarRepo = GoogleCalendarSyncRepository.instance;
    final linked = await calendarRepo.isCalendarLinkedForCurrentUser();
    if (!linked) {
      await pendingRef.set({
        'calendarSyncState': 'skipped',
        'calendarSyncError': 'calendar-not-linked',
      }, SetOptions(merge: true));
      await allRef.set({
        'calendarSyncState': 'skipped',
        'calendarSyncError': 'calendar-not-linked',
      }, SetOptions(merge: true));
      return;
    }

    final accessToken = await calendarRepo.getCalendarAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      await pendingRef.set({
        'calendarSyncState': 'error',
        'calendarSyncError': 'missing-access-token',
      }, SetOptions(merge: true));
      await allRef.set({
        'calendarSyncState': 'error',
        'calendarSyncError': 'missing-access-token',
      }, SetOptions(merge: true));
      return;
    }

    final calendarId = await calendarRepo.getCalendarIdForCurrentUser();
    final currentEventId = data['googleEventId']?.toString().trim() ?? '';
    final normalizedStatus = AppointmentStatus.normalize(nextStatus);

    try {
      if (normalizedStatus == AppointmentStatus.cancelled ||
          normalizedStatus == AppointmentStatus.pending) {
        if (currentEventId.isNotEmpty) {
          await GoogleCalendarApiClient.instance.deleteEvent(
            accessToken: accessToken,
            calendarId: calendarId,
            eventId: currentEventId,
          );
        }
        await pendingRef.set({
          'googleEventId': FieldValue.delete(),
          'calendarSyncState': 'synced',
          'calendarSyncError': null,
          'calendarSyncedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await allRef.set({
          'googleEventId': FieldValue.delete(),
          'calendarSyncState': 'synced',
          'calendarSyncError': null,
          'calendarSyncedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }

      final payload = _buildCalendarEventPayload(
        data: data,
        start: date,
        status: normalizedStatus,
      );
      var finalEventId = currentEventId;
      if (finalEventId.isEmpty) {
        finalEventId = await GoogleCalendarApiClient.instance.createEvent(
          accessToken: accessToken,
          calendarId: calendarId,
          event: payload,
        );
      } else {
        await GoogleCalendarApiClient.instance.updateEvent(
          accessToken: accessToken,
          calendarId: calendarId,
          eventId: finalEventId,
          event: payload,
        );
      }

      await pendingRef.set({
        'googleEventId': finalEventId,
        'calendarSyncState': 'synced',
        'calendarSyncError': null,
        'calendarSyncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await allRef.set({
        'googleEventId': finalEventId,
        'calendarSyncState': 'synced',
        'calendarSyncError': null,
        'calendarSyncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      await pendingRef.set({
        'calendarSyncState': 'error',
        'calendarSyncError': error.toString(),
      }, SetOptions(merge: true));
      await allRef.set({
        'calendarSyncState': 'error',
        'calendarSyncError': error.toString(),
      }, SetOptions(merge: true));
    }
  }

  Map<String, dynamic> _buildCalendarEventPayload({
    required Map<String, dynamic> data,
    required DateTime start,
    required String status,
  }) {
    final end = start.add(const Duration(hours: 1));
    final doctor = data['doctor']?.toString().trim() ?? 'Bác sĩ';
    final patient = data['name']?.toString().trim() ?? 'Bệnh nhân';
    final phone = data['phone']?.toString().trim() ?? '';
    final note = data['description']?.toString().trim() ?? '';
    final isCompleted = status == AppointmentStatus.completed;

    return {
      'summary': isCompleted
          ? '[Completed] Khám với $doctor - $patient'
          : 'Khám với $doctor - $patient',
      'description': 'SĐT: $phone\\nGhi chú: $note',
      'start': {
        'dateTime': start.toUtc().toIso8601String(),
        'timeZone': 'Asia/Ho_Chi_Minh',
      },
      'end': {
        'dateTime': end.toUtc().toIso8601String(),
        'timeZone': 'Asia/Ho_Chi_Minh',
      },
    };
  }

  Future<void> _onAction({
    required String uid,
    required String id,
    required Map<String, dynamic> data,
    required String nextStatus,
  }) async {
    try {
      await _setStatus(uid: uid, id: id, data: data, nextStatus: nextStatus);
    } on FirebaseException catch (e) {
      var message = 'Không thể cập nhật trạng thái. Vui lòng thử lại.';
      if (e.code == 'patient-conflict') {
        message = 'Bạn đã có một lịch confirmed trong khung giờ này.';
      } else if (e.code == 'invalid-transition') {
        message = 'Trạng thái hiện tại không cho phép thao tác này.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    if (!mounted) return;
    _showTopBanner(
      'Đã chuyển trạng thái: ${AppointmentStatus.label(nextStatus)}',
    );
  }

  Color _statusColor(String status) {
    switch (AppointmentStatus.normalize(status)) {
      case AppointmentStatus.confirmed:
        return Colors.green.shade700;
      case AppointmentStatus.completed:
        return Colors.blueGrey.shade700;
      case AppointmentStatus.cancelled:
        return Colors.red.shade700;
      case AppointmentStatus.pending:
      default:
        return Colors.orange.shade700;
    }
  }

  IconData _statusIcon(String status) {
    switch (AppointmentStatus.normalize(status)) {
      case AppointmentStatus.confirmed:
        return Icons.verified_rounded;
      case AppointmentStatus.completed:
        return Icons.task_alt_rounded;
      case AppointmentStatus.cancelled:
        return Icons.cancel_rounded;
      case AppointmentStatus.pending:
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  Widget _buildStatusSummaryChip({required String status, required int count, bool isDark = false,}) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '${AppointmentStatus.label(status)}: $count',
            style: GoogleFonts.lato(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSectionHeader({
    required String status,
    required int count,
    bool isDark = false,
  }) {
    final color = _statusColor(status);
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Row(
        children: [
          Icon(_statusIcon(status), color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            AppointmentStatus.label(status),
            style: GoogleFonts.lato(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.lato(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard({
    required User user,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required Map<String, dynamic> data,
    required String status,
    required BuildContext context,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: _lightCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.event_available_rounded,
                color: _primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['doctor']?.toString() ?? 'Bác sĩ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lato(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ngày khám: ${_formatDate(data['date'])} - Giờ: ${_formatTime(data)}',
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          AppointmentStatus.label(status),
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _statusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if ((data['name'] ?? '').toString().trim().isNotEmpty)
                    Text(
                      'Bệnh nhân: ${data['name']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 34,
                    child: OutlinedButton.icon(
                      onPressed:
                          _canManualSyncToGoogleCalendar(status) &&
                              !_syncingIds.contains(doc.id)
                          ? () => _manualSyncAppointmentToGoogleCalendar(
                              uid: user.uid,
                              id: doc.id,
                              status: status,
                              data: data,
                            )
                          : null,
                      icon: _syncingIds.contains(doc.id)
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        _syncingIds.contains(doc.id)
                            ? 'Đang đồng bộ...'
                            : 'Google Calendar',
                        style: GoogleFonts.lato(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        disabledForegroundColor: Colors.black38,
                        side: BorderSide(
                          color: _canManualSyncToGoogleCalendar(status)
                              ? _primary.withValues(alpha: 0.45)
                              : Colors.black26,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: _buildActions(
                uid: user.uid,
                id: doc.id,
                data: data,
                status: status,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions({
    required String uid,
    required String id,
    required Map<String, dynamic> data,
    required String status,
  }) {
    final normalized = AppointmentStatus.normalize(status);
    final actions = <Widget>[];

    if (normalized == AppointmentStatus.pending) {
      actions.add(
        TextButton(
          onPressed: () => _onAction(
            uid: uid,
            id: id,
            data: data,
            nextStatus: AppointmentStatus.cancelled,
          ),
          child: Text(
            'Hủy',
            style: GoogleFonts.lato(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: Colors.red.shade700,
            ),
          ),
        ),
      );
      actions.add(
        TextButton(
          onPressed: () => _onAction(
            uid: uid,
            id: id,
            data: data,
            nextStatus: AppointmentStatus.confirmed,
          ),
          child: Text(
            'Xác nhận',
            style: GoogleFonts.lato(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: Colors.green.shade700,
            ),
          ),
        ),
      );
      return actions;
    }

    if (normalized == AppointmentStatus.confirmed) {
      actions.add(
        TextButton(
          onPressed: () => _onAction(
            uid: uid,
            id: id,
            data: data,
            nextStatus: AppointmentStatus.completed,
          ),
          child: Text(
            'Hoàn thành',
            style: GoogleFonts.lato(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: Colors.blueGrey.shade700,
            ),
          ),
        ),
      );
      actions.add(
        TextButton(
          onPressed: () => _onAction(
            uid: uid,
            id: id,
            data: data,
            nextStatus: AppointmentStatus.cancelled,
          ),
          child: Text(
            'Hủy',
            style: GoogleFonts.lato(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: Colors.red.shade700,
            ),
          ),
        ),
      );
      return actions;
    }

    return actions;
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (user == null) {
      return Center(child: Text( 
        'Vui lòng đăng nhập để xem lịch hẹn', 
        style: GoogleFonts.lato(color: isDark ? Colors.white70 : Colors.black54),));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .doc(user.uid)
          .collection('pending')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return Center(
            child: Text(
              'Chưa có lịch hẹn',
              style: GoogleFonts.lato(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          );
        }

        final grouped =
            <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{
              for (final status in _statusOrder)
                status: <QueryDocumentSnapshot<Map<String, dynamic>>>[],
            };

        for (final doc in docs) {
          final status = AppointmentStatus.normalize(
            doc.data()['status']?.toString(),
          );
          grouped
              .putIfAbsent(
                status,
                () => <QueryDocumentSnapshot<Map<String, dynamic>>>[],
              )
              .add(doc);
        }

        final sections = <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _statusOrder
                  .map<Widget>(
                    (status) => _buildStatusSummaryChip(
                      status: status,
                      count: grouped[status]?.length ?? 0,
                      isDark: isDark,
                    ),
                  )
                  .toList(),
            ),
          ),
        ];

        for (final status in _statusOrder) {
          final sectionDocs =
              grouped[status] ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          if (sectionDocs.isEmpty) continue;

          sections.add(
            _buildStatusSectionHeader(
              status: status,
              count: sectionDocs.length,
            ),
          );
          for (final doc in sectionDocs) {
            final data = doc.data();
            sections.add(
              _buildAppointmentCard(
                user: user,
                doc: doc,
                data: data,
                status: status,
                context: context,
              ),
            );
            sections.add(const SizedBox(height: 9));
          }
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 8),
          children: sections,
        );
      },
    );
  }
}
