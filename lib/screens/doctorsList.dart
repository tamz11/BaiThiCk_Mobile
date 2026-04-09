import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/realtime_doctors_repository.dart';
import '../utils/specialty_text.dart';
import 'doctorProfile.dart';

// ─────────────────────────────────────────────
// Màn hình danh sách bác sĩ – tìm kiếm & lọc
// ─────────────────────────────────────────────
class DoctorsList extends StatefulWidget {
  const DoctorsList({super.key});

  @override
  State<DoctorsList> createState() => _DoctorsListState();
}

class _DoctorsListState extends State<DoctorsList> {
  // ── Màu sắc ──────────────────────────────
  static const Color _primary = Color(0xFF4B5AB5);
  static const Color _lightCard = Color(0xFFE8F0FE);
  static const Color _neutral = Color(0xFFD6D6D6);

  // ── Chuyên khoa: tên hiển thị → giá trị 'type' trong DB ─────────────────
  static const Map<String, String> _specialtyMap = {
    'Tất cả': '',
    'Tim mạch': 'tim_mach',
    'Nha khoa': 'rang_ham_mat',
    'Mắt': 'mat',
    'Cơ xương khớp': 'co_xuong_khop',
    'Nhi khoa': 'nhi_khoa',
    'Sản phụ khoa': 'san_phu_khoa',
    'Nội tiết': 'noi_tiet',
    'Tiêu hóa': 'tieu_hoa',
    'Hô hấp': 'ho_hap',
  };

  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  String _activeType = ''; // '' = tất cả chuyên khoa

  String _normalizeVietnamese(String input) {
    final source = input.trim().toLowerCase();
    if (source.isEmpty) return '';
    const from =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const to =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    final out = StringBuffer();
    for (final rune in source.runes) {
      final ch = String.fromCharCode(rune);
      final idx = from.indexOf(ch);
      out.write(idx >= 0 ? to[idx] : ch);
    }
    return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _canonicalType(String raw) {
    final t = _normalizeVietnamese(raw);
    if (t.contains('tim') || t.contains('cardio')) return 'tim_mach';
    if (t.contains('rang') ||
        t.contains('nha') ||
        t.contains('dentist') ||
        t.contains('ham')) {
      return 'rang_ham_mat';
    }
    if (t == 'mat' || t.contains('eye')) return 'mat';
    if (t.contains('co xuong') ||
        t.contains('khop') ||
        t.contains('orthopaedic')) {
      return 'co_xuong_khop';
    }
    if (t.contains('nhi') || t.contains('paediatric') || t.contains('tre')) {
      return 'nhi_khoa';
    }
    if (t.contains('san') ||
        t.contains('phu khoa') ||
        t.contains('obstetric') ||
        t.contains('gyne')) {
      return 'san_phu_khoa';
    }
    if (t.contains('noi tiet') || t.contains('endocr')) {
      return 'noi_tiet';
    }
    if (t.contains('tieu hoa') || t.contains('gastro')) {
      return 'tieu_hoa';
    }
    if (t.contains('ho hap') || t.contains('respir')) {
      return 'ho_hap';
    }
    return t;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Lọc theo tên + chuyên khoa ───────────────────────────────────────────
  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> all) {
    final key = _searchText.toLowerCase();
    return all.where((d) {
      final name = (d['name'] ?? '').toString().toLowerCase();
      final type = _canonicalType((d['type'] ?? '').toString());
      final nameOk = key.isEmpty || name.contains(key);
      final typeOk = _activeType.isEmpty || type == _activeType;
      return nameOk && typeOk;
    }).toList();
  }

  // ── AppBar với ô tìm kiếm ────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 68,
      titleSpacing: 14,
      title: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onChanged: (v) => setState(() => _searchText = v.trim()),
        style: GoogleFonts.lato(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: 'Tìm bác sĩ theo tên...',
          hintStyle: GoogleFonts.lato(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black38,
          ),
          filled: true,
          fillColor: _neutral.withOpacity(0.35),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.black45),
          suffixIcon: _searchText.isNotEmpty
              ? IconButton(
                  onPressed: () => setState(() {
                    _searchController.clear();
                    _searchText = '';
                  }),
                  icon: const Icon(Icons.close_rounded, color: Colors.black45),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  // ── Chip lọc chuyên khoa ─────────────────────────────────────────────────
  Widget _buildSpecialtyChips() {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        itemCount: _specialtyMap.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final label = _specialtyMap.keys.elementAt(i);
          final typeVal = _specialtyMap.values.elementAt(i);
          final selected = _activeType == typeVal;
          return FilterChip(
            label: Text(
              label,
              style: GoogleFonts.lato(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : _primary,
              ),
            ),
            selected: selected,
            onSelected: (_) => setState(() => _activeType = typeVal),
            backgroundColor: scheme.surface,
            selectedColor: _primary,
            checkmarkColor: Colors.white,
            showCheckmark: false,
            side: BorderSide(color: selected ? _primary : _neutral, width: 1.2),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        },
      ),
    );
  }

  // ── Trạng thái rỗng ──────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 72,
            color: Color(0xFFD0D5E8),
          ),
          const SizedBox(height: 14),
          Text(
            'Không tìm thấy bác sĩ',
            style: GoogleFonts.lato(
              color: _primary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Thử tìm với từ khóa hoặc chuyên khoa khác',
            style: GoogleFonts.lato(color: Colors.black38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDataError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 70,
              color: Color(0xFFD0D5E8),
            ),
            const SizedBox(height: 14),
            Text(
              'Không tải được danh sách bác sĩ từ Realtime Database',
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(
                color: _primary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error?.toString() ?? 'Lỗi không xác định',
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(color: Colors.black45, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSpecialtyChips(),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: RealtimeDoctorsRepository.streamDoctors(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _buildDataError(snapshot.error);
                }
                final source = snapshot.data ?? const <Map<String, dynamic>>[];
                final filtered = _applyFilters(source);

                if (filtered.isEmpty) return _buildEmptyState();

                return Scrollbar(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _DoctorCard(
                      data: filtered[i],
                      primary: _primary,
                      lightCard: scheme.surfaceContainerLow,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Widget card cho một bác sĩ
// ─────────────────────────────────────────────
class _DoctorCard extends StatelessWidget {
  const _DoctorCard({
    required this.data,
    required this.primary,
    required this.lightCard,
  });

  final Map<String, dynamic> data;
  final Color primary;
  final Color lightCard;

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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = data['name']?.toString() ?? 'Bác sĩ';
    final type = toVietnameseSpecialty(data['type']?.toString() ?? '');
    final image = _extractAvatarPath(data);
    final address = data['address']?.toString() ?? '';
    final open = data['openHour']?.toString() ?? '';
    final close = data['closeHour']?.toString() ?? '';
    final rating = (data['rating'] is num)
        ? (data['rating'] as num).toDouble()
        : 0.0;

    return Material(
      color: lightCard,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DoctorProfile(doctor: name)),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Avatar ──────────────────────────
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  child: ClipOval(
                    child: image.isNotEmpty
                        ? Image.network(
                            image,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return Image.asset(
                                'assets/person.jpg',
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              );
                            },
                          )
                        : Image.asset(
                            'assets/person.jpg',
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // ── Thông tin ──────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lato(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Badge chuyên khoa
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        type,
                        style: GoogleFonts.lato(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 12,
                            color: Colors.black38,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.lato(
                                fontSize: 11,
                                color: Colors.black38,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (open.isNotEmpty && close.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: Colors.black38,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$open – $close',
                            style: GoogleFonts.lato(
                              fontSize: 11,
                              color: Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // ── Rating ─────────────────────────
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _RatingBadge(rating: rating, primary: primary),
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFBBBBBB),
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Badge hiển thị điểm đánh giá
// ─────────────────────────────────────────────
class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating, required this.primary});
  final double rating;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final label = (rating == rating.roundToDouble())
        ? rating.toInt().toString()
        : rating.toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: primary, size: 15),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.lato(
              color: primary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
