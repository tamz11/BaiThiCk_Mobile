import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart'; // 1. Thêm import này
import '../theme_provider.dart';        // 2. Thêm import này
import '../firestore-data/appointmentHistoryList.dart';
import 'userSettings.dart';

class AppointmentHistoryScreen extends StatelessWidget {
  const AppointmentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Thay Colors.white bằng màu nền hệ thống
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Lịch sử lịch hẹn',
          style: GoogleFonts.lato(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: SingleChildScrollView(
          child: AppointmentHistoryList(compactProfileStyle: false),
        ),
      ),
    );
  }
}

class UserProfile extends StatelessWidget {
  const UserProfile({super.key});

  static const Color _primary = Color(0xFF4B5AB5);
  static const double _headerHeight = 150;
  static const double _avatarRadius = 58;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // 3. Lấy themeProvider để điều khiển nút gạt
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      // Tự động đổi màu nền khi sang Dark Mode
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(15, 0, 15, 10),
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  children: [
                    Container(
                      height: _headerHeight,
                      decoration: const BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8, right: 8),
                          child: IconButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const UserSettings(),
                              ),
                            ),
                            iconSize: 22,
                            icon: const Icon(Icons.settings, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 72),
                  ],
                ),
                Positioned(
                  top: 48,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: themeProvider.isDarkMode ? Colors.grey.shade800 : const Color(0xFFE6EFEA),
                            width: 4,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: _avatarRadius,
                          backgroundImage: const AssetImage('assets/person.jpg'),
                          child: (user?.displayName?.isEmpty ?? true)
                              ? Icon(Icons.person, size: _avatarRadius)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user?.displayName ?? 'Người dùng',
                        style: GoogleFonts.lato(
                          fontSize: 29,
                          fontWeight: FontWeight.w800,
                          // Tự động đổi màu chữ
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // --- GẠT DARK MODE ---
            _infoCard(
              context,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: themeProvider.isDarkMode ? Colors.amber : Colors.orange,
                ),
                title: Text(
                  "Chế độ tối",
                  style: GoogleFonts.lato(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                value: themeProvider.isDarkMode,
                onChanged: (value) {
                  themeProvider.toggleTheme();
                },
              ),
            ),
            // ------------------------------------------

            const SizedBox(height: 10),
            _infoCard(
              context,
              height: 112,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _contactRow(
                    context,
                    icon: Icons.mail_rounded,
                    iconBg: Colors.red.shade700,
                    text: user?.email ?? 'Chưa có email',
                  ),
                  const SizedBox(height: 10),
                  _contactRow(
                    context,
                    icon: Icons.phone,
                    iconBg: Colors.blue.shade700,
                    text: (user?.phoneNumber?.trim().isNotEmpty ?? false)
                        ? user!.phoneNumber!
                        : 'Chưa có số điện thoại',
                  ),
                ],
              ),
            ),
            
            // Các thẻ Info khác...
            _infoCard(
              context,
              minHeight: 130,
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: user == null
                    ? const Stream.empty()
                    : FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                builder: (context, snapshot) {
                  final bio = snapshot.data?.data()?['bio']?.toString().trim() ?? '';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _smallIcon(Icons.edit, Colors.indigo.shade700),
                          const SizedBox(width: 10),
                          Text(
                            'Giới thiệu',
                            style: GoogleFonts.lato(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 40),
                        child: Text(
                          bio.isEmpty ? 'Hãy cập nhật mô tả của bạn.' : bio,
                          style: GoogleFonts.lato(
                            fontSize: 15,
                            color: themeProvider.isDarkMode ? Colors.white70 : Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Cập nhật hàm _infoCard để đổi màu nền thẻ khi sang Dark Mode
  Widget _infoCard(BuildContext context, {required Widget child, double? height, double? minHeight}) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final box = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        // Màu thẻ: Xám đậm trong Dark Mode, Xám nhạt trong Light Mode
        color: isDark ? Colors.grey.shade900 : const Color(0xFFE9EEF2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
    if (height != null) return SizedBox(height: height, child: box);
    if (minHeight != null) return ConstrainedBox(constraints: BoxConstraints(minHeight: minHeight), child: box);
    return box;
  }

  Widget _contactRow(BuildContext context, {required IconData icon, required Color iconBg, required String text}) {
    return Row(
      children: [
        _smallIcon(icon, iconBg),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.lato(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _smallIcon(IconData icon, Color bg) {
    return Container(
      width: 30, height: 30,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15)),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }
}