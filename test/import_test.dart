import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:so_thu_nhap/db.dart';
import 'package:so_thu_nhap/hubs.dart';

// Fixture chứa dữ liệu cá nhân -> chỉ để trên máy, không commit (xem .gitignore).
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final fx = File('test/fixtures/old_export2.json');

  test('parse map links', () {
    expect(parseLatLng('https://www.google.com/maps/place/X/@10.8231,106.6297,17z'), (10.8231, 106.6297));
    expect(parseLatLng('https://maps.google.com/?q=10.762622,106.660172'), (10.762622, 106.660172));
    expect(parseLatLng('10.80123, 106.71234'), (10.80123, 106.71234));
  });

  test('import old export with duplicates', skip: fx.existsSync() ? false : 'fixture không có trong repo', () async {
    await DB.init();
    await DB.db.delete('trips');
    await DB.db.delete('fuel');
    final d = jsonDecode(fx.readAsStringSync()) as Map<String, dynamic>;
    print('FILE trips=${(d['trips'] as List).length} fuel=${(d['fuel'] as List).length}');
    print(await DB.importOld(d));
    final trips = await DB.trips();
    print('AFTER trips=${trips.length} fuel=${(await DB.fuels()).length}');
    final codes = trips.map((t) => t.note).where((c) => c.isNotEmpty).toList();
    expect(codes.length - codes.toSet().length, 1); // LT0Q8A4UWI09A: cùng mã, 2 chuyến khác ngày/tuyến
    final m = <String, int>{};
    for (final t in trips) { final k = t.date.substring(0, 7); m[k] = (m[k] ?? 0) + t.price; }
    for (final k in m.keys.toList()..sort()) { print('$k total=${m[k]} cong=${Payroll.of(trips.where((t) => t.date.startsWith(k)).toList()).cong}'); }
    // Nhập lại lần 2: không thêm gì
    print('REIMPORT ${await DB.importOld(d)}');
    expect((await DB.trips()).length, trips.length);
    // Dedupe DB (giả lập migration): chèn bản trùng rồi dọn
    final t0 = (await DB.db.query('trips', limit: 1)).first;
    await DB.db.insert('trips', Map.of(t0)..remove('id'));
    final f0 = (await DB.db.query('fuel', limit: 1)).first;
    await DB.db.insert('fuel', Map.of(f0)..remove('id'));
    expect(await DB.dedupe(DB.db), (1, 1));
    expect(await DB.codeExists(t0['note'] as String), true);
  });
}
