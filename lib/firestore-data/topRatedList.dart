import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:typicons_flutter/typicons_flutter.dart';

import '../data/mock_doctors.dart';
import '../data/realtime_doctors_repository.dart';
import '../screens/doctorProfile.dart';
import '../utils/specialty_text.dart';

class TopRatedList extends StatefulWidget {
  const TopRatedList({super.key});

  @override
  State<TopRatedList> createState() => _TopRatedListState();
}

class _TopRatedListState extends State<TopRatedList> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: RealtimeDoctorsRepository.fetchDoctors(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final fromRealtime = snapshot.hasError
            ? <Map<String, dynamic>>[]
            : List<Map<String, dynamic>>.from(snapshot.data ?? const []);
        fromRealtime.sort((a, b) {
          final ar = (a['rating'] is num) ? (a['rating'] as num).toDouble() : 0;
          final br = (b['rating'] is num) ? (b['rating'] as num).toDouble() : 0;
          return br.compareTo(ar);
        });
        final fromTopFive = fromRealtime.take(5).toList();
        final source = fromTopFive.isNotEmpty
            ? fromTopFive
            : topRatedDoctors(5);
        if (source.isEmpty) {
          return const Center(child: Text('Không tìm thấy bác sĩ'));
        }
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: source.length,
          itemBuilder: (context, index) {
            final data = source[index];
            return Padding(
              padding: const EdgeInsets.only(top: 3.0),
              child: Card(
                color: scheme.surfaceVariant,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Container(
                  padding: EdgeInsets.only(left: 10, right: 10, top: 0),
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height / 9,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurface, // màu text button
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DoctorProfile(
                            doctor: data['name']?.toString() ?? '',
                            doctorData: data,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundImage:
                              (data['image']?.toString().isNotEmpty ?? false)
                              ? NetworkImage(data['image'].toString())
                              : null,
                          radius: 25,
                          backgroundColor: scheme.primaryContainer,
                          child: (data['image']?.toString().isNotEmpty ?? false)
                              ? null
                              : const Icon(Icons.person),
                        ),
                        SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                data['name']?.toString() ?? 'Bác sĩ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.lato(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: scheme.onSurface,
                                ),
                              ),
                              Text(
                                toVietnameseSpecialty(
                                  data['type']?.toString() ?? '',
                                ),
                                style: GoogleFonts.lato(
                                  fontSize: 16,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(
                              Typicons.star_full_outline,
                              size: 20,
                              color: scheme.secondary,
                            ),
                            SizedBox(width: 3),
                            Text(
                              (data['rating'] ?? '').toString(),
                              style: GoogleFonts.lato(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: scheme.secondary,
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
        );
      },
    );
  }
}
