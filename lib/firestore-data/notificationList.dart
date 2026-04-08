import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class NotificationList extends StatefulWidget {
  const NotificationList({super.key});

  @override
  State<NotificationList> createState() => _NotificationListState();
}

class _NotificationListState extends State<NotificationList> {
  static const Color _primary = Color(0xFF4B5AB5);
  static const Color _soft = Color(0xFFE4F2FD);

  Future<void> _markReadIfNeeded(
    DocumentReference<Map<String, dynamic>> ref,
    bool read,
  ) async {
    if (read) return;
    try {
      await ref.set({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Ignore read-marking failure to keep UI responsive.
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Vừa xong';
    return DateFormat('HH:mm - dd/MM/yyyy').format(timestamp.toDate());
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'appointment_created':
        return Icons.event_available_rounded;
      case 'appointment_confirmed':
        return Icons.verified_rounded;
      case 'appointment_cancelled':
        return Icons.cancel_rounded;
      case 'appointment_completed':
        return Icons.task_alt_rounded;
      case 'appointment_pending':
        return Icons.hourglass_top_rounded;
      case 'appointment_status_changed':
        return Icons.sync_alt_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _iconColorForType(String type) {
    switch (type) {
      case 'appointment_confirmed':
        return Colors.green.shade700;
      case 'appointment_cancelled':
        return Colors.red.shade700;
      case 'appointment_completed':
        return Colors.blueGrey.shade700;
      case 'appointment_pending':
        return Colors.orange.shade700;
      case 'appointment_created':
        return Colors.indigo.shade600;
      case 'appointment_status_changed':
        return _primary;
      default:
        return _primary;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: _primary.withValues(alpha: 0.15),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: _primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Không có thông báo mới',
              style: GoogleFonts.lato(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          title: Text(
            'Thông báo',
            style: GoogleFonts.lato(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: Center(
          child: Text(
            'Vui lòng đăng nhập để xem thông báo.',
            style: GoogleFonts.lato(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          'Thông báo',
          style: GoogleFonts.lato(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('notification_history')
            .doc(user.uid)
            .collection('messages')
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
            itemCount: docs.length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final ref = docs[index].reference;
              final title = data['title']?.toString().trim() ?? 'Thông báo';
              final message = data['message']?.toString().trim() ?? '';
              final type = data['type']?.toString().trim() ?? 'general';
              final createdAt = data['createdAt'] as Timestamp?;
              final read = data['read'] == true;
              final iconColor = _iconColorForType(type);
              final cardBg = read
                  ? const Color(0xFFE8EEF4)
                  : const Color(0xFFDCEBFB);

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _markReadIfNeeded(ref, read),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: read
                          ? _primary.withValues(alpha: 0.08)
                          : _primary.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: iconColor.withValues(alpha: 0.14),
                        child: Icon(
                          _iconForType(type),
                          color: iconColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.lato(
                                fontSize: 15,
                                fontWeight: read
                                    ? FontWeight.w700
                                    : FontWeight.w900,
                                color: Colors.black87,
                              ),
                            ),
                            if (message.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                message,
                                style: GoogleFonts.lato(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              _formatTime(createdAt),
                              style: GoogleFonts.lato(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
