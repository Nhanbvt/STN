import 'package:flutter_test/flutter_test.dart';
import 'package:so_thu_nhap/contacts.dart';
import 'package:so_thu_nhap/hub_sync.dart';

void main() {
  test('merge admin hub data', () {
    final hubs = <Map<String, Object?>>[
      {'id': 1, 'name': 'Hub A', 'lat': 10.0, 'lng': 106.0, 'note': 'x'},
      {'id': 2, 'name': 'Hub B', 'lat': 11.0, 'lng': 107.0, 'note': ''},
    ];
    final phones = <Map<String, Object?>>[
      {'id': 5, 'name': 'hub a', 'contacts': encodeContacts([Contact(name: 'Tú', phone: '0901 234 567')])},
    ];
    final remote = {
      'updatedAt': 1,
      'hubs': [
        {'name': 'HUB A', 'lat': 10.5, 'lng': 106.5, 'contacts': [
          {'title': 'Chị', 'name': 'Khác', 'phone': '+84901234567', 'active': false},
          {'title': 'Anh', 'name': 'Mới', 'phone': '0911111111'},
        ]},
        {'name': 'Hub B', 'lat': 11.0, 'lng': 107.0, 'contacts': []},
        {'name': 'Hub C', 'lat': 12.0, 'lng': 108.0, 'note': 'n', 'contacts': [{'name': 'C', 'phone': '0922'}]},
        {'name': '', 'lat': 1, 'lng': 1},
      ],
    };
    final p = planHubMerge(hubs, phones, remote);
    expect(p.hubInserts.map((h) => h['name']), ['Hub C']);
    expect(p.hubLocUpdates, [(1, 10.5, 106.5)]);
    expect(p.phoneInserts.map((e) => e.$1), ['Hub C']);
    expect(p.phoneUpdates.length, 1);
    final cs = p.phoneUpdates.first.$2;
    expect(cs.length, 2);
    expect(cs[0].name, 'Tú'); // không sửa tên
    expect(cs[0].inactive, true); // nhận cờ Ko dùng
    expect(cs[1].phone, '0911111111');
    expect(p.newPhones, 2); // Hub A: 0911111111; Hub C: 0922 (trùng 0901 bỏ qua)
    expect(p.hubsWithNewPhones, 2); // Hub A + Hub C
    expect(p.phoneNotice, 'Đã cập nhật SĐT cho 2 hub (thêm 2 số mới)');
  });

  test('location-only and inactive-only: no phone notice', () {
    final hubs = <Map<String, Object?>>[
      {'id': 1, 'name': 'A', 'lat': 1.0, 'lng': 2.0},
    ];
    final phones = <Map<String, Object?>>[
      {'id': 9, 'name': 'A', 'contacts': encodeContacts([Contact(phone: '0901', inactive: false)])},
    ];
    final loc = planHubMerge(hubs, phones, {'hubs': [
      {'name': 'A', 'lat': 9.0, 'lng': 9.0, 'contacts': [{'phone': '0901', 'active': false}]},
    ]});
    expect(loc.hubLocUpdates.length, 1);
    expect(loc.newPhones, 0);
    expect(loc.phoneNotice, isNull);
    expect(loc.phoneUpdates.length, 1); // cờ Ko dùng vẫn ghi
  });

  test('never re-activates and is idempotent', () {
    final phones = <Map<String, Object?>>[
      {'id': 5, 'name': 'A', 'contacts': encodeContacts([Contact(phone: '0901', inactive: true)])},
    ];
    final p = planHubMerge([{'id': 1, 'name': 'A', 'lat': 1.0, 'lng': 2.0}], phones, {'hubs': [{'name': 'A', 'lat': 1.0, 'lng': 2.0, 'contacts': [{'phone': '0901', 'active': true}]}]});
    expect(p.isEmpty, true);
  });

  test('empty / malformed remote', () {
    expect(planHubMerge([], [], {}).isEmpty, true);
    expect(planHubMerge([], [], {'hubs': ['x', 1]}).isEmpty, true);
  });

  test('remote region applied on insert; old clients without region classify', () {
    final p = planHubMerge([], [], {'hubs': [
      {'name': '70-LAN X', 'lat': 1.0, 'lng': 2.0, 'region': 'noi_vung', 'contacts': []},
      {'name': 'HCMSeller-Y', 'lat': 1.0, 'lng': 2.0, 'contacts': []},
    ]});
    expect(p.hubInserts.length, 2);
    expect(p.hubInserts[0]['region'], 'noi_vung');
    expect(p.hubInserts[1]['region'], 'seller'); // classify by name
  });
}
