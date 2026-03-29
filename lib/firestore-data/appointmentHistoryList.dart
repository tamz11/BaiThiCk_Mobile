import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AppointmentHistoryList extends StatefulWidget {
  const AppointmentHistoryList({
    super.key,
    this.compactProfileStyle = false,
  });

  final bool compactProfileStyle;

  @override
  State<AppointmentHistoryList> createState() => _AppointmentHistoryListState();
}

class _AppointmentHistoryListState extends State<AppointmentHistoryList> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const Color _primary = Color(0xFF4B5AB5);
  static const Color _soft = Color(0xFFE4F2FD);

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

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Text('Vui lòng đăng nhập để xem lịch sử');
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .doc(user.uid)
          .collection('all')
          .orderBy('date', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return Text(
            'Chưa có lịch sử lịch hẹn.',
            style: GoogleFonts.lato(
              fontSize: 14,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          );
        }

        final visibleDocs = widget.compactProfileStyle ? docs.take(1).toList() : docs;
        return Column(
          children: visibleDocs.map((doc) {
            final data = doc.data();
            if (widget.compactProfileStyle) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['doctor']?.toString() ?? 'Bác sĩ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lato(
                        fontSize: 19,
                        color: Colors.black87,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _formatDate(data['date']),
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: _soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, size: 18, color: _primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${data['doctor'] ?? 'Bác sĩ'} - ${_formatDate(data['date'])}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
