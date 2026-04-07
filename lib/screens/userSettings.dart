import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/google_calendar_sync_repository.dart';
import '../firestore-data/userDetails.dart';

import 'signIn.dart';

class UserSettings extends StatelessWidget {
  const UserSettings({super.key});

  // Giữ nguyên các định nghĩa màu gốc làm mặc định cho Light Mode
  static const Color _primaryLight = Color(0xFF4B5AB5);
  static const Color _softLight = Color(0xFFE4F2FD);

  Future<void> _linkCalendar(BuildContext context) async {
    try {
      await GoogleCalendarSyncRepository.instance
          .linkGoogleToCurrentUserForCalendar();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Liên kết Google Calendar thành công')),
      );
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Không thể liên kết Google Calendar'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể liên kết Google Calendar: ${e.toString()}'),
        ),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignIn()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Kiểm tra chế độ tối
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Tự động điều chỉnh màu sắc dựa trên theme
    final primaryColor = isDark
        ? Theme.of(context).colorScheme.primary
        : _primaryLight;
    final softColor = isDark ? Colors.grey.withOpacity(0.15) : _softLight;
    final containerColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      // backgroundColor tự động lấy từ Theme (ScaffoldBackgroundColor)
      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            Colors.transparent, // Trong suốt để ăn theo nền Scaffold
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: primaryColor),
        title: Text(
          'Cài đặt',
          style: GoogleFonts.lato(
            color: primaryColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: softColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 21,
                  backgroundColor: Colors.white24,
                  backgroundImage: AssetImage('assets/person.jpg'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'Người dùng',
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textColor, // Đổi màu theo theme
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Chỉnh sửa hồ sơ',
            style: GoogleFonts.lato(
              color: primaryColor,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: softColor),
            ),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: UserDetails(),
            ),
          ),
          const SizedBox(height: 14),
          StreamBuilder<Map<String, dynamic>?>(
            stream: GoogleCalendarSyncRepository.instance
                .watchCurrentUserCalendarStatus(),
            builder: (context, snapshot) {
              final data = snapshot.data ?? const <String, dynamic>{};
              final linked =
                  data['calendarSyncEnabled'] == true &&
                  data['calendarTokenStatus'] == 'ready';
              final exchanging = data['calendarTokenStatus'] == 'exchanging';
              final googleEmail = data['googleEmail']?.toString() ?? '';
              final calendarError =
                  data['calendarSyncError']?.toString().trim() ?? '';

              final statusText = linked
                  ? 'Đã liên kết với Calendar'
                  : exchanging
                  ? 'Đang liên kết với Calendar...'
                  : 'Chưa liên kết với Calendar';

              final statusColor = linked
                  ? Colors.green.shade400
                  : exchanging
                  ? Colors.orange.shade400
                  : (isDark ? Colors.grey : Colors.grey.shade700);

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: softColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Google Calendar',
                          style: GoogleFonts.lato(
                            color: primaryColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statusText,
                      style: GoogleFonts.lato(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (googleEmail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        googleEmail,
                        style: GoogleFonts.lato(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (!linked && calendarError.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        calendarError,
                        style: GoogleFonts.lato(
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (!linked && !exchanging) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 40,
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _linkCalendar(context),
                          icon: const Icon(Icons.link, size: 18),
                          label: Text(
                            'Liên kết với Google Calendar',
                            style: GoogleFonts.lato(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Material(
            color: isDark
                ? Colors.red.withOpacity(0.15)
                : const Color(0xFFFFECEC),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _logout(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.logout, color: Colors.red, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Đăng xuất',
                      style: GoogleFonts.lato(
                        color: isDark ? Colors.redAccent : Colors.red.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
