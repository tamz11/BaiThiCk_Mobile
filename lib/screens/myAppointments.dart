import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../firestore-data/myAppointmentList.dart';

class MyAppointments extends StatelessWidget {
  const MyAppointments({super.key});

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
          'Lịch hẹn của tôi',
          style: GoogleFonts.lato(
            color: scheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(children: [Expanded(child: MyAppointmentList())]),
      ),
    );
  }
}
