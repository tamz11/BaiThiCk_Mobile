import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../data/google_calendar_sync_repository.dart';
import '../firestore-data/userDetails.dart';
import '../utils/app_theme_controller.dart';

import 'signIn.dart';

class UserSettings extends StatelessWidget {
  const UserSettings({super.key});

  static const Color _primary = Color(0xFF4B5AB5);
  static const Color _soft = Color(0xFFE4F2FD);

  Future<void> _pickAndSaveAvatar(
    BuildContext context,
    User user,
    ImageSource source,
  ) async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        imageQuality: 60,
        maxWidth: 600,
        maxHeight: 600,
      );

      if (file == null) {
        return;
      }

      final bytes = await file.readAsBytes();
      final encoded = base64Encode(bytes);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'photoBase64': encoded,
      }, SetOptions(merge: true));

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật ảnh đại diện thành công')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật ảnh: ${e.toString()}')),
      );
    }
  }

  void _showAvatarSourcePicker(BuildContext context, User user) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Chọn ảnh từ máy'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndSaveAvatar(context, user, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Chụp ảnh mới'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndSaveAvatar(context, user, ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  ImageProvider<Object> _buildAvatarProvider(String photoBase64) {
    if (photoBase64.trim().isNotEmpty) {
      try {
        return MemoryImage(base64Decode(photoBase64));
      } catch (_) {
        return const AssetImage('assets/person.jpg');
      }
    }
    return const AssetImage('assets/person.jpg');
  }

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
    final scheme = Theme.of(context).colorScheme;
    final userDocStream = user == null
        ? const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty()
        : FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _primary),
        title: Text(
          'Cài đặt',
          style: GoogleFonts.lato(
            color: _primary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userDocStream,
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          final firestoreName = data['name']?.toString().trim() ?? '';
          final displayName = firestoreName.isNotEmpty
              ? firestoreName
              : (user?.displayName ?? 'Người dùng');
          final photoBase64 = data['photoBase64']?.toString() ?? '';

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 21,
                          backgroundColor: Colors.transparent,
                          backgroundImage: _buildAvatarProvider(photoBase64),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: InkWell(
                            onTap: user == null
                                ? null
                                : () => _showAvatarSourcePicker(context, user),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_outlined,
                                size: 13,
                                color: _primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: GoogleFonts.lato(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
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
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _soft),
                ),
                child: ValueListenableBuilder<ThemeMode>(
                  valueListenable: AppThemeController.instance.mode,
                  builder: (context, mode, _) {
                    final isDarkMode = mode == ThemeMode.dark;
                    return SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      secondary: const Icon(
                        Icons.dark_mode_outlined,
                        color: _primary,
                      ),
                      title: Text(
                        'Chế độ tối',
                        style: GoogleFonts.lato(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        'Bật/tắt giao diện tối',
                        style: GoogleFonts.lato(fontSize: 12),
                      ),
                      value: isDarkMode,
                      onChanged: (value) {
                        AppThemeController.instance.setDarkMode(value);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Chỉnh sửa hồ sơ',
                style: GoogleFonts.lato(
                  color: _primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: UserDetails(
                    onEditAvatar: user == null
                        ? null
                        : () => _showAvatarSourcePicker(context, user),
                  ),
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
                  final exchanging =
                      data['calendarTokenStatus'] == 'exchanging';
                  final googleEmail = data['googleEmail']?.toString() ?? '';
                  final calendarError =
                      data['calendarSyncError']?.toString().trim() ?? '';

                  final statusText = linked
                      ? 'Đã liên kết với Calendar'
                      : exchanging
                      ? 'Đang liên kết với Calendar...'
                      : 'Chưa liên kết với Calendar';

                  final statusColor = linked
                      ? Colors.green.shade700
                      : exchanging
                      ? Colors.orange.shade700
                      : Colors.grey.shade700;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_month,
                              color: _primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Google Calendar',
                              style: GoogleFonts.lato(
                                color: _primary,
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
                              color: scheme.onSurfaceVariant,
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
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (!linked && !exchanging) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 40,
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
                                backgroundColor: _primary,
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
                color: const Color(0xFFFFECEC),
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
                            color: Colors.red.shade700,
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
          );
        },
      ),
    );
  }
}
