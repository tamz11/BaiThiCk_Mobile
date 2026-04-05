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
  // Hàm xử lý đánh dấu đã đọc
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
    } catch (_) {}
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Vừa xong';
    return DateFormat('HH:mm - dd/MM/yyyy').format(timestamp.toDate());
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'appointment_created': return Icons.event_available_rounded;
      case 'appointment_confirmed': return Icons.verified_rounded;
      case 'appointment_cancelled': return Icons.cancel_rounded;
      case 'appointment_completed': return Icons.task_alt_rounded;
      case 'appointment_pending': return Icons.hourglass_top_rounded;
      case 'appointment_status_changed': return Icons.sync_alt_rounded;
      default: return Icons.notifications_none_rounded;
    }
  }

  Color _iconColorForType(String type, bool isDark, Color primary) {
    if (isDark) {
      switch (type) {
        case 'appointment_confirmed': return Colors.greenAccent[400]!;
        case 'appointment_cancelled': return Colors.redAccent[200]!;
        case 'appointment_pending': return Colors.orangeAccent[200]!;
        default: return Colors.blueAccent[100]!;
      }
    }
    switch (type) {
      case 'appointment_confirmed': return Colors.green.shade700;
      case 'appointment_cancelled': return Colors.red.shade700;
      case 'appointment_completed': return Colors.blueGrey.shade700;
      case 'appointment_pending': return Colors.orange.shade700;
      case 'appointment_created': return Colors.indigo.shade600;
      default: return primary;
    }
  }

  Widget _buildEmptyState(Color primary, Color soft) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: soft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: primary.withAlpha(40),
              child: Icon(Icons.notifications_none_rounded, color: primary, size: 20),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final soft = isDark ? Colors.white10 : Colors.grey.shade100;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Thông báo',
          style: GoogleFonts.lato(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: user == null
          ? Center(
              child: Text(
                'Vui lòng đăng nhập để xem thông báo.',
                style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                  return _buildEmptyState(primary, soft);
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
                    final iconColor = _iconColorForType(type, isDark, primary);
                    
                    final cardBg = read
                        ? (isDark ? theme.cardColor.withOpacity(0.6) : const Color(0xFFF0F4F8))
                        : (isDark ? theme.cardColor : const Color(0xFFDCEBFB));

                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _markReadIfNeeded(ref, read),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: read ? Colors.transparent : primary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: iconColor.withAlpha(35),
                              child: Icon(_iconForType(type), color: iconColor, size: 18),
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
                                      fontWeight: read ? FontWeight.w600 : FontWeight.w900,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  if (message.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      message,
                                      style: GoogleFonts.lato(
                                        fontSize: 13,
                                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatTime(createdAt),
                                    style: GoogleFonts.lato(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.blueAccent[100] : primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!read)
                              Container(
                                margin: const EdgeInsets.only(top: 5),
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
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