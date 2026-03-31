import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../data/appointment_slots_repository.dart';
import '../data/google_calendar_api_client.dart';
import '../data/google_calendar_sync_repository.dart';
import '../data/realtime_doctors_repository.dart';
import '../model/appointment_status.dart';
import 'myAppointments.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, this.doctor = ''});

  final String doctor;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  static const Color _primary = Color(0xFF3949AB);
  static const Color _surface = Color(0xFFF4F7FF);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  late final TextEditingController _doctorController;
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();

  final FocusNode _f1 = FocusNode();
  final FocusNode _f2 = FocusNode();
  final FocusNode _f3 = FocusNode();
  final FocusNode _f4 = FocusNode();
  final FocusNode _f5 = FocusNode();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _doctorId = '';
  String _openHour = '08:00';
  String _closeHour = '17:00';
  bool _loadingDoctorMeta = false;
  bool _loadingAvailability = false;
  bool _isSubmitting = false;
  List<TimeOfDay> _dailySlots = const [];
  Set<String> _bookedSlotKeys = const {};

  @override
  void initState() {
    super.initState();
    _doctorController = TextEditingController(text: widget.doctor);
    _doctorId = AppointmentSlotsRepository.normalizeDoctorId(widget.doctor);
    _initDoctorMeta();
  }

  Future<void> _initDoctorMeta() async {
    setState(() {
      _loadingDoctorMeta = true;
    });

    try {
      final doctor = await RealtimeDoctorsRepository.fetchDoctorByExactName(
        widget.doctor,
      );
      if (!mounted) return;
      setState(() {
        _doctorId = AppointmentSlotsRepository.normalizeDoctorId(
          widget.doctor,
          explicitId: doctor?['id']?.toString(),
        );
        _openHour = doctor?['openHour']?.toString().trim().isNotEmpty == true
            ? doctor!['openHour'].toString().trim()
            : _openHour;
        _closeHour = doctor?['closeHour']?.toString().trim().isNotEmpty == true
            ? doctor!['closeHour'].toString().trim()
            : _closeHour;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingDoctorMeta = false;
        });
      }
      if (_selectedDate != null) {
        await _loadAvailability(_selectedDate!);
      }
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    setState(() {
      _selectedDate = date;
      _selectedTime = null;
      _dateController.text = DateFormat('dd-MM-yyyy').format(date);
      _timeController.clear();
    });
    await _loadAvailability(date);
  }

  Future<void> _loadAvailability(DateTime date) async {
    setState(() {
      _loadingAvailability = true;
    });

    final user = _auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _dailySlots = const [];
        _bookedSlotKeys = const {};
        _loadingAvailability = false;
      });
      return;
    }

    final slots = AppointmentSlotsRepository.buildDailySlots(
      date: date,
      openHour: _openHour,
      closeHour: _closeHour,
    );
    final booked = await AppointmentSlotsRepository.fetchUserConfirmedSlotKeys(
      firestore: _firestore,
      uid: user.uid,
      date: date,
    );

    if (!mounted) return;
    setState(() {
      _dailySlots = slots;
      _bookedSlotKeys = booked;
      _loadingAvailability = false;
    });
  }

  bool _isSlotUnavailable(TimeOfDay slot) {
    final date = _selectedDate;
    if (date == null) return true;

    final key = AppointmentSlotsRepository.slotKeyFromTime(slot);
    if (_bookedSlotKeys.contains(key)) return true;
    return AppointmentSlotsRepository.isPastSlot(date, slot);
  }

  String _formatSlot(TimeOfDay slot) {
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(slot, alwaysUse24HourFormat: true);
  }

  void _pickQuickSlot(TimeOfDay slot) {
    if (_isSlotUnavailable(slot)) return;
    setState(() {
      _selectedTime = slot;
      _timeController.text = _formatSlot(slot);
    });
  }

  Future<void> _selectTime() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ngày trước khi chọn giờ')),
      );
      return;
    }
    if (_loadingAvailability) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang tải khung giờ, vui lòng đợi...')),
      );
      return;
    }

    final selected = await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chọn khung giờ (60 phút)',
                style: GoogleFonts.lato(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              if (_dailySlots.isEmpty)
                Text(
                  'Không có khung giờ khả dụng trong ngày này.',
                  style: GoogleFonts.lato(color: Colors.black54),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _dailySlots.map((slot) {
                    final unavailable = _isSlotUnavailable(slot);
                    final text = MaterialLocalizations.of(
                      context,
                    ).formatTimeOfDay(slot, alwaysUse24HourFormat: true);
                    return ChoiceChip(
                      label: Text(text),
                      selected:
                          _selectedTime?.hour == slot.hour &&
                          _selectedTime?.minute == slot.minute,
                      onSelected: unavailable
                          ? null
                          : (_) {
                              Navigator.pop(context, slot);
                            },
                      disabledColor: Colors.grey.shade300,
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );

    if (selected == null) return;
    setState(() {
      _selectedTime = selected;
      _timeController.text = MaterialLocalizations.of(
        context,
      ).formatTimeOfDay(selected, alwaysUse24HourFormat: true);
    });
  }

  Future<void> _createAppointment() async {
    final user = _auth.currentUser;
    if (user == null || _selectedDate == null || _selectedTime == null) return;

    final dateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    final slotKey = AppointmentSlotsRepository.slotKeyFromDateTime(dateTime);
    final dayKey = AppointmentSlotsRepository.dayKey(dateTime);
    final dateTimestamp = Timestamp.fromDate(dateTime);

    final pendingRef = _firestore
        .collection('appointments')
        .doc(user.uid)
        .collection('pending')
        .doc();
    final allRef = _firestore
        .collection('appointments')
        .doc(user.uid)
        .collection('all')
        .doc(pendingRef.id);
    final userSlotRef = _firestore
        .collection('appointments')
        .doc(user.uid)
        .collection('pending_slots')
        .doc('${dayKey}_$slotKey');

    final payload = {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'description': _descriptionController.text.trim(),
      'doctor': widget.doctor,
      'doctorId': _doctorId,
      'dayKey': dayKey,
      'slotKey': slotKey,
      'date': dateTimestamp,
      'status': AppointmentStatus.confirmed,
      'slotLockState': 'locked',
      'confirmedAt': FieldValue.serverTimestamp(),
      'statusUpdatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore.runTransaction((tx) async {
      final userSlotSnap = await tx.get(userSlotRef);
      if (userSlotSnap.exists &&
          userSlotSnap.data()?['appointmentPendingId'] != pendingRef.id) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'patient-conflict',
          message: 'Bạn đã có một lịch confirmed trùng khung giờ này.',
        );
      }

      tx.set(pendingRef, payload);
      tx.set(allRef, {...payload, 'sourcePendingId': pendingRef.id});
      tx.set(userSlotRef, {
        'uid': user.uid,
        'doctorId': _doctorId,
        'dayKey': dayKey,
        'slotKey': slotKey,
        'date': dateTimestamp,
        'appointmentPendingId': pendingRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    await _syncCalendarAfterCreate(
      pendingRef: pendingRef,
      allRef: allRef,
      payload: payload,
      start: dateTime,
    );
  }

  Future<void> _syncCalendarAfterCreate({
    required DocumentReference<Map<String, dynamic>> pendingRef,
    required DocumentReference<Map<String, dynamic>> allRef,
    required Map<String, dynamic> payload,
    required DateTime start,
  }) async {
    final calendarRepo = GoogleCalendarSyncRepository.instance;
    final linked = await calendarRepo.isCalendarLinkedForCurrentUser();

    if (!linked) {
      await pendingRef.set({
        'calendarSyncState': 'skipped',
        'calendarSyncError': 'calendar-not-linked',
      }, SetOptions(merge: true));
      await allRef.set({
        'calendarSyncState': 'skipped',
        'calendarSyncError': 'calendar-not-linked',
      }, SetOptions(merge: true));
      return;
    }

    final accessToken = await calendarRepo.getCalendarAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      await pendingRef.set({
        'calendarSyncState': 'error',
        'calendarSyncError': 'missing-access-token',
      }, SetOptions(merge: true));
      await allRef.set({
        'calendarSyncState': 'error',
        'calendarSyncError': 'missing-access-token',
      }, SetOptions(merge: true));
      return;
    }

    final calendarId = await calendarRepo.getCalendarIdForCurrentUser();
    final eventPayload = _buildCalendarEventPayload(
      payload: payload,
      start: start,
    );

    try {
      final eventId = await GoogleCalendarApiClient.instance.createEvent(
        accessToken: accessToken,
        calendarId: calendarId,
        event: eventPayload,
      );

      await pendingRef.set({
        'googleEventId': eventId,
        'calendarSyncState': 'synced',
        'calendarSyncError': null,
        'calendarSyncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await allRef.set({
        'googleEventId': eventId,
        'calendarSyncState': 'synced',
        'calendarSyncError': null,
        'calendarSyncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      await pendingRef.set({
        'calendarSyncState': 'error',
        'calendarSyncError': error.toString(),
      }, SetOptions(merge: true));
      await allRef.set({
        'calendarSyncState': 'error',
        'calendarSyncError': error.toString(),
      }, SetOptions(merge: true));
    }
  }

  Map<String, dynamic> _buildCalendarEventPayload({
    required Map<String, dynamic> payload,
    required DateTime start,
  }) {
    final end = start.add(const Duration(hours: 1));
    final patientName = payload['name']?.toString().trim() ?? 'Bệnh nhân';
    final doctorName = payload['doctor']?.toString().trim() ?? widget.doctor;
    final phone = payload['phone']?.toString().trim() ?? '';
    final note = payload['description']?.toString().trim() ?? '';

    return {
      'summary': 'Khám với $doctorName - $patientName',
      'description': 'SĐT: $phone\nGhi chú: $note',
      'start': {
        'dateTime': start.toUtc().toIso8601String(),
        'timeZone': 'Asia/Ho_Chi_Minh',
      },
      'end': {
        'dateTime': end.toUtc().toIso8601String(),
        'timeZone': 'Asia/Ho_Chi_Minh',
      },
    };
  }

  Future<bool> _hasLegacyPendingConflict(DateTime dateTime) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final day = AppointmentSlotsRepository.dayKey(dateTime);
    final slot = AppointmentSlotsRepository.slotKeyFromDateTime(dateTime);
    final snapshot = await _firestore
        .collection('appointments')
        .doc(user.uid)
        .collection('pending_slots')
        .where('dayKey', isEqualTo: day)
        .where('slotKey', isEqualTo: slot)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  void _showAlertDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Xong!',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        content: Text('Lịch hẹn đã được đăng ký.', style: GoogleFonts.lato()),
        actions: [
          TextButton(
            child: Text(
              'OK',
              style: GoogleFonts.lato(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const MyAppointments()),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _book() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ngày và giờ khám')),
      );
      return;
    }

    if (_isSlotUnavailable(_selectedTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Khung giờ này đã kín, vui lòng chọn giờ khác'),
        ),
      );
      await _loadAvailability(_selectedDate!);
      return;
    }

    final selectedDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    if (await _hasLegacyPendingConflict(selectedDateTime)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn đã có lịch hẹn khác trùng khung giờ này.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _createAppointment();
    } on FirebaseException catch (e) {
      String message = 'Không thể đặt lịch. Vui lòng thử lại.';
      if (e.code == 'patient-conflict') {
        message = 'Bạn đã có một lịch confirmed trùng khung giờ này.';
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      await _loadAvailability(_selectedDate!);
      return;
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }

    if (!mounted) return;
    _showAlertDialog();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _doctorController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _f1.dispose();
    _f2.dispose();
    _f3.dispose();
    _f4.dispose();
    _f5.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          'Đặt lịch khám',
          style: GoogleFonts.lato(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (notification) {
            notification.disallowIndicator();
            return true;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5C6BC0), Color(0xFF3949AB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.medical_services_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Đặt lịch với bác sĩ',
                                style: GoogleFonts.lato(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.doctor,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.lato(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildInfoChip(
                          icon: Icons.schedule_rounded,
                          label: 'Giờ khám: $_openHour - $_closeHour',
                        ),
                        _buildInfoChip(
                          icon: Icons.timer_outlined,
                          label: 'Mỗi lịch: 60 phút',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildSectionTitle(
                        title: 'Thông tin bệnh nhân',
                        subtitle:
                            'Điền đầy đủ để bác sĩ chuẩn bị trước buổi khám',
                      ),
                      const SizedBox(height: 14),
                      _buildInput(
                        controller: _nameController,
                        focusNode: _f1,
                        hint: 'Tên bệnh nhân*',
                        validator: (value) {
                          if ((value ?? '').isEmpty) {
                            return 'Vui lòng nhập tên bệnh nhân';
                          }
                          return null;
                        },
                        onSubmitted: () {
                          _f1.unfocus();
                          FocusScope.of(context).requestFocus(_f2);
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildInput(
                        controller: _phoneController,
                        focusNode: _f2,
                        hint: 'Số điện thoại*',
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if ((value ?? '').isEmpty) {
                            return 'Vui lòng nhập số điện thoại';
                          }
                          if ((value ?? '').length < 10) {
                            return 'Vui lòng nhập đúng số điện thoại';
                          }
                          return null;
                        },
                        onSubmitted: () {
                          _f2.unfocus();
                          FocusScope.of(context).requestFocus(_f3);
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildInput(
                        controller: _descriptionController,
                        focusNode: _f3,
                        hint: 'Triệu chứng/Ghi chú',
                        keyboardType: TextInputType.multiline,
                        maxLines: 3,
                        onSubmitted: () {
                          _f3.unfocus();
                          FocusScope.of(context).requestFocus(_f4);
                        },
                      ),
                      const SizedBox(height: 18),
                      _buildSectionTitle(
                        title: 'Lịch khám',
                        subtitle: 'Chọn ngày, giờ phù hợp với bạn',
                      ),
                      const SizedBox(height: 14),
                      _buildInput(
                        controller: _doctorController,
                        hint: 'Bác sĩ đã chọn',
                        readOnly: true,
                        validator: (value) {
                          if ((value ?? '').isEmpty) {
                            return 'Vui lòng nhập tên bác sĩ';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildPickerField(
                        focusNode: _f4,
                        controller: _dateController,
                        hint: 'Chọn ngày*',
                        icon: Icons.date_range_outlined,
                        validator: (value) {
                          if ((value ?? '').isEmpty) {
                            return 'Vui lòng chọn ngày';
                          }
                          return null;
                        },
                        onTap: _selectDate,
                        onSubmitted: () {
                          _f4.unfocus();
                          FocusScope.of(context).requestFocus(_f5);
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildPickerField(
                        focusNode: _f5,
                        controller: _timeController,
                        hint: 'Chọn giờ*',
                        icon: Icons.timer_outlined,
                        validator: (value) {
                          if ((value ?? '').isEmpty) return 'Vui lòng chọn giờ';
                          return null;
                        },
                        onTap: _selectTime,
                        onSubmitted: () {
                          _f5.unfocus();
                        },
                      ),
                      if (_loadingDoctorMeta || _loadingAvailability)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: LinearProgressIndicator(minHeight: 3),
                        ),
                      if (_selectedDate != null && !_loadingAvailability)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Khung giờ còn trống: ${_dailySlots.where((slot) => !_isSlotUnavailable(slot)).length}/${_dailySlots.length}',
                              style: GoogleFonts.lato(
                                fontSize: 13,
                                color: Colors.black54,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      if (_selectedDate != null &&
                          !_loadingAvailability &&
                          _dailySlots.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _dailySlots.take(12).map((slot) {
                                final unavailable = _isSlotUnavailable(slot);
                                final selected =
                                    _selectedTime?.hour == slot.hour &&
                                    _selectedTime?.minute == slot.minute;
                                return ChoiceChip(
                                  label: Text(_formatSlot(slot)),
                                  selected: selected,
                                  onSelected: unavailable
                                      ? null
                                      : (_) => _pickQuickSlot(slot),
                                  selectedColor: _primary.withValues(
                                    alpha: 0.18,
                                  ),
                                  side: BorderSide(
                                    color: unavailable
                                        ? Colors.grey.shade300
                                        : _primary.withValues(alpha: 0.35),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        width: MediaQuery.of(context).size.width,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: _primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _isSubmitting ? null : _book,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline_rounded),
                          label: Text(
                            _isSubmitting
                                ? 'Đang đặt lịch...'
                                : 'Xác nhận đặt lịch',
                            style: GoogleFonts.lato(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.lato(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.lato(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: GoogleFonts.lato(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black45,
          ),
        ),
      ],
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    FocusNode? focusNode,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int? maxLines = 1,
    bool readOnly = false,
    VoidCallback? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onFieldSubmitted: (_) => onSubmitted?.call(),
      textInputAction: TextInputAction.next,
      style: GoogleFonts.lato(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.indigo.shade100),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.indigo.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white,
        hintStyle: GoogleFonts.lato(
          color: Colors.black38,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPickerField({
    required FocusNode focusNode,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required VoidCallback onTap,
    required String? Function(String?) validator,
    required VoidCallback onSubmitted,
  }) {
    return SizedBox(
      height: 58,
      width: MediaQuery.of(context).size.width,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          TextFormField(
            focusNode: focusNode,
            controller: controller,
            validator: validator,
            readOnly: true,
            onFieldSubmitted: (_) => onSubmitted(),
            textInputAction: TextInputAction.next,
            style: GoogleFonts.lato(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.indigo.shade100),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.indigo.shade100),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _primary, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
              hintText: hint,
              hintStyle: GoogleFonts.lato(
                color: Colors.black38,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ClipOval(
              child: Material(
                color: _primary,
                child: InkWell(
                  onTap: onTap,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(icon, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
