import 'package:flutter/material.dart';

import 'doctorProfile.dart';

class DoctorDetailScreen extends StatelessWidget {
  const DoctorDetailScreen({
    super.key,
    required this.doctor,
  });

  final dynamic doctor;

  String _doctorName(dynamic value) {
    if (value is String) {
      return value;
    }
    try {
      final name = value?.name?.toString();
      if (name != null && name.isNotEmpty) {
        return name;
      }
    } catch (_) {}
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return DoctorProfile(doctor: _doctorName(doctor));
  }
}
