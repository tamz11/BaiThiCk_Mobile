import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'myAppointments.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, this.doctor = ''});

  final String doctor;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
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

  @override
  void initState() {
    super.initState();
    _doctorController = TextEditingController(text: widget.doctor);
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
      _dateController.text = DateFormat('dd-MM-yyyy').format(date);
    });
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    setState(() {
      _selectedTime = time;
      _timeController.text = time.format(context);
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

    final payload = {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'description': _descriptionController.text.trim(),
      'doctor': widget.doctor,
      'date': dateTime,
    };

    await FirebaseFirestore.instance.collection('appointments').doc(user.uid).collection('pending').add(payload);
    await FirebaseFirestore.instance.collection('appointments').doc(user.uid).collection('all').add(payload);
  }

  void _showAlertDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Xong!',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Lịch hẹn đã được đăng ký.',
          style: GoogleFonts.lato(),
        ),
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
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ngày và giờ khám')),
      );
      return;
    }

    await _createAppointment();

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
            shrinkWrap: true,
            children: [
              Container(
                child: const Image(
                  image: AssetImage('assets/appointment.jpg'),
                  height: 250,
                ),
              ),
              const SizedBox(height: 10),
              Form(
                key: _formKey,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          'Nhập thông tin bệnh nhân',
                          style: GoogleFonts.lato(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildInput(
                        controller: _nameController,
                        focusNode: _f1,
                        hint: 'Tên bệnh nhân*',
                        validator: (value) {
                          if ((value ?? '').isEmpty) return 'Vui lòng nhập tên bệnh nhân';
                          return null;
                        },
                        onSubmitted: () {
                          _f1.unfocus();
                          FocusScope.of(context).requestFocus(_f2);
                        },
                      ),
                      const SizedBox(height: 20),
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
                      const SizedBox(height: 20),
                      _buildInput(
                        controller: _descriptionController,
                        focusNode: _f3,
                        hint: 'Mô tả',
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        onSubmitted: () {
                          _f3.unfocus();
                          FocusScope.of(context).requestFocus(_f4);
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildInput(
                        controller: _doctorController,
                        hint: 'Tên bác sĩ*',
                        readOnly: true,
                        validator: (value) {
                          if ((value ?? '').isEmpty) return 'Vui lòng nhập tên bác sĩ';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildPickerField(
                        focusNode: _f4,
                        controller: _dateController,
                        hint: 'Chọn ngày*',
                        icon: Icons.date_range_outlined,
                        validator: (value) {
                          if ((value ?? '').isEmpty) return 'Vui lòng chọn ngày';
                          return null;
                        },
                        onTap: _selectDate,
                        onSubmitted: () {
                          _f4.unfocus();
                          FocusScope.of(context).requestFocus(_f5);
                        },
                      ),
                      const SizedBox(height: 20),
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
                      const SizedBox(height: 40),
                      SizedBox(
                        height: 50,
                        width: MediaQuery.of(context).size.width,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            elevation: 2,
                            backgroundColor: Colors.indigo,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32.0),
                            ),
                          ),
                          onPressed: _book,
                          child: Text(
                            'Đặt lịch khám',
                            style: GoogleFonts.lato(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
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
      style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.only(left: 20, top: 10, bottom: 10),
        hintText: hint,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(90.0)),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey[350],
        hintStyle: GoogleFonts.lato(
          color: Colors.black26,
          fontSize: 18,
          fontWeight: FontWeight.w800,
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
      height: 60,
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
            style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.only(left: 20, top: 10, bottom: 10),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(90.0)),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[350],
              hintText: hint,
              hintStyle: GoogleFonts.lato(
                color: Colors.black26,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: ClipOval(
              child: Material(
                color: Colors.indigo,
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
