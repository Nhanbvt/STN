import 'package:flutter_test/flutter_test.dart';
import 'package:so_thu_nhap/db.dart';
import 'package:so_thu_nhap/updater.dart';

void main() {
  test('payroll & price', () {
    expect(Band(vehicle: vehicles[0], route: 'Nội Thành', label: '0-15', basePrice: 56000).price, 71680);
    final ts = [for (var d = 1; d <= 28; d++) ...[Trip(date: '2026-10-${d.toString().padLeft(2, '0')}', route: 'x', from: ['a'], to: ['b'], vehicle: vehicles[0], price: 100), Trip(date: '2026-10-${d.toString().padLeft(2, '0')}', route: 'x', from: ['a'], to: ['b'], vehicle: vehicles[0])]];
    ts.add(Trip(date: '2026-10-29', route: 'x', from: ['a'], to: ['b'], vehicle: vehicles[0]));
    final p = Payroll.of(ts);
    expect(p.cong, 28.5);
    expect(p.congChuan, 27); // tháng 10 có 31 ngày
    expect(p.luong, 5310000);
    expect(p.tangCa, (1.5 * 5310000 / 27 * 2).round());
  });
  test('version compare', () {
    expect(compareVersions('1.0.12', '1.0.9'), 1);
    expect(compareVersions('v1.0.6', '1.0.6'), 0);
    expect(compareVersions('1.0.5', '1.0.6'), -1);
  });
}
