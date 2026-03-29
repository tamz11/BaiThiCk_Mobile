import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../firestore-data/searchList.dart';

class DoctorsList extends StatefulWidget {
  const DoctorsList({super.key});

  @override
  State<DoctorsList> createState() => _DoctorsListState();
}

class _DoctorsListState extends State<DoctorsList> {
  static const Color _primary = Color(0xFF4B5AB5);
  static const Color _neutral = Color(0xFFD6D6D6);

  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  bool _showAll = false;

  @override
  void dispose() {
    _searchController.dispose();
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
        toolbarHeight: 64,
        titleSpacing: 16,
        title: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onChanged: (value) {
            setState(() {
              _search = value.trim();
            });
          },
          style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87),
          decoration: InputDecoration(
            hintText: 'Tìm bác sĩ',
            hintStyle: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black26),
            filled: true,
            fillColor: _neutral.withValues(alpha: 0.35),
            prefixIcon: const Icon(Icons.search, color: Colors.black45),
            suffixIcon: _search.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _search = '';
                        _showAll = false;
                      });
                    },
                    icon: const Icon(Icons.close_rounded, color: Colors.black45),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: (_search.isEmpty && !_showAll)
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showAll = true;
                        });
                      },
                      child: Text(
                        'Xem tất cả',
                        style: GoogleFonts.lato(
                          color: _primary,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Image.asset('assets/search-bg.png', height: 170, fit: BoxFit.contain),
                  ],
                ),
              )
            : SearchList(searchKey: _search, embedded: true),
      ),
    );
  }
}
