import 'package:flutter_test/flutter_test.dart';
import 'package:so_thu_nhap/contact_upload.dart';
import 'package:so_thu_nhap/contacts.dart';
import 'package:so_thu_nhap/hub_sync.dart';

void main() {
  test('iso week & weekend rule', () {
    expect(isoWeek(DateTime(2026, 1, 1)), '2026-W01');
    expect(isoWeek(DateTime(2027, 1, 3)), '2026-W53');
    expect(isoWeek(DateTime(2026, 11, 1)), '2026-W44');
    final sat = DateTime(2026, 11, 7);
    expect(shouldAutoUpload(sat, ''), true);
    expect(shouldAutoUpload(sat, isoWeek(sat)), false);
    expect(shouldAutoUpload(DateTime(2026, 11, 8), isoWeek(sat)), false); // CN cùng tuần
    expect(shouldAutoUpload(DateTime(2026, 11, 4), ''), false);
  });

  test('upload payload', () {
    final d = buildContactUpload([
      {'name': 'Hub A', 'contacts': encodeContacts([Contact(title: 'Chị', name: 'Lan', phone: '0901', inactive: true)])},
      {'name': 'Hub B', 'phone': ''},
    ], device: 'id', version: '1.2.6', now: DateTime.utc(2026));
    expect(d['hubs'], [{'name': 'Hub A', 'contacts': [{'title': 'Chị', 'name': 'Lan', 'phone': '0901', 'active': false}]}]);
  });

  test('download: adds contacts to hubs with no number, skips existing numbers', () {
    final phones = <Map<String, Object?>>[
      {'id': 1, 'name': 'Hub Empty', 'phone': '', 'contacts': null},
      {'id': 2, 'name': 'Hub Has', 'contacts': encodeContacts([Contact(name: 'Cũ', phone: '090 123 4567')])},
    ];
    final p = planHubMerge([], phones, {'hubs': [
      {'name': 'hub empty', 'contacts': [{'name': 'X', 'phone': '0911'}]},
      {'name': 'Hub Has', 'contacts': [{'name': 'Khác', 'phone': '84901234567'}, {'name': 'Mới', 'phone': '0922'}]},
    ]});
    expect(p.hubInserts.map((h) => h['name']), ['hub empty', 'Hub Has']); // hub chưa có trong Vị trí Hub → thêm
    final up = {for (final u in p.phoneUpdates) u.$1: u.$2};
    expect(up[1]!.map((c) => c.phone), ['0911']);
    expect(up[2]!.map((c) => '${c.name}:${c.phone}'), ['Cũ:090 123 4567', 'Mới:0922']);
    expect(p.phoneInserts, isEmpty);
    expect(p.newPhones, 2); // 0911 + 0922; 84901234567 trùng
    expect(p.hubsWithNewPhones, 2);
    expect(p.phoneNotice, contains('thêm 2 số mới'));
  });
}
