import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/mock_doctors.dart';
import '../data/realtime_doctors_repository.dart';
import '../utils/specialty_text.dart';
import '../theme_provider.dart'; 
import 'doctorProfile.dart';

class DoctorsList extends StatefulWidget {
  const DoctorsList({super.key});

  @override
  State<DoctorsList> createState() => _DoctorsListState();
}

class _DoctorsListState extends State<DoctorsList> {
  late Color _primary;
  late Color _lightCard;
  late Color _neutral;
  late bool _isDark;

  static const Map<String, String> _specialtyMap = {
    'Tất cả': '',
    'Tim mạch': 'Cardiologist',
    'Nha khoa': 'Dentist',
    'Mắt': 'Eye Special',
    'Cơ xương khớp': 'Orthopaedic',
    'Nhi khoa': 'Paediatrician',
  };

  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  String _activeType = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> all) {
    final key = _searchText.toLowerCase();
    return all.where((d) {
      final name = (d['name'] ?? '').toString().toLowerCase();
      final type = (d['type'] ?? '').toString().trim().toLowerCase();
      final nameOk = key.isEmpty || name.contains(key);
      final typeOk = _activeType.isEmpty || type == _activeType.toLowerCase();
      return nameOk && typeOk;
    }).toList();
  }

  PreferredSizeWidget _buildAppBar() {
    // Khai báo themeProvider ở đây để dùng cho nút bấm đổi màu
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      toolbarHeight: 68,
      titleSpacing: 14,
      title: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchText = v.trim()),
        style: GoogleFonts.lato(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: 'Tìm bác sĩ theo tên...',
          hintStyle: GoogleFonts.lato(color: _isDark ? Colors.white38 : Colors.black38),
          filled: true,
          fillColor: _isDark ? Colors.white10 : Colors.grey[200],
          prefixIcon: Icon(Icons.search_rounded, color: _isDark ? Colors.white70 : Colors.black45),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => themeProvider.toggleTheme(),
          icon: Icon(
            _isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: _isDark ? Colors.amber : _primary,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSpecialtyChips() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor, // Ép nền tối ở đây
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        itemCount: _specialtyMap.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final label = _specialtyMap.keys.elementAt(i);
          final typeVal = _specialtyMap.values.elementAt(i);
          final selected = _activeType == typeVal;
          return FilterChip(
            label: Text(
              label,
              style: GoogleFonts.lato(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : (_isDark ? Colors.white70 : _primary),
              ),
            ),
            selected: selected,
            onSelected: (_) => setState(() => _activeType = typeVal),
            backgroundColor: _isDark ? Colors.white10 : Colors.grey[200],
            selectedColor: _primary,
            showCheckmark: false,
            side: BorderSide(color: selected ? _primary : (_isDark ? Colors.white24 : Colors.transparent)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: _neutral.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            "Không tìm thấy bác sĩ nào",
            style: GoogleFonts.lato(color: _isDark ? Colors.white54 : Colors.black45),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _primary = theme.colorScheme.primary; 
    _lightCard = theme.cardColor;   
    _neutral = theme.colorScheme.onSurface; 
    _isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSpecialtyChips(),
          Divider(height: 1, thickness: 1, color: _isDark ? Colors.white10 : Colors.grey[300]),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: RealtimeDoctorsRepository.streamDoctors(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final raw = snapshot.data ?? const [];
                final source = raw.isNotEmpty ? raw : mockDoctors;
                final filtered = _applyFilters(source);

                if (filtered.isEmpty) return _buildEmptyState();

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _DoctorCard(
                    data: filtered[i],
                    primary: _primary,
                    cardColor: _lightCard,
                    isDark: _isDark,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({
    required this.data,
    required this.primary,
    required this.cardColor,
    required this.isDark,
  });

  final Map<String, dynamic> data;
  final Color primary;
  final Color cardColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final name = data['name']?.toString() ?? 'Bác sĩ';
    final type = toVietnameseSpecialty(data['type']?.toString() ?? '');
    final address = data['address']?.toString() ?? '';
    final rating = (data['rating'] is num) ? (data['rating'] as num).toDouble() : 0.0;
    final subColor = isDark ? Colors.white60 : Colors.black38;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DoctorProfile(doctor: name)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                child: const Icon(Icons.person, color: Colors.grey),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.lato(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type,
                      style: GoogleFonts.lato(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.indigoAccent[100] : primary,
                      ),
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lato(fontSize: 11, color: subColor),
                      ),
                    ],
                  ],
                ),
              ),
              _RatingBadge(rating: rating, primary: primary, isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating, required this.primary, required this.isDark});
  final double rating;
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primary.withOpacity(isDark ? 0.25 : 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.star_rounded, color: isDark ? Colors.amber : primary, size: 15),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: GoogleFonts.lato(
              color: isDark ? Colors.white : primary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}