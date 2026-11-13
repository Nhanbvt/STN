import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:so_thu_nhap/db.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('nâng DB v6 → v7: giữ nguyên chuyến/cài đặt, thêm bảng ngày lễ', () async {
    final dir = Directory.systemTemp.createTempSync('stn_v7_');
    await databaseFactory.setDatabasesPath(dir.path);
    final path = p.join(dir.path, 'so_thu_nhap.db');
    final old = await openDatabase(path, version: 6, onCreate: (d, v) async {
      await d.execute('CREATE TABLE hubs(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, lat REAL, lng REAL, note TEXT, region TEXT)');
      await d.execute('CREATE TABLE phones(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, phone TEXT, note TEXT, contacts TEXT)');
      await d.execute('CREATE TABLE trips(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT, route TEXT, from_pts TEXT, to_pts TEXT, band_id INTEGER, price INTEGER, note TEXT, vehicle TEXT)');
      await d.execute('CREATE TABLE bands(id INTEGER PRIMARY KEY AUTOINCREMENT, vehicle TEXT, route TEXT, label TEXT, base_price INTEGER, placeholder INTEGER)');
      await d.execute('CREATE TABLE fuel(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT, liters REAL, km REAL)');
      await d.execute('CREATE TABLE places(name TEXT PRIMARY KEY, uses INTEGER)');
      await d.execute('CREATE TABLE settings(k TEXT PRIMARY KEY, v TEXT)');
    });
    await old.insert('trips', {'date': '2026-11-24', 'route': 'Nội Vùng', 'from_pts': 'A', 'to_pts': 'B', 'price': 450000, 'note': 'LT1', 'vehicle': vehicles[0]});
    await old.insert('settings', {'k': 'name', 'v': 'Tài xế'});
    await old.close();

    await DB.init();
    expect(await DB.db.getVersion(), 7);
    final ts = await DB.trips();
    expect(ts.length, 1);
    expect(ts.first.price, 450000);
    expect(ts.first.note, 'LT1');
    expect(await DB.get('name'), 'Tài xế');

    expect(await DB.holidayOverrides(), isEmpty);
    await DB.setHolidayOverride('2026-11-25', true);
    await DB.setHolidayOverride('2026-11-24', false);
    expect(await DB.holidayOverrides(), {'2026-11-25': true, '2026-11-24': false});
    await DB.setHolidayOverride('2026-11-25', null);
    expect(await DB.holidayOverrides(), {'2026-11-24': false});

    // Sao lưu/khôi phục mang theo ngày lễ chỉnh tay; file cũ không có khoá thì giữ nguyên.
    final backup = await DB.exportAll();
    expect(backup['holiday_overrides'], isA<List>());
    await DB.importAll(Map<String, dynamic>.from(backup)..remove('holiday_overrides'));
    expect(await DB.holidayOverrides(), {'2026-11-24': false});
    await DB.db.close();
    dir.deleteSync(recursive: true);
  });
}
