import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

const releasesApi = 'https://api.github.com/repos/Nhanbvt/STN/releases/latest';

/// So sánh "1.0.12" vs "1.0.9" theo từng số.
int compareVersions(String a, String b) {
  List<int> p(String s) => s.replaceFirst(RegExp(r'^v'), '').split(RegExp(r'[.+]')).map((e) => int.tryParse(e) ?? 0).toList();
  final x = p(a), y = p(b);
  for (var i = 0; i < 4; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

Future<void> checkForUpdate(BuildContext context, {bool silent = true}) async {
  if (!Platform.isAndroid) {
    // iOS: không cài APK được → mở trang phát hành trên GitHub.
    if (!silent) await launchUrl(Uri.parse('https://github.com/Nhanbvt/STN/releases/latest'), mode: LaunchMode.externalApplication);
    return;
  }
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final info = await PackageInfo.fromPlatform();
    final req = await c.getUrl(Uri.parse(releasesApi));
    req.headers.set('Accept', 'application/vnd.github+json');
    req.headers.set('User-Agent', 'SoThuNhap');
    final res = await req.close();
    if (res.statusCode != 200) throw 'Không có bản phát hành (${res.statusCode})';
    final j = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
    final latest = '${j['tag_name']}'.replaceFirst('v', '');
    final current = info.version;
    final asset = (j['assets'] as List).cast<Map>().where((a) => '${a['name']}'.endsWith('.apk')).firstOrNull;
    if (compareVersions(latest, current) <= 0 || asset == null) {
      if (!silent && context.mounted) _snack(context, 'Bạn đang dùng bản mới nhất ($current)');
      return;
    }
    if (!context.mounted) return;
    final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
      title: Text('Có bản mới $latest'),
      content: SingleChildScrollView(child: Text('Bản hiện tại: $current\n\n${j['body'] ?? ''}\n\nDữ liệu trong app được giữ nguyên khi cập nhật.')),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('ĐỂ SAU')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('CẬP NHẬT'))],
    ));
    if (ok != true || !context.mounted) return;
    await _downloadAndInstall(context, '${asset['browser_download_url']}', (asset['size'] as num?)?.toInt() ?? 0, latest);
  } catch (e) {
    if (!silent && context.mounted) _snack(context, 'Lỗi kiểm tra cập nhật: $e');
  } finally {
    c.close();
  }
}

Future<void> _downloadAndInstall(BuildContext context, String url, int size, String ver) async {
  final progress = ValueNotifier<double>(0);
  showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
    title: Text('Đang tải bản $ver'),
    content: ValueListenableBuilder<double>(valueListenable: progress, builder: (_, v, __) => Column(mainAxisSize: MainAxisSize.min, children: [LinearProgressIndicator(value: v > 0 ? v : null), const SizedBox(height: 8), Text('${(v * 100).toStringAsFixed(0)}%')])),
  ));
  final c = HttpClient();
  try {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/SoThuNhap-$ver.apk');
    final res = await (await c.getUrl(Uri.parse(url))).close();
    final total = res.contentLength > 0 ? res.contentLength : size;
    final sink = f.openWrite();
    var got = 0;
    await for (final chunk in res) { sink.add(chunk); got += chunk.length; if (total > 0) progress.value = got / total; }
    await sink.close();
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    final r = await OpenFilex.open(f.path, type: 'application/vnd.android.package-archive');
    if (r.type != ResultType.done && context.mounted) _snack(context, 'Không mở được trình cài đặt: ${r.message}. Hãy cho phép "Cài ứng dụng không rõ nguồn gốc" cho Sổ Thu Nhập.');
  } catch (e) {
    if (context.mounted) { Navigator.of(context, rootNavigator: true).pop(); _snack(context, 'Lỗi tải: $e'); }
  } finally { c.close(); }
}

void _snack(BuildContext c, String s) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(s)));
