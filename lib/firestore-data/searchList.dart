import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/realtime_doctors_repository.dart';
import '../screens/doctorProfile.dart';

class SearchList extends StatefulWidget {
  const SearchList({
    super.key,
    required this.searchKey,
    this.embedded = false,
  });

  final String searchKey;
  final bool embedded;

  @override
  State<SearchList> createState() => _SearchListState();
}

class _SearchListState extends State<SearchList> {
  static const Color _primary = Color(0xFF4B5AB5);
  static const Color _lightCard = Color(0xFFE4F2FD);

  @override
  Widget build(BuildContext context) {
    final queryKey = widget.searchKey.trim();
    final normalizedQuery = queryKey.toLowerCase();
    final body = StreamBuilder<List<Map<String, dynamic>>>(
      stream: RealtimeDoctorsRepository.streamDoctors(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final fromRealtime = snapshot.data ?? const [];
        final source = normalizedQuery.isEmpty
            ? fromRealtime
            : fromRealtime.where((d) {
                final name = (d['name'] ?? '').toString().toLowerCase();
                return name.contains(normalizedQuery);
              }).toList();

        if (source.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Không tìm thấy bác sĩ',
                  style: GoogleFonts.lato(
                    color: _primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Image.asset('assets/error-404.jpg', width: 150, height: 150),
              ],
            ),
          );
        }

        return Scrollbar(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
            itemCount: source.length,
            separatorBuilder: (_, __) => const SizedBox(height: 9),
            itemBuilder: (context, index) {
              final data = source[index];
              final rating = (data['rating'] is num) ? (data['rating'] as num).toDouble() : 0;
              final doctorName = data['name']?.toString() ?? 'Bác sĩ';
              final doctorType = data['type']?.toString() ?? '';
              final image = data['image']?.toString() ?? '';

              return SizedBox(
                height: MediaQuery.of(context).size.height / 9,
                child: Material(
                  color: _lightCard,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DoctorProfile(doctor: doctorName)),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.white,
                            backgroundImage: image.isNotEmpty ? NetworkImage(image) : null,
                            child: image.isNotEmpty ? null : const Icon(Icons.person, color: _primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  doctorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.lato(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  doctorType,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.lato(
                                    fontSize: 16,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, color: _primary, size: 20),
                              const SizedBox(width: 3),
                              Text(
                                rating == rating.toInt() ? rating.toInt().toString() : rating.toStringAsFixed(1),
                                style: GoogleFonts.lato(
                                  color: _primary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(title: Text('Kết quả: $queryKey')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: body,
      ),
    );
  }
}
