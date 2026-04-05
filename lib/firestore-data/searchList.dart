import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/doctor_type_utils.dart';     // ← canonicalType dùng chung
import '../data/mock_doctors.dart';
import '../data/realtime_doctors_repository.dart';
import '../screens/doctorProfile.dart';

// ─────────────────────────────────────────────
// Widget danh sách kết quả tìm kiếm
//
// Chế độ:
//   embedded = true  → nhúng vào màn hình khác (không có Scaffold riêng)
//   embedded = false → màn hình độc lập với AppBar (mặc định)
//
// Tham số lọc:
//   searchKey  = từ khóa tên bác sĩ
//   typeFilter = tên chuyên khoa (tiếng Anh hoặc tiếng Việt đều được,
//                vì đã dùng canonicalType() để so sánh)
// ─────────────────────────────────────────────
class SearchList extends StatelessWidget {
  const SearchList({
    super.key,
    required this.searchKey,
    this.typeFilter = '',
    this.embedded   = false,
  });

  final String searchKey;
  final String typeFilter;
  final bool   embedded;

  static const Color _primary   = Color(0xFF4B5AB5);
  static const Color _lightCard = Color(0xFFE8F0FE);

  // ── Lọc danh sách ─────────────────────────────────────────────────────────
  // FIX: dùng canonicalType() thay vì so sánh string thẳng.
  //      typeFilter có thể là 'Dentist', 'Răng hàm mặt', hay 'Nha khoa'
  //      — tất cả đều resolve về cùng slug 'rang_ham_mat'.
  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> source) {
    final nameKey    = searchKey.trim().toLowerCase();
    final targetSlug = canonicalType(typeFilter); // slug của filter

    return source.where((d) {
      final name   = (d['name'] ?? '').toString().toLowerCase();
      final dbType = (d['type'] ?? '').toString().trim();

      final nameOk = nameKey.isEmpty    || name.contains(nameKey);
      final typeOk = typeFilter.isEmpty ||
                     canonicalType(dbType) == targetSlug; // ← FIX

      return nameOk && typeOk;
    }).toList();
  }

  // ── Trạng thái rỗng ───────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded,
              size: 64, color: Color(0xFFD0D5E8)),
          const SizedBox(height: 12),
          Text(
            'Không tìm thấy bác sĩ',
            style: GoogleFonts.lato(
              color: _primary, fontSize: 17, fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Thử từ khóa khác',
            style: GoogleFonts.lato(color: Colors.black38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Card một bác sĩ ───────────────────────────────────────────────────────
  Widget _buildCard(BuildContext context, Map<String, dynamic> data) {
    final name   = data['name']?.toString()  ?? 'Bác sĩ';
    final type   = data['type']?.toString()  ?? '';
    final image  = data['image']?.toString() ?? '';
    final rating = (data['rating'] is num)
        ? (data['rating'] as num).toDouble()
        : 0.0;
    final ratingLabel = (rating == rating.roundToDouble())
        ? rating.toInt().toString()
        : rating.toStringAsFixed(1);

    return Material(
      color       : _lightCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DoctorProfile(
              doctor    : name,
              doctorData: data,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius         : 26,
                backgroundColor: Colors.white,
                backgroundImage:
                    image.isNotEmpty ? NetworkImage(image) : null,
                child: image.isNotEmpty
                    ? null
                    : Icon(Icons.person_rounded, color: _primary, size: 26),
              ),
              const SizedBox(width: 14),

              // Tên + chuyên khoa
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment : MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      maxLines : 1,
                      overflow : TextOverflow.ellipsis,
                      style    : GoogleFonts.lato(
                        fontSize  : 16,
                        fontWeight: FontWeight.w700,
                        color     : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      type,
                      maxLines : 1,
                      overflow : TextOverflow.ellipsis,
                      style    : GoogleFonts.lato(
                        fontSize: 14, color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Rating
              Row(
                children: [
                  Icon(Icons.star_rounded, color: _primary, size: 18),
                  const SizedBox(width: 3),
                  Text(
                    ratingLabel,
                    style: GoogleFonts.lato(
                      color     : _primary,
                      fontSize  : 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Nội dung danh sách ────────────────────────────────────────────────────
  Widget _buildBody(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream : RealtimeDoctorsRepository.streamDoctors(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final raw      = snapshot.data ?? const [];
        final source   = raw.isNotEmpty ? raw : mockDoctors;
        final filtered = _filter(source);

        if (filtered.isEmpty) return _buildEmptyState();

        return Scrollbar(
          child: ListView.separated(
            padding         : const EdgeInsets.fromLTRB(0, 4, 0, 16),
            itemCount       : filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder     : (ctx, i) => _buildCard(ctx, filtered[i]),
          ),
        );
      },
    );
  }

  // ── Build: embedded hay standalone ────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (embedded) return _buildBody(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor : Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          searchKey.isNotEmpty
              ? 'Kết quả: $searchKey'
              : 'Danh sách bác sĩ',
          style: GoogleFonts.lato(
            color     : Colors.black87,
            fontSize  : 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child  : _buildBody(context),
      ),
    );
  }
}
