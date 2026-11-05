import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:so_thu_nhap/db.dart';
import 'package:so_thu_nhap/hub_region.dart';
import 'package:so_thu_nhap/hub_seed.dart';
import 'package:so_thu_nhap/hub_seed_vung.dart';

void main() {
  test('classifyHubRegion rules', () {
    expect(classifyHubRegion('HCMSeller-AIWIBI'), kRegionSeller);
    expect(classifyHubRegion('South Seller-PepsiCo Foods'), kRegionSeller);
    expect(classifyHubRegion('southseller-x'), kRegionSeller);
    expect(classifyHubRegion('70-LAN Tan Hung Hub'), kRegionNoiVung);
    expect(classifyHubRegion('82-TGG My Tho Hub'), kRegionNoiVung);
    expect(classifyHubRegion('81-BTE Cho Lach 02 Hub'), kRegionNoiVung);
    expect(classifyHubRegion('60-BRA Phu My Hub'), kRegionNoiVung);
    expect(classifyHubRegion('51-HCM Warehouse Inbound'), kRegionNoiThanh);
    expect(classifyHubRegion('HCM Mega SOC'), kRegionNoiThanh);
    expect(classifyHubRegion('D4 (Mới)'), kRegionNoiThanh);
    expect(classifyHubRegion('Long An SOC'), kRegionNoiVung); // in seed vung names
    expect(classifyHubRegion('BD A Mega SOC'), kRegionNoiVung);
    expect(classifyHubRegion('Random Custom Hub'), kRegionNoiThanh);
  });

  test('seed vung has expected size and mega', () {
    expect(hubSeedVung.length, equals(478));
    expect(hubSeedVung.any((h) => h.$1 == 'HCM Mega SOC'), true);
    expect(hubSeed.any((h) => h.$1.startsWith('70-LAN') || h.$1.startsWith('82-TGG') || h.$1.startsWith('81-BTE')), true);
  });

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('migration/seed keeps data and classifies; seed does not overwrite', () async {
    await DB.init();
    await DB.db.delete('hubs');
    await DB.db.delete('phones');
    await DB.set('hub_seed_v', '0');
    await DB.set('hub_seed_deleted', '');
    await DB.set('hub_seed_deleted_init', '1');

    // Giả lập hub LAN đã có SĐT + định vị người dùng (không bị đè).
    await DB.db.insert('hubs', {
      'name': '70-LAN Chau Thanh Hub',
      'lat': 1.23,
      'lng': 4.56,
      'note': 'user-note',
      'region': null,
    });
    await DB.db.insert('phones', {
      'name': '70-LAN Chau Thanh Hub',
      'phone': '0900111222',
      'note': '',
      'contacts': '[{"title":"Anh","name":"A","phone":"0900111222","active":true}]',
    });

    final added = await DB.seedHubs();
    expect(added, greaterThan(100));

    final lan = (await DB.db.query('hubs', where: 'name=?', whereArgs: ['70-LAN Chau Thanh Hub'])).first;
    expect(lan['lat'], 1.23); // không đè toạ độ
    expect(lan['lng'], 4.56);
    expect(lan['note'], 'user-note');
    expect(lan['region'], kRegionNoiVung); // chuyển nội vùng

    final phone = (await DB.db.query('phones', where: 'name=?', whereArgs: ['70-LAN Chau Thanh Hub'])).first;
    expect(phone['phone'], '0900111222');

    final mega = (await DB.db.query('hubs', where: "LOWER(TRIM(name))=?", whereArgs: ['hcm mega soc'])).first;
    expect(mega['region'], kRegionNoiThanh);
    expect(mega['lat'], isNotNull);

    final all = await DB.hubs();
    final by = <String, int>{};
    for (final h in all) {
      final r = '${h['region'] ?? ''}'.trim().isEmpty ? classifyHubRegion('${h['name']}') : '${h['region']}';
      by[r] = (by[r] ?? 0) + 1;
    }
    expect(by[kRegionSeller]!, greaterThan(20));
    expect(by[kRegionNoiVung]!, greaterThan(300));
    expect(by[kRegionNoiThanh]!, greaterThan(50));

    // Seed lần 2: không thêm trùng / không đè
    final before = all.length;
    final added2 = await DB.seedHubs();
    expect(added2, 0);
    expect((await DB.hubs()).length, before);
    final lan2 = (await DB.db.query('hubs', where: 'name=?', whereArgs: ['70-LAN Chau Thanh Hub'])).first;
    expect(lan2['lat'], 1.23);
  });
}
