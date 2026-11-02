import 'dart:convert';
import 'dart:io';
import 'contacts.dart';
import 'db.dart';

const hubDataRaw =
    'https://raw.githubusercontent.com/Nhanbvt/STN/main/data/hub_data.json';
const hubDataApi =
    'https://api.github.com/repos/Nhanbvt/STN/contents/data/hub_data.json';

String _k(Object? s) => '${s ?? ''}'.trim().toLowerCase();
double? _d(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

/// Kế hoạch gộp dữ liệu admin vào máy (thuần, để test).
class HubMergePlan {
  final hubInserts = <Map<String, Object?>>[];
  final hubLocUpdates = <(int, double, double)>[];
  final phoneInserts = <(String, List<Contact>)>[];
  final phoneUpdates = <(int, List<Contact>)>[];
  /// Chỉ đếm số ĐT mới (chuẩn hoá, chưa có trên máy). Cờ Ko dùng / vị trí không tính.
  int newPhones = 0;
  int hubsWithNewPhones = 0;
  bool get isEmpty =>
      hubInserts.isEmpty &&
      hubLocUpdates.isEmpty &&
      phoneInserts.isEmpty &&
      phoneUpdates.isEmpty;
  String? get phoneNotice => newPhones > 0
      ? 'Đã cập nhật SĐT cho $hubsWithNewPhones hub (thêm $newPhones số mới)'
      : null;
}

/// Kết quả sync: thay đổi bất kỳ + thông báo SĐT mới (null nếu không có số mới).
class HubSyncResult {
  final bool changed;
  final String? phoneNotice;
  const HubSyncResult({this.changed = false, this.phoneNotice});
}

/// Thông báo SĐT chờ hiện (Home / màn hình đang mở).
String? pendingHubPhoneNotice;

/// Gộp: thêm hub thiếu; vị trí admin ghi đè; thêm liên hệ thiếu (theo số); nhận cờ Ko dùng=true. Không xoá gì.
HubMergePlan planHubMerge(List<Map<String, Object?>> hubs,
    List<Map<String, Object?>> phones, Map<String, dynamic> remote) {
  final p = HubMergePlan();
  final hubBy = {for (final h in hubs) _k(h['name']): h};
  final phoneBy = {for (final r in phones) _k(r['name']): r};
  final pendingPhones = <String, (String, List<Contact>)>{};
  for (final item in (remote['hubs'] as List? ?? const []).whereType<Map>()) {
    final name = '${item['name'] ?? ''}'.trim(), k = _k(name);
    if (k.isEmpty) continue;
    final lat = _d(item['lat']), lng = _d(item['lng']);
    final h = hubBy[k];
    if (h == null) {
      final row = {
        'name': name,
        'lat': lat,
        'lng': lng,
        'note': '${item['note'] ?? ''}'.trim()
      };
      p.hubInserts.add(row);
      hubBy[k] = row;
    } else if (lat != null && lng != null && h['id'] is int) {
      final ol = _d(h['lat']), og = _d(h['lng']);
      if (ol == null ||
          og == null ||
          (ol - lat).abs() > 1e-7 ||
          (og - lng).abs() > 1e-7)
        p.hubLocUpdates.add((h['id'] as int, lat, lng));
    }
    final inc = (item['contacts'] as List? ?? const [])
        .whereType<Map>()
        .map(Contact.from)
        .where((c) => c.digits.isNotEmpty)
        .toList();
    final r = phoneBy[k];
    if (r == null) {
      final prev = pendingPhones[k];
      final merged = mergeContacts(prev?.$2 ?? [], inc);
      if (prev != null || inc.isNotEmpty || h == null) {
        pendingPhones[k] = (prev?.$1 ?? name, merged);
      }
    } else if (inc.isNotEmpty && r['id'] is int) {
      final mine = contactsOf(r);
      final before = {for (final c in mine) if (c.digits.isNotEmpty) c.digits};
      final merged = mergeContacts(mine, inc);
      if (!sameContacts(mine, merged)) {
        p.phoneUpdates.add((r['id'] as int, merged));
        final added = merged.where((c) => c.digits.isNotEmpty && !before.contains(c.digits)).length;
        if (added > 0) {
          p.newPhones += added;
          p.hubsWithNewPhones++;
        }
      }
    }
  }
  for (final e in pendingPhones.values) {
    p.phoneInserts.add(e);
    final n = e.$2.where((c) => c.digits.isNotEmpty).length;
    if (n > 0) {
      p.newPhones += n;
      p.hubsWithNewPhones++;
    }
  }
  return p;
}

/// Dữ liệu gửi lên (admin).
Future<Map<String, dynamic>> buildHubData() async {
  final phones = {
    for (final r in await DB.phones()) _k(r['name']): contactsOf(r)
  };
  final hubs = await DB.hubs();
  final names = {for (final h in hubs) _k(h['name'])};
  final now = DateTime.now().toUtc();
  return {
    'version': 1,
    'updatedAt': now.millisecondsSinceEpoch,
    'updatedAtIso': now.toIso8601String(),
    'hubs': [
      for (final h in hubs)
        {
          'name': '${h['name'] ?? ''}'.trim(),
          'lat': h['lat'],
          'lng': h['lng'],
          'note': '${h['note'] ?? ''}',
          'map': h['lat'] != null && h['lng'] != null
              ? 'https://maps.google.com/?q=${h['lat']},${h['lng']}'
              : '',
          'contacts': [
            for (final c in phones[_k(h['name'])] ?? <Contact>[]) c.toJson()
          ],
        },
      for (final r in await DB.phones())
        if (!names.contains(_k(r['name'])) && contactsOf(r).isNotEmpty)
          {
            'name': '${r['name'] ?? ''}'.trim(),
            'lat': null,
            'lng': null,
            'note': '',
            'map': '',
            'contacts': [for (final c in contactsOf(r)) c.toJson()]
          },
    ],
  };
}

Future<void> applyHubPlan(HubMergePlan p) async {
  final b = DB.db.batch();
  for (final h in p.hubInserts) {
    b.insert('hubs', h);
    b.rawInsert(
        'INSERT OR IGNORE INTO places(name, uses) VALUES(?, 0)', [h['name']]);
  }
  for (final u in p.hubLocUpdates) {
    b.update('hubs', {'lat': u.$2, 'lng': u.$3},
        where: 'id=?', whereArgs: [u.$1]);
  }
  for (final (n, cs) in p.phoneInserts) {
    b.insert('phones', {
      'name': n,
      'phone': cs.map((c) => c.phone).join(', '),
      'note': '',
      'contacts': encodeContacts(cs)
    });
    b.rawInsert('INSERT OR IGNORE INTO places(name, uses) VALUES(?, 0)', [n]);
  }
  for (final (id, cs) in p.phoneUpdates) {
    b.update(
        'phones',
        {
          'contacts': encodeContacts(cs),
          'phone': cs.map((c) => c.phone).join(', ')
        },
        where: 'id=?',
        whereArgs: [id]);
  }
  await b.commit(noResult: true);
}

DateTime? _lastTry;

/// Tải dữ liệu hub của admin và gộp. Vị trí im lặng; SĐT mới → pendingHubPhoneNotice.
Future<HubSyncResult> syncHubData({bool force = false}) async {
  if (!force &&
      _lastTry != null &&
      DateTime.now().difference(_lastTry!) < const Duration(minutes: 10)) {
    return const HubSyncResult();
  }
  _lastTry = DateTime.now();
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final req = await c.getUrl(
        Uri.parse('$hubDataRaw?t=${DateTime.now().millisecondsSinceEpoch}'));
    req.headers.set('Cache-Control', 'no-cache');
    final res = await req.close().timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      await res.drain<void>();
      return const HubSyncResult();
    }
    final j = jsonDecode(await res.transform(utf8.decoder).join())
        as Map<String, dynamic>;
    final at = (j['updatedAt'] as num?)?.toInt() ?? 0;
    final last = int.tryParse(await DB.get('hub_data_applied', '0')) ?? 0;
    if (at <= last) return const HubSyncResult();
    final plan = planHubMerge(await DB.hubs(), await DB.phones(), j);
    if (!plan.isEmpty) await applyHubPlan(plan);
    await DB.set('hub_data_applied', '$at');
    if (plan.phoneNotice != null) pendingHubPhoneNotice = plan.phoneNotice;
    return HubSyncResult(changed: !plan.isEmpty, phoneNotice: plan.phoneNotice);
  } catch (_) {
    return const HubSyncResult();
  } finally {
    c.close(force: true);
  }
}

/// Admin: ghi data/hub_data.json lên repo qua GitHub Contents API.
Future<String> pushHubData(String token) async {
  final data = await buildHubData();
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  Future<(int, String)> call(String method, [Object? body]) async {
    final req = await c.openUrl(method,
        Uri.parse(method == 'GET' ? '$hubDataApi?ref=main' : hubDataApi));
    req.headers.set('Accept', 'application/vnd.github+json');
    req.headers.set('Authorization', 'Bearer ${token.trim()}');
    req.headers.set('User-Agent', 'SoThuNhap');
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(body)));
    }
    final res = await req.close();
    return (res.statusCode, await res.transform(utf8.decoder).join());
  }

  try {
    final (gs, gb) = await call('GET');
    String? sha;
    if (gs == 200) {
      sha = (jsonDecode(gb) as Map)['sha'] as String?;
    } else if (gs != 404) {
      throw 'Đọc file lỗi ($gs)';
    }
    final content = base64Encode(
        utf8.encode(const JsonEncoder.withIndent(' ').convert(data)));
    final (ps, pb) = await call('PUT', {
      'message': 'Admin cập nhật dữ liệu hub',
      'content': content,
      'branch': 'main',
      if (sha != null) 'sha': sha
    });
    if (ps != 200 && ps != 201) {
      String msg = pb;
      try {
        msg = '${(jsonDecode(pb) as Map)['message']}';
      } catch (_) {}
      throw 'Lỗi $ps: $msg';
    }
    await DB.set('hub_data_applied', '${data['updatedAt']}');
    return 'Đã đẩy ${(data['hubs'] as List).length} hub lên';
  } finally {
    c.close(force: true);
  }
}
