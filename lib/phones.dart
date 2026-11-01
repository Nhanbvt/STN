import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'contacts.dart';
import 'db.dart';
import 'exchange.dart';

const _red = Color(0xFFD32F2F);
const titles = ['Anh', 'Chị'];

Future<void> call(String phone) => launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), '')));

String zaloNum(String phone) {
  var d = phone.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('84')) d = '0${d.substring(2)}';
  if (d.isNotEmpty && !d.startsWith('0')) d = '0$d';
  return d;
}

Future<void> zalo(String phone) => launchUrl(Uri.parse('https://zalo.me/${zaloNum(phone)}'), mode: LaunchMode.externalApplication);

Widget _act(String t, Color c, VoidCallback f) => Padding(padding: const EdgeInsets.only(left: 4), child: OutlinedButton(onPressed: f, style: OutlinedButton.styleFrom(foregroundColor: c, side: BorderSide(color: c), padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap, textStyle: const TextStyle(fontSize: 12)), child: Text(t)));

String shareText(Map h) {
  final cs = contactsOf(h);
  return '📞 ${h['name']}\n${cs.isEmpty ? 'Chưa có SĐT' : cs.map((c) => '• ${c.label}').join('\n')}${'${h['note'] ?? ''}'.isEmpty ? '' : '\n${h['note']}'}';
}

class PhonePage extends StatefulWidget {
  const PhonePage({super.key});
  @override
  State<PhonePage> createState() => _PhonePageState();
}

class _PhonePageState extends State<PhonePage> {
  List<Map<String, Object?>> rows = [];
  String q = '';
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async { rows = await DB.phones(); if (mounted) setState(() {}); }

  Future<void> edit([Map<String, Object?>? h]) async {
    final r = await showDialog<bool>(context: context, builder: (_) => PhoneDialog(item: h));
    if (r == true) load();
  }

  @override
  Widget build(BuildContext context) {
    final shown = rows.where((h) => q.isEmpty || '${h['name']} ${contactsOf(h).map((c) => '${c.label} ${c.digits}').join(' ')} ${h['note']}'.toLowerCase().contains(q.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Số ĐT Hub'), backgroundColor: _red, foregroundColor: Colors.white, actions: [
        PopupMenuButton<String>(onSelected: (v) async {
          if (v == 'exp') await exportPhones(context, rows);
          if (v == 'imp' && await importPhones(context)) load();
        }, itemBuilder: (_) => const [PopupMenuItem(value: 'exp', child: Text('📤 Xuất file')), PopupMenuItem(value: 'imp', child: Text('📥 Nhập & đối chiếu file'))]),
      ]),
      floatingActionButton: FloatingActionButton(backgroundColor: _red, foregroundColor: Colors.white, onPressed: () => edit(), child: const Icon(Icons.add_call)),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(onChanged: (v) => setState(() => q = v), decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Tìm hub / tên / số ĐT...', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30))))),
        Expanded(child: shown.isEmpty ? const Center(child: Text('Chưa có số ĐT. Bấm + để thêm.')) : ListView(padding: const EdgeInsets.only(bottom: 90), children: [
          for (final h in shown) () {
            final cs = sortActiveFirst(contactsOf(h));
            return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: InkWell(
              onTap: () => edit(h),
              child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 0, 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 2, right: 12), child: Icon(cs.isEmpty ? Icons.phone_disabled : Icons.phone, color: cs.isEmpty ? Colors.grey : _red)),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${h['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  if (cs.isEmpty) const Text('Chưa có SĐT', style: TextStyle(color: Colors.grey)),
                  for (final c in cs) Opacity(opacity: c.inactive ? 0.45 : 1, child: InkWell(onTap: () => call(c.phone), child: Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
                    Icon(c.inactive ? Icons.phone_disabled : Icons.call, size: 16, color: c.inactive ? Colors.grey : Colors.green), const SizedBox(width: 6),
                    Expanded(child: Text(c.inactive ? '${c.label} (không dùng nữa)' : c.label, style: TextStyle(fontSize: 14, color: c.inactive ? Colors.grey : Colors.blue, decoration: c.inactive ? TextDecoration.lineThrough : null))),
                    if (c.digits.isNotEmpty) ...[_act('📞 Gọi', c.inactive ? Colors.grey : Colors.green, () => call(c.phone)), _act('💬 Nhắn tin', c.inactive ? Colors.grey : Colors.blue, () => zalo(c.phone))],
                  ])))),
                  if ('${h['note'] ?? ''}'.isNotEmpty) Text('${h['note']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ])),
                PopupMenuButton<String>(onSelected: (v) async {
                  if (v == 'share') await Share.share(shareText(h), subject: '${h['name']}');
                  if (v == 'edit') edit(h);
                  if (v == 'del' && context.mounted) {
                    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text('Xoá số của "${h['name']}"?'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('HUỶ')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('XOÁ'))]));
                    if (ok == true) { await DB.deletePhone(h['id'] as int); load(); }
                  }
                }, itemBuilder: (_) => const [PopupMenuItem(value: 'share', child: Text('📤 Chia sẻ (Zalo...)')), PopupMenuItem(value: 'edit', child: Text('Sửa / thêm SĐT')), PopupMenuItem(value: 'del', child: Text('Xoá'))]),
              ])),
            ));
          }(),
        ])),
      ]),
    );
  }
}

class PhoneDialog extends StatefulWidget {
  final Map<String, Object?>? item;
  const PhoneDialog({super.key, this.item});
  @override
  State<PhoneDialog> createState() => _PhoneDialogState();
}

class _Row { String title; bool inactive; final TextEditingController name, phone; _Row(Contact c) : title = titles.contains(c.title) ? c.title : 'Anh', inactive = c.inactive, name = TextEditingController(text: c.name), phone = TextEditingController(text: c.phone); }

class _PhoneDialogState extends State<PhoneDialog> {
  late final name = TextEditingController(text: '${widget.item?['name'] ?? ''}');
  late final note = TextEditingController(text: '${widget.item?['note'] ?? ''}');
  late final List<_Row> cs = [for (final c in contactsOf(widget.item ?? {})) _Row(c)];
  List<String> names = [];
  @override
  void initState() {
    super.initState();
    if (cs.isEmpty) cs.add(_Row(Contact()));
    () async { final h = (await DB.hubs()).map((e) => '${e['name']}'); final p = await DB.places(); names = {...p, ...h}.toList(); if (mounted) setState(() {}); }();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.item == null ? 'Thêm số ĐT Hub' : 'Sửa số ĐT Hub'),
        content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Autocomplete<String>(
            initialValue: name.value,
            optionsBuilder: (v) => names.where((p) => v.text.isEmpty || p.toLowerCase().contains(v.text.toLowerCase())),
            onSelected: (v) => name.text = v,
            fieldViewBuilder: (c, ctl, fn, _) { ctl.addListener(() => name.text = ctl.text); return TextField(controller: ctl, focusNode: fn, decoration: const InputDecoration(labelText: 'Tên hub')); },
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < cs.length; i++) Card(color: Colors.grey.shade50, margin: const EdgeInsets.symmetric(vertical: 4), child: Padding(padding: const EdgeInsets.fromLTRB(8, 0, 0, 8), child: Column(children: [
            Row(children: [
              DropdownButton<String>(value: cs[i].title, underline: const SizedBox(), items: [for (final t in titles) DropdownMenuItem(value: t, child: Text(t))], onChanged: (v) => setState(() => cs[i].title = v!)),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: cs[i].name, decoration: const InputDecoration(labelText: 'Tên', isDense: true))),
              IconButton(tooltip: 'Xoá liên hệ', icon: const Icon(Icons.remove_circle_outline, color: _red), onPressed: () => setState(() { cs.removeAt(i); if (cs.isEmpty) cs.add(_Row(Contact())); })),
            ]),
            Padding(padding: const EdgeInsets.only(right: 8), child: TextField(controller: cs[i].phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Số điện thoại', isDense: true, prefixIcon: Icon(Icons.phone, size: 18)))),
            CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, value: cs[i].inactive, onChanged: (v) => setState(() => cs[i].inactive = v!), title: const Text('Không dùng nữa', style: TextStyle(fontSize: 13))),
          ]))),
          TextButton.icon(onPressed: () => setState(() => cs.add(_Row(Contact()))), icon: const Icon(Icons.person_add), label: const Text('Thêm số điện thoại')),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Ghi chú (ca trực, cổng...)')),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('HUỶ')),
          FilledButton(onPressed: () async {
            if (name.text.trim().isEmpty) return;
            final list = [for (final r in cs) Contact(title: r.title, name: r.name.text.trim(), phone: r.phone.text.trim(), inactive: r.inactive)].where((c) => c.phone.isNotEmpty || c.name.isNotEmpty).toList();
            await DB.savePhone({'id': widget.item?['id'], 'name': name.text.trim(), 'contacts': list, 'note': note.text.trim()});
            if (context.mounted) Navigator.pop(context, true);
          }, child: const Text('LƯU')),
        ],
      );
}

String _cell(Object? v) { final s = '${v ?? ''}'; return s.contains(RegExp('[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s; }

Future<void> exportPhones(BuildContext context, List<Map<String, Object?>> rows) async {
  final csv = await showDialog<bool>(context: context, builder: (c) => SimpleDialog(title: Text('Xuất Số ĐT Hub (${rows.length})'), children: [
    SimpleDialogOption(onPressed: () => Navigator.pop(c, false), child: const Text('📄 File JSON (nhập lại vào app)')),
    SimpleDialogOption(onPressed: () => Navigator.pop(c, true), child: const Text('📊 File CSV (mở bằng Excel / Google Sheets)')),
  ]));
  if (csv == null) return;
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/so_thu_nhap_phones_${DateTime.now().toIso8601String().substring(0, 10)}.${csv ? 'csv' : 'json'}');
  if (csv) {
    final b = StringBuffer('\uFEFFname,title,contact_name,phone,status,note\n');
    for (final r in rows) {
      final cs = contactsOf(r);
      for (final c in cs.isEmpty ? [Contact(title: '')] : cs) { b.writeln([r['name'], c.title, c.name, c.phone, c.phone.isEmpty ? '' : (c.inactive ? 'inactive' : 'active'), r['note']].map(_cell).join(',')); }
    }
    await f.writeAsString(b.toString());
  } else {
    await f.writeAsString(const JsonEncoder.withIndent(' ').convert({'app': 'so_thu_nhap', 'kind': 'phones', 'version': 2, 'items': [
      for (final r in rows) {'name': r['name'], 'phone': contactsOf(r).map((c) => c.phone).join(', '), 'note': r['note'] ?? '', 'contacts': contactsOf(r).map((c) => c.toJson()).toList()},
    ]}));
  }
  await Share.shareXFiles([XFile(f.path)], text: 'Số ĐT Hub - Sổ Thu Nhập');
}

/// Đọc file (JSON mới/cũ hoặc CSV mới/cũ) → {tên hub: (tên gốc, liên hệ, ghi chú)} gộp theo tên.
Map<String, (String, List<Contact>, String)> parsePhoneFile(String text) {
  final t = text.replaceFirst('\uFEFF', '').trim();
  List<Map> raw;
  if (t.startsWith('{') || t.startsWith('[')) {
    final j = jsonDecode(t);
    raw = (j is List ? j : (j['items'] ?? j['phones'] ?? []) as List).cast<Map>();
  } else {
    final rows = parseCsv(t);
    if (rows.isEmpty) return {};
    const alias = {'tên': 'name', 'ten': 'name', 'tên hub': 'name', 'sđt': 'phone', 'sdt': 'phone', 'số điện thoại': 'phone', 'ghi chú': 'note', 'danh xưng': 'title', 'tên liên hệ': 'contact_name', 'trạng thái': 'status', 'trang thai': 'status'};
    final head = rows.first.map((e) => e.trim().toLowerCase()).map((h) => alias[h] ?? h).toList();
    final hasHead = head.contains('name');
    final cols = hasHead ? head : ['name', 'phone', 'note'];
    raw = [for (final r in rows.skip(hasHead ? 1 : 0)) {for (var i = 0; i < cols.length && i < r.length; i++) cols[i]: r[i]}];
  }
  final out = <String, (String, List<Contact>, String)>{};
  for (final m in raw) {
    final (n, cs, note) = contactsFromItem(m);
    if (n.isEmpty) continue;
    final k = DB.key(n);
    final prev = out[k];
    out[k] = prev == null ? (n, cs, note) : (prev.$1, mergeContacts(prev.$2, cs), prev.$3.isEmpty ? note : prev.$3);
  }
  return out;
}

Future<bool> importPhones(BuildContext context) async {
  final m = ScaffoldMessenger.of(context);
  final r = await FilePicker.pickFiles(type: FileType.any, withData: true);
  final bytes = r?.files.single.bytes;
  if (bytes == null) return false;
  Map<String, (String, List<Contact>, String)> inc;
  try { inc = parsePhoneFile(utf8.decode(bytes, allowMalformed: true)); } catch (e) { m.showSnackBar(SnackBar(content: Text('File không đúng định dạng: $e'))); return false; }
  if (inc.isEmpty) { m.showSnackBar(const SnackBar(content: Text('File không có dữ liệu'))); return false; }
  final mine = {for (final x in await DB.phones()) DB.key(x['name']): x};
  final add = <(String, List<Contact>, String)>[];
  final chg = <(Map<String, Object?>, List<Contact>, List<Contact>, String)>[];
  for (final e in inc.entries) {
    final old = mine[e.key];
    if (old == null) { add.add(e.value); continue; }
    final cur = contactsOf(old), merged = mergeContacts(cur, e.value.$2);
    final note = '${old['note'] ?? ''}'.isEmpty ? e.value.$3 : '${old['note']}';
    if (!sameContacts(cur, merged) || note != '${old['note'] ?? ''}') chg.add((old, cur, merged, note));
  }
  if (add.isEmpty && chg.isEmpty) { m.showSnackBar(SnackBar(content: Text('Đã đối chiếu ${inc.length} hub: không có gì mới'))); return false; }
  if (!context.mounted) return false;
  final pick = {for (var i = 0; i < chg.length; i++) i};
  String fmt(List<Contact> cs) => cs.isEmpty ? '(trống)' : cs.map((c) => c.inactive ? '${c.label} ⛔ không dùng nữa' : c.label).join('\n');
  final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, ss) => AlertDialog(
    title: const Text('Đối chiếu Số ĐT Hub'),
    content: SizedBox(width: 420, child: ListView(shrinkWrap: true, children: [
      Text('File có ${inc.length} hub.\n➕ Hub mới: ${add.length}\n✏️ Có SĐT mới / khác: ${chg.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
      if (add.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Mới: ${add.take(15).map((e) => e.$1).join(', ')}${add.length > 15 ? '…' : ''}', style: const TextStyle(fontSize: 12))),
      if (chg.isNotEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Chọn hub muốn cập nhật theo file (SĐT cũ vẫn giữ, số "không dùng nữa" chỉ bị đánh dấu, không xoá):')),
      for (var i = 0; i < chg.length; i++) CheckboxListTile(dense: true, value: pick.contains(i), onChanged: (v) => ss(() => v! ? pick.add(i) : pick.remove(i)),
        title: Text('${chg[i].$1['name']}'), subtitle: Text('Đang có:\n${fmt(chg[i].$2)}\nSau khi cập nhật:\n${fmt(chg[i].$3)}')),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('HUỶ')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('CẬP NHẬT'))],
  )));
  if (ok != true) return false;
  for (final a in add) { await DB.savePhone({'id': null, 'name': a.$1, 'contacts': a.$2, 'note': a.$3}); }
  for (final i in pick) { final (old, _, merged, note) = chg[i]; await DB.savePhone({...old, 'contacts': merged, 'note': note}); }
  m.showSnackBar(SnackBar(content: Text('Đã thêm ${add.length} hub, cập nhật ${pick.length} hub')));
  return true;
}
