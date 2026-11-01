import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'db.dart';
import 'exchange.dart';

const _red = Color(0xFFD32F2F);
const phoneFields = ['name', 'phone', 'note'];

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
    final shown = rows.where((h) => q.isEmpty || '${h['name']} ${h['phone']} ${h['note']}'.toLowerCase().contains(q.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Số ĐT Hub'), backgroundColor: _red, foregroundColor: Colors.white, actions: [
        PopupMenuButton<String>(onSelected: (v) async {
          if (v == 'exp') await exportItems(context, 'phones', 'Số ĐT Hub', rows, phoneFields);
          if (v == 'imp' && await importItems(context, 'phones', 'Số ĐT Hub', phoneFields, DB.phones, DB.savePhone)) load();
        }, itemBuilder: (_) => const [PopupMenuItem(value: 'exp', child: Text('📤 Xuất file')), PopupMenuItem(value: 'imp', child: Text('📥 Nhập & đối chiếu file'))]),
      ]),
      floatingActionButton: FloatingActionButton(backgroundColor: _red, foregroundColor: Colors.white, onPressed: () => edit(), child: const Icon(Icons.add_call)),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(onChanged: (v) => setState(() => q = v), decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Tìm hub / số ĐT...', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30))))),
        Expanded(child: shown.isEmpty ? const Center(child: Text('Chưa có số ĐT. Bấm + để thêm.')) : ListView(padding: const EdgeInsets.only(bottom: 90), children: [
          for (final h in shown) Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(
            leading: Icon('${h['phone'] ?? ''}'.trim().isEmpty ? Icons.phone_disabled : Icons.phone, color: '${h['phone'] ?? ''}'.trim().isEmpty ? Colors.grey : _red),
            title: Text('${h['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${'${h['phone'] ?? ''}'.isEmpty ? 'Chưa có SĐT' : h['phone']}${'${h['note'] ?? ''}'.isEmpty ? '' : '\n${h['note']}'}'),
            onTap: () => '${h['phone'] ?? ''}'.trim().isEmpty ? edit(h) : launchUrl(Uri(scheme: 'tel', path: '${h['phone']}'.replaceAll(RegExp(r'[^\d+]'), ''))),
            trailing: PopupMenuButton<String>(onSelected: (v) async {
              if (v == 'call' && '${h['phone'] ?? ''}'.trim().isEmpty) { edit(h); return; }
              if (v == 'call') await launchUrl(Uri(scheme: 'tel', path: '${h['phone']}'.replaceAll(RegExp(r'[^\d+]'), '')));
              if (v == 'share') await Share.share('📞 ${h['name']}: ${h['phone']}', subject: '${h['name']}');
              if (v == 'edit') edit(h);
              if (v == 'del' && context.mounted) {
                final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text('Xoá số của "${h['name']}"?'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('HUỶ')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('XOÁ'))]));
                if (ok == true) { await DB.deletePhone(h['id'] as int); load(); }
              }
            }, itemBuilder: (_) => const [PopupMenuItem(value: 'call', child: Text('📞 Gọi')), PopupMenuItem(value: 'share', child: Text('📤 Chia sẻ (Zalo...)')), PopupMenuItem(value: 'edit', child: Text('Sửa')), PopupMenuItem(value: 'del', child: Text('Xoá'))]),
          )),
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

class _PhoneDialogState extends State<PhoneDialog> {
  late final name = TextEditingController(text: '${widget.item?['name'] ?? ''}');
  late final phone = TextEditingController(text: '${widget.item?['phone'] ?? ''}');
  late final note = TextEditingController(text: '${widget.item?['note'] ?? ''}');
  List<String> names = [];
  @override
  void initState() {
    super.initState();
    () async { final h = (await DB.hubs()).map((e) => '${e['name']}'); final p = await DB.places(); names = {...p, ...h}.toList(); if (mounted) setState(() {}); }();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.item == null ? 'Thêm số ĐT Hub' : 'Sửa số ĐT Hub'),
        content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Autocomplete<String>(
            initialValue: name.value,
            optionsBuilder: (v) => names.where((p) => v.text.isEmpty || p.toLowerCase().contains(v.text.toLowerCase())),
            onSelected: (v) => name.text = v,
            fieldViewBuilder: (c, ctl, fn, _) { ctl.addListener(() => name.text = ctl.text); return TextField(controller: ctl, focusNode: fn, decoration: const InputDecoration(labelText: 'Tên hub')); },
          ),
          const SizedBox(height: 8),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Số điện thoại')),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Ghi chú (tên người, ca trực...)')),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('HUỶ')),
          FilledButton(onPressed: () async {
            if (name.text.trim().isEmpty) return;
            await DB.savePhone({'id': widget.item?['id'], 'name': name.text.trim(), 'phone': phone.text.trim(), 'note': note.text.trim()});
            if (context.mounted) Navigator.pop(context, true);
          }, child: const Text('LƯU')),
        ],
      );
}
