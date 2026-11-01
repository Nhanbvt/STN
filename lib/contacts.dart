import 'dart:convert';

/// Một người liên hệ của hub: danh xưng (Anh/Chị), tên, số điện thoại.
class Contact {
  String title, name, phone;
  Contact({this.title = 'Anh', this.name = '', this.phone = ''});
  Map<String, String> toJson() => {'title': title, 'name': name, 'phone': phone};
  static Contact from(Map m) => Contact(title: '${m['title'] ?? 'Anh'}'.trim().isEmpty ? 'Anh' : '${m['title'] ?? 'Anh'}'.trim(), name: '${m['name'] ?? ''}'.trim(), phone: '${m['phone'] ?? ''}'.trim());
  String get label => [if (name.isNotEmpty) '$title $name', if (phone.isNotEmpty) phone].join(' – ');
  String get digits => normPhone(phone);
  bool sameAs(Contact o) => title == o.title && name == o.name && phone == o.phone;
}

String normPhone(String p) {
  var d = p.replaceAll(RegExp(r'[^\d]'), '');
  if (d.startsWith('84') && d.length >= 11) d = '0${d.substring(2)}';
  return d;
}

/// Danh sách liên hệ của 1 dòng phones. Dòng cũ (chỉ có phone/note) → 1 liên hệ, không mất dữ liệu.
List<Contact> contactsOf(Map row) {
  final raw = '${row['contacts'] ?? ''}'.trim();
  if (raw.isNotEmpty) {
    try { return (jsonDecode(raw) as List).cast<Map>().map(Contact.from).where((c) => c.phone.isNotEmpty || c.name.isNotEmpty).toList(); } catch (_) {}
  }
  final ph = '${row['phone'] ?? ''}'.trim();
  return ph.isEmpty ? [] : [Contact(phone: ph)];
}

String encodeContacts(List<Contact> cs) => jsonEncode(cs.map((c) => c.toJson()).toList());

/// Gộp liên hệ từ file vào danh sách đang có: khớp theo số điện thoại;
/// số mới → thêm; cùng số nhưng tên/danh xưng khác (file có tên) → cập nhật.
List<Contact> mergeContacts(List<Contact> mine, List<Contact> inc) {
  final out = [for (final c in mine) Contact(title: c.title, name: c.name, phone: c.phone)];
  for (final c in inc) {
    if (c.digits.isEmpty) continue;
    final ex = out.where((o) => o.digits == c.digits).firstOrNull;
    if (ex == null) { out.add(c); continue; }
    if (c.name.isNotEmpty && (c.name != ex.name || c.title != ex.title)) { ex.name = c.name; ex.title = c.title; }
  }
  return out;
}

bool sameContacts(List<Contact> a, List<Contact> b) => a.length == b.length && [for (var i = 0; i < a.length; i++) a[i].sameAs(b[i])].every((e) => e);

/// Đọc bản ghi đã parse (JSON item hoặc dòng CSV) thành (tên hub, liên hệ, ghi chú).
/// Hỗ trợ file cũ: name, phone, note.
(String, List<Contact>, String) contactsFromItem(Map m) {
  final name = '${m['name'] ?? ''}'.trim();
  final note = '${m['note'] ?? ''}'.trim();
  final cs = m['contacts'];
  if (cs is List) return (name, cs.cast<Map>().map(Contact.from).where((c) => c.phone.isNotEmpty).toList(), note);
  if (cs is String && cs.trim().startsWith('[')) return (name, contactsOf({'contacts': cs}), note);
  final ph = '${m['phone'] ?? ''}'.trim();
  final cn = '${m['contact_name'] ?? m['ten_lien_he'] ?? ''}'.trim();
  final t = '${m['title'] ?? m['danh_xung'] ?? ''}'.trim();
  return (name, ph.isEmpty ? [] : [Contact(title: t.isEmpty ? 'Anh' : t, name: cn, phone: ph)], note);
}
