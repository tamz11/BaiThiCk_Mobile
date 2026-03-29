import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/mock_doctors.dart';
import '../data/realtime_doctors_repository.dart';
import 'bookingScreen.dart';

class DoctorProfile extends StatelessWidget {
  const DoctorProfile({super.key, this.doctor = ''});

  static const Color _primary = Colors.indigo;
  static const Color _accent = Colors.indigoAccent;

  final String doctor;

  Future<void> _launchCaller(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: RealtimeDoctorsRepository.streamDoctors(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final fromRealtime = snapshot.data ?? const [];
            final key = doctor.trim().toLowerCase();
            final matched = fromRealtime.where((d) {
              final name = (d['name'] ?? '').toString().trim().toLowerCase();
              return name == key;
            }).toList();
            final data = matched.isNotEmpty ? matched.first : doctorByName(doctor);
            if (data == null) {
              return const Center(child: Text('Không tìm thấy bác sĩ'));
            }
            final rating = (data['rating'] is num) ? (data['rating'] as num).toInt().clamp(0, 5) : 0;
            return NotificationListener<OverscrollIndicatorNotification>(
              onNotification: (notification) {
                notification.disallowIndicator();
                return true;
              },
              child: ListView(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    child: Column(
                      children: <Widget>[
                        Container(
                          alignment: Alignment.centerLeft,
                          height: 50,
                          width: MediaQuery.of(context).size.width,
                          padding: const EdgeInsets.only(left: 5),
                          child: IconButton(
                            icon: const Icon(
                              Icons.chevron_left_sharp,
                              color: _primary,
                              size: 30,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        CircleAvatar(
                          backgroundImage: (data['image']?.toString().isNotEmpty ?? false)
                              ? NetworkImage(data['image'].toString())
                              : null,
                          radius: 80,
                          child: (data['image']?.toString().isNotEmpty ?? false) ? null : const Icon(Icons.person, size: 64),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          data['name']?.toString() ?? 'Bác sĩ',
                          style: GoogleFonts.lato(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          data['type']?.toString() ?? '',
                          style: GoogleFonts.lato(
                            fontSize: 18,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < rating; i++)
                              const Icon(
                                Icons.star_rounded,
                                color: _accent,
                                size: 30,
                              ),
                            if (5 - rating > 0)
                              for (var i = 0; i < 5 - rating; i++)
                                const Icon(
                                  Icons.star_rounded,
                                  color: Colors.black12,
                                  size: 30,
                                ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.only(left: 22, right: 22),
                          alignment: Alignment.center,
                          child: Text(
                            data['specification']?.toString() ?? '',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: MediaQuery.of(context).size.width,
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(width: 15),
                              const Icon(Icons.place_outlined),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Text(
                                  data['address']?.toString() ?? '',
                                  style: GoogleFonts.lato(fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                          ),
                        ),
                        Container(
                          height: MediaQuery.of(context).size.height / 12,
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              const SizedBox(width: 15),
                              const Icon(Icons.phone_in_talk),
                              const SizedBox(width: 11),
                              TextButton(
                                onPressed: () => _launchCaller(data['phone']?.toString() ?? ''),
                                child: Text(
                                  data['phone']?.toString() ?? '',
                                  style: GoogleFonts.lato(fontSize: 16, color: Colors.blue),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              const SizedBox(width: 15),
                              const Icon(Icons.access_time_rounded),
                              const SizedBox(width: 20),
                              Text(
                                'Giờ làm việc',
                                style: GoogleFonts.lato(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          padding: const EdgeInsets.only(left: 60),
                          child: Row(
                            children: [
                              Text(
                                'Hôm nay:',
                                style: GoogleFonts.lato(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${data['openHour'] ?? ''} - ${data['closeHour'] ?? ''}',
                                style: GoogleFonts.lato(fontSize: 17),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 50),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 30),
                          height: 50,
                          width: MediaQuery.of(context).size.width,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              elevation: 2,
                              backgroundColor: _primary.withValues(alpha: 0.9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32.0),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BookingScreen(
                                    doctor: data['name']?.toString() ?? '',
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              'Đặt lịch khám',
                              style: GoogleFonts.lato(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
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
