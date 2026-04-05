import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart'; // Thêm import này nếu cần dùng ThemeProvider trực tiếp
import '../firestore-data/myAppointmentList.dart';

class MyAppointments extends StatelessWidget {
  const MyAppointments({super.key});

  @override
  Widget build(BuildContext context) {
    // Kiểm tra xem ứng dụng đang ở chế độ Dark Mode hay không
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Sử dụng màu nền từ Theme thay vì Colors.white cố định
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      
      appBar: AppBar(
        // Tự động lấy màu nền AppBar từ Theme
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87, // Đổi màu nút quay lại
        ),
        title: Text(
          'Lịch hẹn của tôi',
          style: GoogleFonts.lato(
            // Đổi màu chữ tiêu đề dựa theo mode
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      
      body: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          children: [
            // MyAppointmentList cũng nên sử dụng Theme.of(context) bên trong nó
            Expanded(child: MyAppointmentList()),
          ],
        ),
      ),
    );
  }
}