const List<Map<String, dynamic>> mockDoctors = [
  {
    'name': 'BS. Nguyễn Văn Minh',
    'type': 'Cardiologist',
    'email': 'minh.timmach@doctor.vn',
    'phone': '0903123456',
    'address': 'Bệnh viện Tim Hà Nội, 89 Trần Hưng Đạo, Hoàn Kiếm, Hà Nội',
    'specification': 'Chuyên khoa tim mạch, tăng huyết áp, rối loạn nhịp tim, theo dõi bệnh tim mạn tính.',
    'openHour': '08:00',
    'closeHour': '16:30',
    'rating': 5,
    'image': '',
  },
  {
    'name': 'BS. Trần Thị Lan',
    'type': 'Dentist',
    'email': 'lan.nhakhoa@doctor.vn',
    'phone': '0911222333',
    'address': 'Nha khoa Sài Gòn Smile, 120 Nguyễn Thị Minh Khai, Quận 3, TP.HCM',
    'specification': 'Khám răng tổng quát, điều trị sâu răng, nhổ răng khôn, thẩm mỹ răng sứ.',
    'openHour': '09:00',
    'closeHour': '19:00',
    'rating': 4,
    'image': '',
  },
  {
    'name': 'BS. Lê Quốc Anh',
    'type': 'Eye Special',
    'email': 'anh.mat@doctor.vn',
    'phone': '0939888777',
    'address': 'Bệnh viện Mắt Trung Ương, 85 Bà Triệu, Hai Bà Trưng, Hà Nội',
    'specification': 'Điều trị cận thị, viêm kết mạc, theo dõi glaucoma và bệnh lý đáy mắt.',
    'openHour': '07:30',
    'closeHour': '16:00',
    'rating': 5,
    'image': '',
  },
  {
    'name': 'BS. Phạm Đức Khoa',
    'type': 'Orthopaedic',
    'email': 'khoa.co-xuong-khop@doctor.vn',
    'phone': '0977555666',
    'address': 'Trung tâm Chấn thương Chỉnh hình, 201B Nguyễn Chí Thanh, Đống Đa, Hà Nội',
    'specification': 'Chấn thương thể thao, đau cột sống, thoái hóa khớp, phục hồi chức năng vận động.',
    'openHour': '08:30',
    'closeHour': '17:00',
    'rating': 4,
    'image': '',
  },
  {
    'name': 'BS. Võ Thị Hương',
    'type': 'Paediatrician',
    'email': 'huong.nhi@doctor.vn',
    'phone': '0909777888',
    'address': 'Bệnh viện Nhi Đồng 2, 14 Lý Tự Trọng, Quận 1, TP.HCM',
    'specification': 'Theo dõi tăng trưởng, tiêm chủng, bệnh hô hấp và tiêu hóa ở trẻ em.',
    'openHour': '08:00',
    'closeHour': '17:30',
    'rating': 5,
    'image': '',
  },
  {
    'name': 'BS. Đặng Thanh Bình',
    'type': 'Cardiologist',
    'email': 'binh.timmach@doctor.vn',
    'phone': '0966333444',
    'address': 'Phòng khám Đa khoa Bình An, 55 Điện Biên Phủ, Bình Thạnh, TP.HCM',
    'specification': 'Tư vấn tim mạch dự phòng, siêu âm tim, điều trị mạch vành.',
    'openHour': '08:00',
    'closeHour': '15:30',
    'rating': 4,
    'image': '',
  },
  {
    'name': 'BS. Hoàng Minh Châu',
    'type': 'Dentist',
    'email': 'chau.nhakhoa@doctor.vn',
    'phone': '0944111222',
    'address': 'Nha khoa Kim Cương, 42 Lê Duẩn, Hải Châu, Đà Nẵng',
    'specification': 'Niềng răng, tẩy trắng, implant và điều trị nha chu.',
    'openHour': '10:00',
    'closeHour': '20:00',
    'rating': 5,
    'image': '',
  },
  {
    'name': 'BS. Nguyễn Thị Mai',
    'type': 'Eye Special',
    'email': 'mai.mat@doctor.vn',
    'phone': '0922666777',
    'address': 'Phòng khám Mắt Ánh Sáng, 19 Võ Văn Tần, Quận 3, TP.HCM',
    'specification': 'Khám mắt tổng quát, tư vấn kính thuốc, điều trị khô mắt mạn tính.',
    'openHour': '09:00',
    'closeHour': '18:00',
    'rating': 4,
    'image': '',
  },
  {
    'name': 'BS. Bùi Tuấn Kiệt',
    'type': 'Orthopaedic',
    'email': 'kiet.co-xuong-khop@doctor.vn',
    'phone': '0913555777',
    'address': 'Bệnh viện Đa khoa Thành phố Cần Thơ, 22 Nguyễn Văn Cừ, Ninh Kiều, Cần Thơ',
    'specification': 'Điều trị gãy xương, đau khớp gối, vật lý trị liệu sau chấn thương.',
    'openHour': '07:30',
    'closeHour': '16:30',
    'rating': 4,
    'image': '',
  },
  {
    'name': 'BS. Phan Ngọc Trúc',
    'type': 'Paediatrician',
    'email': 'truc.nhi@doctor.vn',
    'phone': '0988889999',
    'address': 'Phòng khám Nhi An Tâm, 88 Nguyễn Trãi, Thanh Xuân, Hà Nội',
    'specification': 'Sơ sinh, dị ứng trẻ em, dinh dưỡng nhi và theo dõi bệnh theo mùa.',
    'openHour': '08:30',
    'closeHour': '17:00',
    'rating': 5,
    'image': '',
  },
];

String _normalize(String value) => value.trim().toLowerCase();

String _normalizeVietnamese(String input) {
  final source = input.trim().toLowerCase();
  if (source.isEmpty) return '';
  const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final out = StringBuffer();
  for (final rune in source.runes) {
    final ch = String.fromCharCode(rune);
    final idx = from.indexOf(ch);
    out.write(idx >= 0 ? to[idx] : ch);
  }
  return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _canonicalType(String raw) {
  final t = _normalizeVietnamese(raw);
  if (t.contains('tim') || t.contains('cardio')) return 'tim_mach';
  if (t.contains('rang') || t.contains('nha') || t.contains('dentist') || t.contains('ham')) {
    return 'rang_ham_mat';
  }
  if (t == 'mat' || t.contains('eye')) return 'mat';
  if (t.contains('co xuong') || t.contains('khop') || t.contains('orthopaedic')) return 'co_xuong_khop';
  if (t.contains('nhi') || t.contains('paediatric') || t.contains('tre')) return 'nhi_khoa';
  return t;
}

List<Map<String, dynamic>> doctorsByName(String keyword) {
  final key = _normalize(keyword);
  if (key.isEmpty) return List<Map<String, dynamic>>.from(mockDoctors);
  return mockDoctors
      .where((d) => _normalize((d['name'] ?? '').toString()).contains(key))
      .toList();
}

List<Map<String, dynamic>> doctorsByType(String type) {
  final key = _canonicalType(type);
  return mockDoctors
      .where((d) => _canonicalType((d['type'] ?? '').toString()) == key)
      .toList();
}

Map<String, dynamic>? doctorByName(String name) {
  final key = _normalize(name);
  for (final doctor in mockDoctors) {
    if (_normalize((doctor['name'] ?? '').toString()) == key) {
      return doctor;
    }
  }
  return null;
}

List<Map<String, dynamic>> topRatedDoctors([int limit = 5]) {
  final items = List<Map<String, dynamic>>.from(mockDoctors);
  items.sort((a, b) => (b['rating'] as int).compareTo(a['rating'] as int));
  if (items.length <= limit) return items;
  return items.take(limit).toList();
}
