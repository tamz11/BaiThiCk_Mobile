import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../data/appointment_slots_repository.dart';

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

  Future<void> _cancel(String uid, String id, Map<String, dynamic> data) async {
    final firestore = FirebaseFirestore.instance;
    final pendingRef = firestore
        .collection('appointments')
        .doc(uid)
        .collection('pending')
        .doc(id);

    DateTime date;
    final rawDate = data['date'];
    if (rawDate is Timestamp) {
      date = rawDate.toDate();
    } else if (rawDate is DateTime) {
      date = rawDate;
    } else {
      date = DateTime.now();
    }

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

    final slotRef = AppointmentSlotsRepository.slotDocRef(
      firestore: firestore,
      doctorId: doctorId,
      date: date,
      slotKey: slotKey,
    );
    final userSlotRef = firestore
        .collection('appointments')
        .doc(uid)
        .collection('pending_slots')
        .doc('${dayKey}_$slotKey');

    final batch = firestore.batch();
    batch.delete(pendingRef);
    batch.delete(slotRef);
    batch.delete(userSlotRef);
    await batch.commit();
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
              'Không có lịch hẹn đang chờ',
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
          separatorBuilder: (_, __) => const SizedBox(height: 9),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
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
                            'Ngày khám: ${_formatDate(data['date'])}',
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
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
                    TextButton(
                      onPressed: () => _cancel(user.uid, doc.id, data),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                      ),
                      child: Text(
                        'Hủy',
                        style: GoogleFonts.lato(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
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
