import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationList extends StatelessWidget {
  const NotificationList({super.key});

  static const Color _primary = Color(0xFF4B5AB5);
  static const Color _soft = Color(0xFFE4F2FD);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          'Thông báo',
          style: GoogleFonts.lato(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _soft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: _primary.withValues(alpha: 0.15),
                child: const Icon(Icons.notifications_none_rounded, color: _primary, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Không có thông báo mới',
                style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
