import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/mock_doctors.dart';
import '../data/realtime_doctors_repository.dart';
import 'doctorProfile.dart';

class ExploreList extends StatelessWidget {
  const ExploreList({super.key, required this.type});

  static const Color _primary = Color(0xFF4B5AB5);
  static const Color _lightCard = Color(0xFFE4F2FD);

  final String type;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          type,
          style: GoogleFonts.lato(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: RealtimeDoctorsRepository.streamDoctors(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final fromRealtime = snapshot.data ?? const [];
          final filteredByType = fromRealtime.where((d) {
            final doctorType = (d['type'] ?? '').toString().trim().toLowerCase();
            return doctorType == type.trim().toLowerCase();
          }).toList();
          final source = filteredByType.isNotEmpty ? filteredByType : doctorsByType(type);
          if (source.isEmpty) {
            return const Center(child: Text('Không tìm thấy bác sĩ'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            itemCount: source.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final data = source[index];
              return Material(
                color: _lightCard,
                borderRadius: BorderRadius.circular(10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundImage: (data['image']?.toString().isNotEmpty ?? false)
                        ? NetworkImage(data['image'].toString())
                        : null,
                    child: (data['image']?.toString().isNotEmpty ?? false) ? null : const Icon(Icons.person),
                  ),
                  title: Text(
                    data['name']?.toString() ?? '',
                    style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    data['type']?.toString() ?? '',
                    style: GoogleFonts.lato(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: _primary, size: 18),
                      const SizedBox(width: 2),
                      Text(
                        (data['rating'] ?? '').toString(),
                        style: GoogleFonts.lato(fontSize: 13, color: _primary, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => DoctorProfile(doctor: data['name']?.toString() ?? '')));
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
