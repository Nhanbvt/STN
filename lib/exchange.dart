import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'db.dart';

/// Xuất / nhập danh sách (hub, số ĐT) để anh em đối chiếu & cập nhật cho nhau.
/// File JSON: {"app":"so_thu_nhap","kind":"hubs","items":[...]} hoặc CSV có dòng tiêu đề.
String _csvCell(Object? v) { final s = '${v ?? ''}'; return s.contains(RegExp('[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s; }

List<List<String>> parseCsv(String s) {
  final rows = <List<String>>[]; var row = <String>[]; final cell = StringBuffer(); var q = false;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (q) {
      if (c == '"') { if (i + 1 < s.length && s[i + 1] == '"') { cell.write('"'); i++; } else { q = false; } } else { cell.write(c); }
    } else if (c == '"') { q = true; }
    else if (c == ',' || c == ';') { row.add(cell.toString()); cell.clear(); }
    else if (c == '\n' || c == '\r') { if (c == '\r' && i + 1 < s.length && s[i + 1] == '\n') i++; row.add(cell.toString()); cell.clear(); if (row.any((e) => e.trim().isNotEmpty)) rows.add(row); row = <String>[]; }
    else { cell.write(c); }
  }
  row.add(cell.toString()); if (row.any((e) => e.trim().isNotEmpty)) rows.add(row);
  return rows;
}

/// Đọc nội dung file → danh sách bản ghi chỉ gồm [fields] (luôn có 'name').
List<Map<String, Object?>> parseItems(String text, String kind, List<String> fields) {
  final t = text.replaceFirst('\uFEFF', '').trim();
  List<Map> raw;
  if (t.startsWith('{') || t.startsWith('[')) {
    final j = jsonDecode(t);
    raw = (j is List ? j : (j['items'] ?? j[kind] ?? []) as List).cast<Map>();
  } else {
    final rows = parseCsv(t);
    if (rows.isEmpty) return [];
    final head = rows.first.map((e) => e.trim().toLowerCase()).toList();
    final hasHead = head.contains('name') || head.contains('tên') || head.contains('ten');
    final cols = hasHead ? head.map((h) => const {'tên': 'name', 'ten': 'name', 'sđt': 'phone', 'sdt': 'phone', 'số điện thoại': 'phone', 'ghi chú': 'note', 'ghi chu': 'note'}[h] ?? h).toList() : ['name', ...fields.where((f) => f != 'name')];
    raw = [for (final r in rows.skip(hasHead ? 1 : 0)) {for (var i = 0; i < cols.length && i < r.length; i++) cols[i]: r[i]}];
  }
  num? n(Object? v) => v is num ? v : double.tryParse('${v ?? ''}'.trim());
  return [
    for (final m in raw)
      if ('${m['name'] ?? ''}'.trim().isNotEmpty)
        {for (final f in fields) f: (f == 'lat' || f == 'lng') ? n(m[f]) : '${m[f] ?? ''}'.trim()},
  ];
}

Future<void> exportItems(BuildContext context, String kind, String title, List<Map<String, Object?>> rows, List<String> fields) async {
  final csv = await showDialog<bool>(context: context, builder: (c) => SimpleDialog(title: Text('Xuất $title (${rows.length})'), children: [
    SimpleDialogOption(onPressed: () => Navigator.pop(c, false), child: const Text('📄 File JSON (nhập lại vào app)')),
    SimpleDialogOption(onPressed: () => Navigator.pop(c, true), child: const Text('📊 File CSV (mở bằng Excel / Google Sheets)')),
  ]));
  if (csv == null) return;
  final dir = await getTemporaryDirectory();
  final stamp = DateTime.now().toIso8601String().substring(0, 10);
  final f = File('${dir.path}/so_thu_nhap_${kind}_$stamp.${csv ? 'csv' : 'json'}');
  final items = [for (final r in rows) {for (final k in fields) k: r[k]}];
  await f.writeAsString(csv
      ? '\uFEFF${fields.join(',')}\n${items.map((r) => fields.map((k) => _csvCell(r[k])).join(',')).join('\n')}\n'
      : const JsonEncoder.withIndent(' ').convert({'app': 'so_thu_nhap', 'kind': kind, 'items': items}));
  await Share.shareXFiles([XFile(f.path)], text: '$title - Sổ Thu Nhập');
}

/// Nhập & đối chiếu theo tên: thêm mục chưa có; mục khác thông tin thì hỏi trước khi cập nhật.
Future<bool> importItems(BuildContext context, String kind, String title, List<String> fields, Future<List<Map<String, Object?>>> Function() mine, Future<void> Function(Map<String, Object?>) save) async {
  final m = ScaffoldMessenger.of(context);
  final r = await FilePicker.pickFiles(type: FileType.any, withData: true);
  final bytes = r?.files.single.bytes;
  if (bytes == null) return false;
  List<Map<String, Object?>> inc;
  try { inc = parseItems(utf8.decode(bytes, allowMalformed: true), kind, fields); } catch (e) { m.showSnackBar(SnackBar(content: Text('File không đúng định dạng: $e'))); return false; }
  if (inc.isEmpty) { m.showSnackBar(const SnackBar(content: Text('File không có dữ liệu'))); return false; }
  final (add, chg) = DB.diff(await mine(), inc, fields.where((f) => f != 'name').toList());
  if (add.isEmpty && chg.isEmpty) { m.showSnackBar(SnackBar(content: Text('Đã đối chiếu ${inc.length} mục: không có gì mới'))); return false; }
  if (!context.mounted) return false;
  final pick = {for (var i = 0; i < chg.length; i++) i};
  String show(Map<String, Object?> x) => fields.where((f) => f != 'name' && '${x[f] ?? ''}'.isNotEmpty).map((f) => '${x[f]}').join(' · ');
  final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, ss) => AlertDialog(
    title: Text('Đối chiếu $title'),
    content: SizedBox(width: 400, child: ListView(shrinkWrap: true, children: [
      Text('File có ${inc.length} mục.\n➕ Thêm mới: ${add.length}\n✏️ Khác thông tin: ${chg.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
      if (add.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Mới: ${add.take(15).map((e) => e['name']).join(', ')}${add.length > 15 ? '…' : ''}', style: const TextStyle(fontSize: 12))),
      if (chg.isNotEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Chọn mục muốn cập nhật theo file:')),
      for (var i = 0; i < chg.length; i++) CheckboxListTile(dense: true, value: pick.contains(i), onChanged: (v) => ss(() => v! ? pick.add(i) : pick.remove(i)),
        title: Text('${chg[i].$1['name']}'), subtitle: Text('Đang có: ${show(chg[i].$1)}\nTrong file: ${show(chg[i].$2)}')),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('HUỶ')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('CẬP NHẬT'))],
  )));
  if (ok != true) return false;
  for (final a in add) { await save({...a, 'id': null}); }
  for (final i in pick) {
    final (old, n) = chg[i];
    await save({...old, for (final f in fields) if (f != 'name' && n[f] != null && '${n[f]}'.trim().isNotEmpty) f: n[f]});
  }
  m.showSnackBar(SnackBar(content: Text('Đã thêm ${add.length}, cập nhật ${pick.length} mục')));
  return true;
}
