import 'db.dart';
import 'hub_region.dart';

/// Chuẩn hoá ngày 'yyyy-M-d' (dữ liệu cũ có thể thiếu số 0, vd 2026-05-5) → 'yyyy-MM-dd'.
/// Chỉ dùng để tính toán, không sửa dữ liệu đã lưu.
String normDate(String d) {
  final p = d.trim().split(RegExp(r'[-/]'));
  if (p.length < 3) return d.trim();
  final y = int.tryParse(p[0]), m = int.tryParse(p[1]), dd = int.tryParse(p[2].split(RegExp(r'[ T]')).first);
  if (y == null || m == null || dd == null) return d.trim();
  return '$y-${m.toString().padLeft(2, '0')}-${dd.toString().padLeft(2, '0')}';
}

/// Công chuẩn của tháng: tháng 31 ngày = 27 công; tháng 30 ngày và tháng 2 = 26 công.
int congChuanThang(DateTime month) => DateTime(month.year, month.month + 1, 0).day == 31 ? 27 : 26;

/// Chuyến tính 1 công/ngày (Nội vùng). Căn cứ chính là "Hành trình" tài xế chọn khi lưu chuyến
/// (cũng là căn cứ tính giá): 'Nội Vùng' / 'Liên Vùng' → nội vùng.
/// Chỉ khi hành trình không thuộc danh sách chuẩn (dữ liệu lạ) mới xét vùng của hub đi/đến
/// (cột region trong bảng hubs, không có thì đoán theo tên bằng classifyHubRegion).
bool tripIsNoiVung(Trip t, [Map<String, String> hubRegion = const {}]) {
  if (t.route == 'Nội Thành') return false;
  if (t.route == 'Nội Vùng' || t.route == 'Liên Vùng') return true;
  for (final n in [...t.from, ...t.to]) {
    final s = n.trim();
    if (s.isEmpty) continue;
    if ((hubRegion[s.toLowerCase()] ?? classifyHubRegion(s)) == kRegionNoiVung) return true;
  }
  return false;
}

/// Công & lương cho danh sách chuyến của 1 tháng (kỳ lương 1 → cuối tháng).
class Payroll {
  final int days, trips, tripMoney, congChuan;
  /// Công ngày thường (mỗi ngày tối đa 1).
  final double congNgay;
  /// Số ngày lễ trong tháng (mỗi ngày mặc định 1 công dù nghỉ).
  final int ngayLe;
  /// Công thưởng do đi làm ngày lễ. Ngày lễ đi làm = công ngày đó x3 (0.5→1.5, 1→3);
  /// trong đó 1 công là công lễ mặc định (đã tính vào công chuẩn), phần còn lại (3c − 1)
  /// là công thưởng trả theo đơn giá ngày, không tính vào công chuẩn/tăng ca.
  final double congLeThem;
  /// Phần công thường (≤ công chuẩn) và phần tăng ca (vượt công chuẩn, x2).
  final double congThuong, congTangCa;
  Payroll({required this.days, required this.trips, required this.tripMoney, required this.congChuan, required this.congNgay, required this.ngayLe, required this.congLeThem, required this.congThuong, required this.congTangCa});

  double get donGia => luongThang / congChuan;
  /// Tổng công hiển thị = công ngày thường + công lễ mặc định + công lễ thêm.
  double get cong => congNgay + ngayLe + congLeThem;
  int get luong => (congThuong * donGia).round();
  int get tangCa => (congTangCa * donGia * 2).round();
  int get tienLe => (congLeThem * donGia).round();
  int get tong => tripMoney + luong + tangCa + tienLe;

  /// [ts]: chuyến của tháng [month] (mặc định lấy theo chuyến đầu tiên / tháng hiện tại).
  /// [holidays]: ngày lễ (yyyy-MM-dd) trong tháng. [isNoiVung]: chuyến tính 1 công.
  static Payroll of(List<Trip> ts, {DateTime? month, Set<String> holidays = const {}, bool Function(Trip)? isNoiVung}) {
    final m = month ?? (ts.isNotEmpty ? DateTime.tryParse(normDate(ts.first.date)) ?? DateTime.now() : DateTime.now());
    final std = congChuanThang(m);
    final nv = isNoiVung ?? tripIsNoiVung;
    final count = <String, int>{};
    final vung = <String>{};
    for (final t in ts) {
      final k = normDate(t.date);
      count[k] = (count[k] ?? 0) + 1;
      if (nv(t)) vung.add(k);
    }
    double congNgay = 0, leThem = 0;
    for (final e in count.entries) {
      final c = vung.contains(e.key) || e.value >= 2 ? 1.0 : 0.5;
      if (holidays.contains(e.key)) {
        leThem += 3 * c - 1;
      } else {
        congNgay += c;
      }
    }
    final base = congNgay + holidays.length;
    final thuong = base > std ? std.toDouble() : base;
    return Payroll(days: count.length, trips: ts.length, tripMoney: ts.fold(0, (s, t) => s + t.price), congChuan: std, congNgay: congNgay, ngayLe: holidays.length, congLeThem: leThem, congThuong: thuong, congTangCa: base - thuong);
  }

  /// Công của 1 ngày (để tô màu lịch): 0 / 0.5 / 1 (ngày thường); lễ: nghỉ 1, đi làm 1.5 / 3.
  static double congOfDay(List<Trip> dayTrips, {bool holiday = false, bool Function(Trip)? isNoiVung}) {
    final nv = isNoiVung ?? tripIsNoiVung;
    final c = dayTrips.isEmpty ? 0.0 : dayTrips.any(nv) || dayTrips.length >= 2 ? 1.0 : 0.5;
    return holiday ? (c == 0 ? 1 : 3 * c) : c;
  }
}
