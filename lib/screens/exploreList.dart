import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/mock_doctors.dart';
import '../data/realtime_doctors_repository.dart';
import '../utils/specialty_text.dart';
import 'doctorProfile.dart';

class ExploreList extends StatelessWidget {
  const ExploreList({super.key, required this.type});

  static const Color _primary = Color(0xFF4B5AB5);
  static const Color _lightCard = Color(0xFFE4F2FD);

  final String type;

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
    if (t.contains('tim')) return 'tim_mach';
    if (t.contains('rang') || t.contains('nha') || t.contains('ham'))
      return 'rang_ham_mat';
    if (t == 'mat' || t.contains('eye')) return 'mat';
    if (t.contains('co xuong') ||
        t.contains('khop') ||
        t.contains('orthopaedic'))
      return 'co_xuong_khop';
    if (t.contains('nhi') || t.contains('tre') || t.contains('paediatric'))
      return 'nhi_khoa';
    return t;
  }

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
          type,
          style: GoogleFonts.lato(
            color: scheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: RealtimeDoctorsRepository.fetchDoctors(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final fromRealtime = snapshot.hasError
              ? <Map<String, dynamic>>[]
              : List<Map<String, dynamic>>.from(snapshot.data ?? const []);
          final targetType = _canonicalType(type);
          final filteredByType = fromRealtime.where((d) {
            final doctorType = _canonicalType((d['type'] ?? '').toString());
            return doctorType == targetType;
          }).toList();
          final source = filteredByType.isNotEmpty
              ? filteredByType
              : doctorsByType(type);
          if (source.isEmpty) {
            return const Center(child: Text('Không tìm thấy bác sĩ'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            itemCount: source.length,
            separatorBuilder: (_, index) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final data = source[index];
              return Material(
                color: _lightCard,
                borderRadius: BorderRadius.circular(10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundImage:
                        (data['image']?.toString().isNotEmpty ?? false)
                        ? NetworkImage(data['image'].toString())
                        : null,
                    child: (data['image']?.toString().isNotEmpty ?? false)
                        ? null
                        : const Icon(Icons.person),
                  ),
                  title: Text(
                    data['name']?.toString() ?? '',
                    style: GoogleFonts.lato(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    toVietnameseSpecialty(data['type']?.toString() ?? ''),
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: _primary, size: 18),
                      const SizedBox(width: 2),
                      Text(
                        (data['rating'] ?? '').toString(),
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          color: _primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DoctorProfile(
                          doctor: data['name']?.toString() ?? '',
                          doctorData: data,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
