import 'dart:convert';

/// Một người liên hệ của hub: danh xưng (Anh/Chị), tên, số điện thoại.
class Contact {
  String title, name, phone;
  /// "Không dùng nữa". Mặc định false (đang dùng) → file/dữ liệu cũ không đổi.
  bool inactive;
  Contact({this.title = 'Anh', this.name = '', this.phone = '', this.inactive = false});
  Map<String, Object> toJson() => {'title': title, 'name': name, 'phone': phone, 'active': !inactive};
  static Contact from(Map m) => Contact(title: '${m['title'] ?? 'Anh'}'.trim().isEmpty ? 'Anh' : '${m['title'] ?? 'Anh'}'.trim(), name: '${m['name'] ?? ''}'.trim(), phone: '${m['phone'] ?? ''}'.trim(), inactive: isInactiveValue(m['active'] ?? m['status'] ?? m['trang_thai'] ?? m['trạng thái']));
  Contact copy() => Contact(title: title, name: name, phone: phone, inactive: inactive);
  String get label => [if (name.isNotEmpty) '$title $name', if (phone.isNotEmpty) phone].join(' – ');
  String get digits => normPhone(phone);
  bool sameAs(Contact o) => title == o.title && name == o.name && phone == o.phone && inactive == o.inactive;
}

/// Đọc cờ trạng thái từ JSON/CSV: false, 0, inactive, không dùng... → không dùng nữa. Trống → đang dùng.
bool isInactiveValue(Object? v) {
  if (v == null) return false;
  if (v is bool) return !v;
  final s = '$v'.trim().toLowerCase();
  return const {'false', '0', 'inactive', 'no', 'off', 'không dùng', 'khong dung', 'không dùng nữa', 'khong dung nua', 'ngưng', 'ngung'}.contains(s);
}

/// Đang dùng trước, không dùng nữa xuống cuối (giữ thứ tự gốc).
List<Contact> sortActiveFirst(List<Contact> cs) => [...cs.where((c) => !c.inactive), ...cs.where((c) => c.inactive)];

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
/// số mới → thêm; số đã có giữ nguyên, chỉ nhận cờ "không dùng nữa".
List<Contact> mergeContacts(List<Contact> mine, List<Contact> inc) {
  final out = [for (final c in mine) c.copy()];
  for (final c in inc) {
    if (c.digits.isEmpty) continue;
    final ex = out.where((o) => o.digits == c.digits).firstOrNull;
    if (ex == null) { out.add(c); continue; }
    // Số đã có: không đổi tên/danh xưng/số (chỉ được thêm, không sửa).
    // File đánh dấu "không dùng nữa" → đánh dấu theo (không bao giờ xoá số).
    if (c.inactive) ex.inactive = true;
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
  final off = isInactiveValue(m['status'] ?? m['active'] ?? m['trang_thai']);
  return (name, ph.isEmpty ? [] : [Contact(title: t.isEmpty ? 'Anh' : t, name: cn, phone: ph, inactive: off)], note);
}
