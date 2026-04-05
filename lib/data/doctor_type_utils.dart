// ─────────────────────────────────────────────────────────────────────────────
// doctor_type_utils.dart
//
// Hàm dùng chung để chuẩn hóa tên chuyên khoa bác sĩ.
// Import file này ở bất kỳ nơi nào cần so sánh hoặc lọc theo chuyên khoa.
// ─────────────────────────────────────────────────────────────────────────────

String normalizeVietnamese(String input) {
  final source = input.trim().toLowerCase();
  if (source.isEmpty) return '';

  const from =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩ'
      'òóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const to =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiioo'
      'oooooooooooooooouuuuuuuuuuuyyyyyd';

  final buffer = StringBuffer();
  for (final rune in source.runes) {
    final ch = String.fromCharCode(rune);
    final idx = from.indexOf(ch);
    buffer.write(idx >= 0 ? to[idx] : ch);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Chuyển bất kỳ tên chuyên khoa nào (tiếng Anh hoặc tiếng Việt) về
/// một giá trị chuẩn duy nhất (slug) để so sánh.
///
/// Ví dụ:
///   'Cardiologist' → 'tim_mach'
///   'Tim mạch'     → 'tim_mach'
///   'Dentist'      → 'rang_ham_mat'
///   'Răng hàm mặt' → 'rang_ham_mat'
String canonicalType(String raw) {
  final t = normalizeVietnamese(raw);

  if (t.contains('tim') || t.contains('cardio')) return 'tim_mach';
  if (t.contains('rang') ||
      t.contains('nha') ||
      t.contains('dentist') ||
      t.contains('ham'))
    return 'rang_ham_mat';
  if (t == 'mat' || t.contains('eye') || t.contains('mat ')) return 'mat';
  if (t.contains('co xuong') ||
      t.contains('khop') ||
      t.contains('orthopaedic') ||
      t.contains('chinh hinh'))
    return 'co_xuong_khop';
  if (t.contains('nhi') ||
      t.contains('paediatric') ||
      t.contains('tre em') ||
      t.contains('pediatric'))
    return 'nhi_khoa';

  return t; // fallback: giữ nguyên để không mất dữ liệu lạ
}
