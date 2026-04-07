import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/mock_doctors.dart';
import '../data/realtime_doctors_repository.dart';
import '../utils/specialty_text.dart';
import 'bookingScreen.dart';

// ─────────────────────────────────────────────
// Màn hình chi tiết bác sĩ
// ─────────────────────────────────────────────
class DoctorProfile extends StatelessWidget {
  const DoctorProfile({super.key, this.doctor = '', this.doctorData});

  static const Color _primary = Color(0xFF4B5AB5);
  static const Color _accent = Color(0xFF7986CB);

  final String doctor;
  final Map<String, dynamic>? doctorData;

  String _extractAvatarPath(Map<String, dynamic> src) {
    const keys = <String>[
      'image',
      'avatar',
      'avatarUrl',
      'imageUrl',
      'photoUrl',
      'photo',
    ];
    for (final key in keys) {
      final value = src[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  Future<void> _dial(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _mail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ── Ngôi sao đánh giá ────────────────────────────────────────────────────
  Widget _buildStars(BuildContext context, int rating) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          color: i < rating ? _accent : Colors.black12,
          size: 28,
        );
      }),
    );
  }

  // ── Hàng thông tin (icon + text) ─────────────────────────────────────────
  Widget _infoRow({
    required BuildContext context,
    required IconData icon,
    required String text,
    VoidCallback? onTap,
    Color? textColor,
  }) {
    final defaultTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: _primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.lato(
                  fontSize: 15,
                  color: textColor ?? Colors.black87,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Nhãn thông tin dạng chip ──────────────────────────────────────────────
  Widget _infoBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.lato(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: RealtimeDoctorsRepository.fetchDoctorByIdentity(
            id: doctorData?['id']?.toString(),
            name: doctorData?['name']?.toString() ?? doctor,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data ?? doctorData ?? doctorByName(doctor);
            if (data == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.person_off_outlined,
                      size: 64,
                      color: Color(0xFFD0D5E8),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Không tìm thấy bác sĩ',
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            final name = data['name']?.toString() ?? 'Bác sĩ';
            final type = toVietnameseSpecialty(data['type']?.toString() ?? '');
            final phone = data['phone']?.toString() ?? '';
            final email = data['email']?.toString() ?? '';
            final address = data['address']?.toString() ?? '';
            final spec = data['specification']?.toString() ?? '';
            final open = data['openHour']?.toString() ?? '';
            final close = data['closeHour']?.toString() ?? '';
            final image = _extractAvatarPath(data);
            final rating = (data['rating'] is num)
                ? (data['rating'] as num).toInt().clamp(0, 5)
                : 0;

            return NotificationListener<OverscrollIndicatorNotification>(
              onNotification: (n) {
                n.disallowIndicator();
                return true;
              },
              child: CustomScrollView(
                slivers: [
                  // ── SliverAppBar với gradient ─────────────────────────────
                  SliverAppBar(
                    expandedHeight: 220,
                    pinned: true,
                    backgroundColor: theme.scaffoldBackgroundColor,
                    surfaceTintColor: theme.scaffoldBackgroundColor,
                    elevation: 0,
                    leading: IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,color: isDark ? Colors.white : _primary,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _primary.withOpacity(0.08),
                              _accent.withOpacity(0.14),
                            ],
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            // Avatar
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _primary.withOpacity(0.20),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 52,
                                backgroundColor: Colors.white,
                                child: ClipOval(
                                  child: image.isNotEmpty
                                      ? Image.network(
                                          image,
                                          width: 104,
                                          height: 104,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) {
                                            return Image.asset(
                                              'assets/person.jpg',
                                              width: 104,
                                              height: 104,
                                              fit: BoxFit.cover,
                                            );
                                          },
                                        )
                                      : Image.asset(
                                          'assets/person.jpg',
                                          width: 104,
                                          height: 104,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Nội dung chi tiết ─────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                      child: Column(
                        children: [
                          // Tên
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.lato(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Badge chuyên khoa
                          if (type.isNotEmpty) _infoBadge(type),

                          const SizedBox(height: 12),

                          // Đánh giá sao
                          _buildStars(context, rating),

                          const SizedBox(height: 6),
                          Text(
                            '$rating / 5',
                            style: GoogleFonts.lato(
                              fontSize: 13,
                              color: theme.textTheme.bodyLarge?.color?.withOpacity(0.6),
                            ),
                          ),

                          const SizedBox(height: 20),
                          _buildStars(context, rating),
                          
                          const Divider(),

                          // Mô tả chuyên môn
                          if (spec.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Chuyên môn',
                                style: GoogleFonts.lato(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: theme.textTheme.bodyLarge?.color?.withOpacity(0.6),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F6FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                spec,
                                style: GoogleFonts.lato(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Thông tin liên hệ & thời gian
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Thông tin',
                              style: GoogleFonts.lato(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: theme.textTheme.bodyLarge?.color?.withOpacity(0.6),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFEEEEEE),
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                if (address.isNotEmpty)
                                  _infoRow(
                                    context: context,
                                    icon: Icons.place_outlined,
                                    text: address,
                                  ),
                                if (phone.isNotEmpty) ...[
                                  const Divider(
                                    height: 1,
                                    indent: 20,
                                    endIndent: 20,
                                  ),
                                  _infoRow(
                                    context: context,
                                    icon: Icons.phone_in_talk_rounded,
                                    text: phone,
                                    textColor: Colors.blue[700],
                                    onTap: () => _dial(phone),
                                  ),
                                ],
                                if (email.isNotEmpty) ...[
                                  const Divider(
                                    height: 1,
                                    indent: 20,
                                    endIndent: 20,
                                  ),
                                  _infoRow(
                                    context: context,
                                    icon: Icons.email_outlined,
                                    text: email,
                                    textColor: Colors.blue[700],
                                    onTap: () => _mail(email),
                                  ),
                                ],
                                if (open.isNotEmpty && close.isNotEmpty) ...[
                                  const Divider(
                                    height: 1,
                                    indent: 20,
                                    endIndent: 20,
                                  ),
                                  _infoRow(
                                    context: context,
                                    icon: Icons.access_time_rounded,
                                    text: 'Hôm nay: $open – $close',
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Nút đặt lịch khám
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              icon: const Icon(
                                Icons.calendar_month_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              label: Text(
                                'Đặt lịch khám',
                                style: GoogleFonts.lato(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BookingScreen(
                                    doctor: data['name']?.toString() ?? '',
                                    doctorData: data,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
