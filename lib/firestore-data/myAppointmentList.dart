import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../data/appointment_slots_repository.dart';
import '../model/appointment_status.dart';

class MyAppointmentList extends StatefulWidget {
  const MyAppointmentList({super.key});

  @override
  State<MyAppointmentList> createState() => _MyAppointmentListState();
}

class _MyAppointmentListState extends State<MyAppointmentList> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const Color _primary = Color(0xFF4B5AB5);
  static const Color _lightCard = Color(0xFFE4F2FD);

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã chuyển trạng thái: ${AppointmentStatus.label(nextStatus)}',
        ),
      ),
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
            nextStatus: AppointmentStatus.confirmed,
          ),
          child: Text(
            'Confirm',
            style: GoogleFonts.lato(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: Colors.green.shade700,
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
            'Cancel',
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

    if (normalized == AppointmentStatus.confirmed) {
      actions.add(
        TextButton(
          onPressed: () => _onAction(
            uid: uid,
            id: id,
            data: data,
            nextStatus: AppointmentStatus.pending,
          ),
          child: Text(
            'Pending',
            style: GoogleFonts.lato(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: Colors.orange.shade700,
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
            nextStatus: AppointmentStatus.completed,
          ),
          child: Text(
            'Completed',
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
            'Cancel',
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
    if (user == null) {
      return const Center(child: Text('Vui lòng đăng nhập để xem lịch hẹn'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .doc(user.uid)
          .collection('pending')
          .orderBy('date')
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
                color: Colors.black54,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 9),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final status = AppointmentStatus.normalize(
              data['status']?.toString(),
            );
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
                                  color: _statusColor(
                                    status,
                                  ).withValues(alpha: 0.12),
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
          },
        );
      },
    );
  }
}
