import 'vn_lunar.dart';

String _ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Ngày lễ, Tết người lao động được nghỉ hưởng nguyên lương (Bộ luật Lao động 2019, Điều 112)
/// + Ngày Văn hóa Việt Nam 24/11 (Nghị quyết Quốc hội, hiệu lực 1/7/2026).
/// - Tết Âm lịch 5 ngày: 1 ngày cuối năm + mùng 1–4 (phương án Bộ Nội vụ áp dụng cho công chức).
/// - Quốc khánh: 2/9 + ngày liền kề trước 1/9.
/// Ngày bị thiếu/khác (nghỉ bù, phương án công ty) người dùng tự chạm trên Lịch vận hành để bật/tắt.
Map<String, String> builtinHolidays(int year) {
  final m = <String, String>{};
  void add(DateTime d, String name) => m[_ymd(d)] = name;
  add(DateTime(year, 1, 1), 'Tết Dương lịch');
  final tet = lunarToSolar(1, 1, year);
  add(tet.subtract(const Duration(days: 1)), 'Tết Nguyên đán (cuối năm)');
  for (var i = 0; i < 4; i++) {
    add(DateTime(tet.year, tet.month, tet.day + i), 'Tết Nguyên đán (mùng ${i + 1})');
  }
  add(lunarToSolar(10, 3, year), 'Giỗ Tổ Hùng Vương');
  add(DateTime(year, 4, 30), 'Ngày Chiến thắng 30/4');
  add(DateTime(year, 5, 1), 'Quốc tế Lao động 1/5');
  add(DateTime(year, 9, 1), 'Quốc khánh (liền kề)');
  add(DateTime(year, 9, 2), 'Quốc khánh 2/9');
  if (year >= 2026) add(DateTime(year, 11, 24), 'Ngày Văn hóa Việt Nam');
  return m;
}

final _cache = <int, Map<String, String>>{};
Map<String, String> _builtin(int y) => _cache.putIfAbsent(y, () => builtinHolidays(y));

/// Tên ngày lễ của [date] (yyyy-MM-dd) sau khi áp dụng chỉnh tay [overrides]
/// (true = người dùng thêm, false = người dùng bỏ). null = không phải ngày lễ.
String? holidayName(String date, Map<String, bool> overrides) {
  final o = overrides[date];
  if (o == false) return null;
  final y = int.tryParse(date.length >= 4 ? date.substring(0, 4) : '');
  final b = y == null ? null : _builtin(y)[date];
  if (b != null) return b;
  return o == true ? 'Ngày lễ (tự thêm)' : null;
}

bool isHoliday(String date, Map<String, bool> overrides) => holidayName(date, overrides) != null;

/// Các ngày lễ (yyyy-MM-dd) trong tháng của [month].
Set<String> holidaysInMonth(DateTime month, Map<String, bool> overrides) {
  final days = DateTime(month.year, month.month + 1, 0).day;
  return {
    for (var d = 1; d <= days; d++)
      if (isHoliday(_ymd(DateTime(month.year, month.month, d)), overrides)) _ymd(DateTime(month.year, month.month, d)),
  };
}

/// Giá trị ghi đè mới khi người dùng chạm vào [date]: đảo trạng thái lễ hiện tại.
/// Trả về null nếu sau khi đảo trùng với danh sách có sẵn (xoá ghi đè).
bool? toggledOverride(String date, Map<String, bool> overrides) {
  final y = int.tryParse(date.substring(0, 4))!;
  final builtin = _builtin(y).containsKey(date);
  final nowHoliday = isHoliday(date, overrides);
  final want = !nowHoliday;
  return want == builtin ? null : want;
}
