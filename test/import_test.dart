import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:so_thu_nhap/db.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  test('import old Android export', () async {
    await DB.init();
    final d = jsonDecode(File('test/fixtures/old_export.json').readAsStringSync()) as Map<String, dynamic>;
    expect(DB.isOldFormat(d), true);
    print(await DB.importOld(d));
    final trips = await DB.trips();
    expect(trips.length, 621);
    expect((await DB.fuels()).length, 112);
    expect(await DB.get('driver_id'), '132253');
    final old = <String, int>{}, neu = <String, int>{};
    for (final m in (d['trips'] as List).cast<Map>()) { final k = '${m['date']}'.substring(0, 7); old[k] = (old[k] ?? 0) + (m['amount'] as num).toInt(); }
    for (final t in trips) { final k = t.date.substring(0, 7); neu[k] = (neu[k] ?? 0) + t.price; }
    for (final k in old.keys) { print('$k old=${old[k]} new=${neu[k]} diff=${neu[k]! - old[k]!} cong=${Payroll.of(trips.where((t) => t.date.startsWith(k)).toList()).cong}'); }
    final byCode = {for (final m in (d['trips'] as List).cast<Map>()) '${m['tripCode']}': (m['amount'] as num).toInt()};
    for (final t in trips) { if (t.note.isNotEmpty && byCode[t.note] != t.price) print('DIFF ${t.date} ${t.note} old=${byCode[t.note]} new=${t.price} ${t.fromText} -> ${t.toText} band=${t.bandId}'); }
    final ghep = trips.firstWhere((t) => t.note == 'LT1QAI51CNNT1');
    expect(ghep.from.length, 3);
    expect(ghep.price, 258400);
  });
}
