import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';

import '../firestore-data/appointmentHistoryList.dart';
import 'userSettings.dart';

class AppointmentHistoryScreen extends StatelessWidget {
  const AppointmentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Lịch sử lịch hẹn',
          style: GoogleFonts.lato(
            color: scheme.onSurface,
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
  static const Color _soft = Color(0xFFE9EEF2);
  static const double _headerHeight = 150;
  static const double _avatarRadius = 58;

  ImageProvider<Object> _avatarProvider(String photoBase64) {
    if (photoBase64.trim().isNotEmpty) {
      try {
        return MemoryImage(base64Decode(photoBase64));
      } catch (_) {
        return const AssetImage('assets/person.jpg');
      }
    }
    return const AssetImage('assets/person.jpg');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    final userDocStream = user == null
        ? const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty()
        : FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userDocStream,
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? const <String, dynamic>{};
            final firestoreName = data['name']?.toString().trim() ?? '';
            final displayName = firestoreName.isNotEmpty
                ? firestoreName
                : (user?.displayName ?? 'Người dùng');
            final firestorePhone = data['phone']?.toString().trim() ?? '';
            final phone = firestorePhone.isNotEmpty
                ? firestorePhone
                : ((user?.phoneNumber?.trim().isNotEmpty ?? false)
                      ? user!.phoneNumber!
                      : 'Chưa có số điện thoại');
            final bio = data['bio']?.toString().trim() ?? '';
            final photoBase64 = data['photoBase64']?.toString() ?? '';

            return ListView(
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
                                icon: const Icon(
                                  Icons.settings,
                                  color: Colors.white,
                                ),
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
                                color: const Color(0xFFE6EFEA),
                                width: 4,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: _avatarRadius,
                              backgroundImage: _avatarProvider(photoBase64),
                              child: displayName.trim().isEmpty
                                  ? Icon(Icons.person, size: _avatarRadius)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            displayName,
                            style: GoogleFonts.lato(
                              fontSize: 29,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _infoCard(
                  height: 112,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _contactRow(
                        context: context,
                        icon: Icons.mail_rounded,
                        iconBg: Colors.red.shade700,
                        text: user?.email ?? 'Chưa có email',
                      ),
                      const SizedBox(height: 10),
                      _contactRow(
                        context: context,
                        icon: Icons.phone,
                        iconBg: Colors.blue.shade700,
                        text: phone,
                      ),
                    ],
                  ),
                ),
                _infoCard(
                  minHeight: 130,
                  child: Column(
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
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 40),
                        child: Text(
                          bio.isEmpty
                              ? 'Hãy cập nhật mô tả của bạn trong phần cài đặt.'
                              : bio,
                          style: GoogleFonts.lato(
                            fontSize: 15,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _infoCard(
                  minHeight: 170,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _smallIcon(Icons.history, Colors.green.shade700),
                          const SizedBox(width: 10),
                          Text(
                            'Lịch sử lịch hẹn',
                            style: GoogleFonts.lato(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AppointmentHistoryScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'Xem tất cả',
                              style: GoogleFonts.lato(
                                color: const Color(0xFF64B5F7),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const AppointmentHistoryList(compactProfileStyle: true),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _infoCard({required Widget child, double? height, double? minHeight}) {
    final box = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
    if (height != null) {
      return SizedBox(height: height, child: box);
    }
    if (minHeight != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: box,
      );
    }
    return box;
  }

  Widget _contactRow({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required String text,
  }) {
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _smallIcon(IconData icon, Color bg) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }
}
