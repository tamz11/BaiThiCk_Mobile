import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../data/realtime_doctors_repository.dart';
import '../model/appointment_status.dart';

class AppointmentHistoryList extends StatefulWidget {
  const AppointmentHistoryList({super.key, this.compactProfileStyle = false});

  final bool compactProfileStyle;

  @override
  State<AppointmentHistoryList> createState() => _AppointmentHistoryListState();
}

class _AppointmentHistoryListState extends State<AppointmentHistoryList> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const Color _primary = Color(0xFF4B5AB5);
  static const Color _soft = Color(0xFFE4F2FD);

  final Map<String, String> _avatarByDoctorId = <String, String>{};
  final Map<String, String> _avatarByDoctorName = <String, String>{};

  @override
  void initState() {
    super.initState();
    _loadDoctorAvatarMap();
  }

  Future<void> _loadDoctorAvatarMap() async {
    try {
      final doctors = await RealtimeDoctorsRepository.fetchDoctors();
      final nextById = <String, String>{};
      final nextByName = <String, String>{};

      for (final doctor in doctors) {
        final avatar = _doctorAvatarFromRecord(doctor);
        if (avatar.isEmpty) continue;

        final id = doctor['id']?.toString().trim() ?? '';
        final name = doctor['name']?.toString().trim() ?? '';
        if (id.isNotEmpty) {
          nextById[_normalizeKey(id)] = avatar;
        }
        if (name.isNotEmpty) {
          nextByName[_normalizeKey(name)] = avatar;
        }
      }

      if (!mounted) return;
      setState(() {
        _avatarByDoctorId
          ..clear()
          ..addAll(nextById);
        _avatarByDoctorName
          ..clear()
          ..addAll(nextByName);
      });
    } catch (_) {
      // Keep fallback avatar if doctors source is unavailable.
    }
  }

  String _normalizeKey(String raw) {
    return raw.trim().toLowerCase();
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

  String _doctorAvatarFromRecord(Map<String, dynamic> data) {
    const keys = <String>[
      'doctorImage',
      'doctorAvatar',
      'doctorAvatarUrl',
      'image',
      'avatar',
      'avatarUrl',
    ];
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _doctorAvatar(Map<String, dynamic> appointment) {
    final direct = _doctorAvatarFromRecord(appointment);
    if (direct.isNotEmpty) return direct;

    final doctorId = appointment['doctorId']?.toString().trim() ?? '';
    if (doctorId.isNotEmpty) {
      final byId = _avatarByDoctorId[_normalizeKey(doctorId)] ?? '';
      if (byId.isNotEmpty) return byId;
    }

    final doctorName = appointment['doctor']?.toString().trim() ?? '';
    if (doctorName.isNotEmpty) {
      final byName = _avatarByDoctorName[_normalizeKey(doctorName)] ?? '';
      if (byName.isNotEmpty) return byName;
    }

    return '';
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
          .limit(widget.compactProfileStyle ? 5 : 80)
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

        final visibleDocs = widget.compactProfileStyle
            ? docs.take(1).toList()
            : docs;
        return Column(
          children: visibleDocs.map((doc) {
            final data = doc.data();
            final status = AppointmentStatus.normalize(
              data['status']?.toString(),
            );
            if (widget.compactProfileStyle) {
              final doctorName = data['doctor']?.toString() ?? 'Bác sĩ';
              final avatar = _doctorAvatar(data);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        child: ClipOval(
                          child: avatar.isNotEmpty
                              ? Image.network(
                                  avatar,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    'assets/doc.png',
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Image.asset(
                                  'assets/doc.png',
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doctorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.lato(
                                fontSize: 22,
                                color: Colors.black87,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _formatDate(data['date']),
                              style: GoogleFonts.lato(
                                fontSize: 15,
                                color: Colors.black54,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              AppointmentStatus.label(status),
                              style: GoogleFonts.lato(
                                fontSize: 13,
                                color: _statusColor(status),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: _soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      child: ClipOval(
                        child: _doctorAvatar(data).isNotEmpty
                            ? Image.network(
                                _doctorAvatar(data),
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Image.asset(
                                  'assets/doc.png',
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.asset(
                                'assets/doc.png',
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${data['doctor'] ?? 'Bác sĩ'} - ${_formatDate(data['date'])}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppointmentStatus.label(status),
                            style: GoogleFonts.lato(
                              fontSize: 12,
                              color: _statusColor(status),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.circle, size: 10, color: _statusColor(status)),
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
