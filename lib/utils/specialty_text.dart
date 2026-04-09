String _normalizeVietnamese(String input) {
  final source = input.trim().toLowerCase();
  if (source.isEmpty) return '';
  const from =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const to =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final out = StringBuffer();
  for (final rune in source.runes) {
    final ch = String.fromCharCode(rune);
    final idx = from.indexOf(ch);
    out.write(idx >= 0 ? to[idx] : ch);
  }
  return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

String toVietnameseSpecialty(String raw) {
  final t = _normalizeVietnamese(raw);
  if (t.isEmpty) return '';

  if (t.contains('tim') || t.contains('cardio')) return 'Tim mạch';
  if (t.contains('rang') ||
      t.contains('nha') ||
      t.contains('ham') ||
      t.contains('dentist')) {
    return 'Răng hàm mặt';
  }
  if (t == 'mat' || t.contains('eye')) return 'Mắt';
  if (t.contains('co xuong') ||
      t.contains('khop') ||
      t.contains('orthopaedic')) {
    return 'Cơ xương khớp';
  }
  if (t.contains('nhi') || t.contains('tre') || t.contains('paediatric')) {
    return 'Nhi khoa';
  }
  if (t.contains('san') ||
      t.contains('phu khoa') ||
      t.contains('obstetric') ||
      t.contains('gyne')) {
    return 'Sản phụ khoa';
  }
  if (t.contains('noi tiet') || t.contains('endocr')) return 'Nội tiết';
  if (t.contains('tieu hoa') || t.contains('gastro')) return 'Tiêu hóa';
  if (t.contains('ho hap') || t.contains('respir')) return 'Hô hấp';
  if (t.contains('than kinh') || t.contains('neurology')) return 'Thần kinh';
  if (t.contains('da lieu') || t.contains('derma')) return 'Da liễu';
  if (t.contains('tai mui hong') || t.contains('ent')) return 'Tai mũi họng';

  return raw;
}
