import 'package:flutter_test/flutter_test.dart';
import 'package:so_thu_nhap/db.dart';
import 'package:so_thu_nhap/holidays.dart';
import 'package:so_thu_nhap/vn_lunar.dart';

Trip nt(String d, {int price = 100}) => Trip(date: d, route: 'Nội Thành', from: ['A'], to: ['B'], vehicle: vehicles[0], price: price);
Trip nv(String d, {int price = 100}) => Trip(date: d, route: 'Nội Vùng', from: ['A'], to: ['72-LAN Ben Luc Hub'], vehicle: vehicles[0], price: price);
String day(int y, int m, int d) => '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

void main() {
  group('công chuẩn theo tháng', () {
    test('31 ngày = 27, 30 ngày = 26, tháng 2 = 26', () {
      expect(congChuanThang(DateTime(2026, 1)), 27);
      expect(congChuanThang(DateTime(2026, 4)), 26);
      expect(congChuanThang(DateTime(2026, 2)), 26);
      expect(congChuanThang(DateTime(2028, 2)), 26); // năm nhuận 29 ngày
      expect(congChuanThang(DateTime(2026, 12)), 27);
    });
    test('đơn giá = 5.310.000 / công chuẩn', () {
      final p31 = Payroll.of([], month: DateTime(2026, 10));
      final p30 = Payroll.of([], month: DateTime(2026, 11));
      expect(p31.donGia, 5310000 / 27);
      expect(p30.donGia, 5310000 / 26);
    });
  });

  group('công theo ngày', () {
    test('1 chuyến nội thành = 0.5, 2+ = 1, tối đa 1/ngày', () {
      final p = Payroll.of([nt('2026-11-02'), nt('2026-11-03'), nt('2026-11-03'), nt('2026-11-04'), nt('2026-11-04'), nt('2026-11-04'), nt('2026-11-04')], month: DateTime(2026, 11));
      expect(p.congNgay, 2.5);
      expect(p.days, 3);
    });
    test('chuyến nội vùng = 1 công, không cộng dồn với nội thành', () {
      final p = Payroll.of([nv('2026-11-02'), nv('2026-11-03'), nt('2026-11-03'), nv('2026-11-04'), nv('2026-11-04')], month: DateTime(2026, 11));
      expect(p.congNgay, 3);
    });
    test('liên vùng cũng 1 công', () {
      final t = Trip(date: '2026-11-05', route: 'Liên Vùng', from: ['A'], to: ['B'], vehicle: vehicles[0]);
      expect(Payroll.of([t], month: DateTime(2026, 11)).congNgay, 1);
    });
    test('hành trình lạ: dựa vào vùng của hub', () {
      final t = Trip(date: '2026-11-05', route: '', from: ['HCM Mega SOC'], to: ['Hub X'], vehicle: vehicles[0]);
      expect(tripIsNoiVung(t), false);
      expect(tripIsNoiVung(t, {'hub x': 'noi_vung'}), true);
      // Hành trình Nội Thành thì luôn theo hành trình đã chọn (không đổi giá/công tự động).
      expect(tripIsNoiVung(nt('2026-11-05'), {'b': 'noi_vung'}), false);
    });
  });

  test('ngày thiếu số 0 (dữ liệu cũ) vẫn gộp đúng ngày', () {
    expect(normDate('2026-05-5'), '2026-05-05');
    final p = Payroll.of([nt('2026-05-5'), nt('2026-05-05')]);
    expect(p.days, 1);
    expect(p.congNgay, 1);
    // 1/5 là ngày lễ dù ghi '2026-5-1'
    final q = Payroll.of([nt('2026-5-1'), nt('2026-05-01')], month: DateTime(2026, 5), holidays: holidaysInMonth(DateTime(2026, 5), const {}));
    expect(q.congLeThem, 2); // 2 chuyến ngày lễ = 3 công = 1 + 2 thưởng
  });

  group('ngày lễ', () {
    test('ngày lễ không đi làm mặc định 1 công', () {
      final hol = holidaysInMonth(DateTime(2026, 9), const {});
      expect(hol, {'2026-09-01', '2026-09-02'});
      final p = Payroll.of([nt('2026-09-03'), nt('2026-09-03')], month: DateTime(2026, 9), holidays: hol);
      expect(p.ngayLe, 2);
      expect(p.cong, 3); // 1 ngày thường + 2 ngày lễ
      expect(p.congThuong, 3);
      expect(p.luong, (3 * 5310000 / 26).round());
      expect(p.tienLe, 0);
    });
    test('đi làm ngày lễ cả ngày = 1 × 3 = 3 công (1 vào công chuẩn + 2 thưởng)', () {
      final p = Payroll.of([nv('2026-09-02')], month: DateTime(2026, 9), holidays: {'2026-09-02'});
      expect(p.cong, 3);
      expect(p.congThuong, 1);
      expect(p.congLeThem, 2);
      expect(p.luong, (5310000 / 26).round());
      expect(p.tienLe, (2 * 5310000 / 26).round());
      expect(p.tong, 100 + p.luong + p.tienLe);
      expect(Payroll.congOfDay([nv('2026-09-02')], holiday: true), 3);
    });
    test('đi 1 chuyến nội thành ngày lễ = 0.5 × 3 = 1.5 công (1 + 0.5 thưởng)', () {
      expect(Payroll.congOfDay([nt('2026-09-02')], holiday: true), 1.5);
      expect(Payroll.congOfDay([nt('2026-09-02'), nt('2026-09-02')], holiday: true), 3);
      expect(Payroll.congOfDay([], holiday: true), 1);
      final p = Payroll.of([nt('2026-09-02')], month: DateTime(2026, 9), holidays: {'2026-09-01', '2026-09-02'});
      expect(p.cong, 2.5); // 1/9 nghỉ = 1, 2/9 đi 1 chuyến = 1.5
      expect(p.congThuong, 2);
      expect(p.congLeThem, 0.5);
      expect(p.tienLe, (0.5 * 5310000 / 26).round());
    });
  });

  test('tăng ca x2 khi vượt công chuẩn (ngày lễ mặc định tính vào công chuẩn)', () {
    // Tháng 11/2026: 30 ngày → 26 công; 24/11 là ngày lễ (Ngày Văn hóa Việt Nam).
    final hol = holidaysInMonth(DateTime(2026, 11), const {});
    expect(hol, {'2026-11-24'});
    final ts = [for (var d = 1; d <= 30; d++) if (d != 24) nv(day(2026, 11, d))];
    final p = Payroll.of(ts, month: DateTime(2026, 11), holidays: hol);
    expect(p.congNgay, 29);
    expect(p.congThuong, 26);
    expect(p.congTangCa, 4); // 29 + 1 lễ − 26
    expect(p.tangCa, (4 * 5310000 / 26 * 2).round());
    expect(p.luong, 5310000);
  });

  group('lịch âm & danh sách lễ', () {
    test('Tết & Giỗ Tổ khớp lịch Việt Nam 2024–2035', () {
      const tet = {2024: '2024-02-10', 2025: '2025-01-29', 2026: '2026-02-17', 2027: '2027-02-06', 2028: '2028-01-26', 2029: '2029-02-13', 2030: '2030-02-02' /* lịch VN (UTC+7) khác lịch TQ */, 2031: '2031-01-23', 2032: '2032-02-11', 2033: '2033-01-31', 2034: '2034-02-19', 2035: '2035-02-08'};
      const gioTo = {2024: '2024-04-18', 2025: '2025-04-07', 2026: '2026-04-26', 2027: '2027-04-16', 2028: '2028-04-04', 2029: '2029-04-23', 2030: '2030-04-12', 2031: '2031-04-01', 2032: '2032-04-19', 2033: '2033-04-09', 2034: '2034-04-28', 2035: '2035-04-17'};
      for (final y in tet.keys) {
        final t = lunarToSolar(1, 1, y), g = lunarToSolar(10, 3, y);
        expect(day(t.year, t.month, t.day), tet[y], reason: 'Tết $y');
        expect(day(g.year, g.month, g.day), gioTo[y], reason: 'Giỗ Tổ $y');
      }
    });
    test('2026: 12 ngày lễ, Tết 16–20/2', () {
      final h = builtinHolidays(2026);
      expect(h.length, 12);
      for (final d in ['2026-01-01', '2026-02-16', '2026-02-17', '2026-02-18', '2026-02-19', '2026-02-20', '2026-04-26', '2026-04-30', '2026-05-01', '2026-09-01', '2026-09-02', '2026-11-24']) {
        expect(h.containsKey(d), true, reason: d);
      }
      expect(builtinHolidays(2025).containsKey('2025-11-24'), false);
    });
    test('chạm bật/tắt ngày lễ', () {
      final ov = <String, bool>{};
      // thêm ngày lễ mới
      expect(toggledOverride('2026-11-25', ov), true);
      ov['2026-11-25'] = true;
      expect(isHoliday('2026-11-25', ov), true);
      expect(toggledOverride('2026-11-25', ov), null); // tắt lại → xoá ghi đè
      // bỏ ngày lễ có sẵn
      expect(toggledOverride('2026-11-24', ov), false);
      ov['2026-11-24'] = false;
      expect(isHoliday('2026-11-24', ov), false);
      expect(holidaysInMonth(DateTime(2026, 11), ov), {'2026-11-25'});
      expect(toggledOverride('2026-11-24', ov), null);
    });
  });
}
