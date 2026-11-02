import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:package_info_plus/package_info_plus.dart';
import 'contacts.dart';
import 'db.dart';

const _uploadToken = String.fromEnvironment('STN_UPLOAD_TOKEN');
const _dataRepo = 'https://api.github.com/repos/Nhanbvt/STN-data/contents';

/// Tuần ISO dạng yyyy-Www.
String isoWeek(DateTime d) {
  final day = DateTime.utc(d.year, d.month, d.day);
  final thu = day.add(Duration(days: 4 - day.weekday));
  final w = ((thu.difference(DateTime.utc(thu.year, 1, 1)).inDays) ~/ 7) + 1;
  return '${thu.year}-W${w.toString().padLeft(2, '0')}';
}

bool isWeekend(DateTime d) =>
    d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

/// Có nên tự tải lên lúc [now]? Cuối tuần và tuần này chưa tải.
bool shouldAutoUpload(DateTime now, String lastWeek) =>
    isWeekend(now) && lastWeek != isoWeek(now);

String _uuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

Future<String> deviceId() async {
  var id = await DB.get('device_id');
  if (id.isEmpty) {
    id = _uuid();
    await DB.set('device_id', id);
  }
  return id;
}

/// Dữ liệu SĐT hub gửi lên (cùng định dạng hub_data.json, chỉ có contacts).
Map<String, dynamic> buildContactUpload(List<Map<String, Object?>> phones,
        {required String device,
        required String version,
        required DateTime now}) =>
    {
      'device': device,
      'appVersion': version,
      'uploadedAt': now.toUtc().toIso8601String(),
      'hubs': [
        for (final r in phones)
          if ('${r['name'] ?? ''}'.trim().isNotEmpty &&
              contactsOf(r).isNotEmpty)
            {
              'name': '${r['name']}'.trim(),
              'contacts': [for (final c in contactsOf(r)) c.toJson()]
            },
      ],
    };

bool _busy = false;

/// Tự tải lên im lặng (cuối tuần, mỗi tuần 1 lần). [force]: tải ngay (Admin). Trả thông báo cho Admin.
Future<String> uploadContacts({bool force = false}) async {
  if (_uploadToken.isEmpty) return 'Bản này không có token tải lên';
  if (_busy) return 'Đang tải...';
  final now = DateTime.now();
  if (!force && !shouldAutoUpload(now, await DB.get('contact_upload_week')))
    return '';
  _busy = true;
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final id = await deviceId();
    final info = await PackageInfo.fromPlatform();
    final data = buildContactUpload(await DB.phones(),
        device: id, version: info.version, now: now);
    final url = Uri.parse('$_dataRepo/uploads/${isoWeek(now)}/$id.json');
    Future<(int, String)> call(String m, [Object? body]) async {
      final req = await c.openUrl(m, url);
      req.headers.set('Accept', 'application/vnd.github+json');
      req.headers.set('Authorization', 'Bearer $_uploadToken');
      req.headers.set('User-Agent', 'SoThuNhap');
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.add(utf8.encode(jsonEncode(body)));
      }
      final res = await req.close().timeout(const Duration(seconds: 30));
      return (res.statusCode, await res.transform(utf8.decoder).join());
    }

    final (gs, gb) = await call('GET');
    final sha = gs == 200 ? (jsonDecode(gb) as Map)['sha'] as String? : null;
    final (ps, _) = await call('PUT', {
      'message': 'upload $id',
      'content': base64Encode(utf8.encode(jsonEncode(data))),
      if (sha != null) 'sha': sha,
    });
    if (ps != 200 && ps != 201) return 'Lỗi tải lên ($ps)';
    await DB.set('contact_upload_week', isoWeek(now));
    return 'Đã tải lên ${(data['hubs'] as List).length} hub';
  } catch (e) {
    return 'Lỗi tải lên';
  } finally {
    _busy = false;
    c.close(force: true);
  }
}
