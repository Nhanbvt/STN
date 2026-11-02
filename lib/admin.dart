import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'db.dart';
import 'hub_sync.dart';
import 'contact_upload.dart';

String pinHash(String pin) =>
    sha256.convert(utf8.encode('stn-admin:$pin')).toString();
const _defaultPin = '2468';

Future<bool> checkPin(String pin) async {
  final h = await DB.get('admin_pin_hash');
  return h.isEmpty ? pin == _defaultPin : h == pinHash(pin);
}

Future<void> openAdmin(BuildContext context) async {
  final ctl = TextEditingController();
  final pin = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
            content: TextField(
                controller: ctl,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'PIN')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c), child: const Text('HUỶ')),
              FilledButton(
                  onPressed: () => Navigator.pop(c, ctl.text),
                  child: const Text('OK'))
            ],
          ));
  if (pin == null || !context.mounted) return;
  if (!await checkPin(pin)) {
    if (context.mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sai PIN')));
    return;
  }
  if (context.mounted)
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const AdminPage()));
}

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final token = TextEditingController(),
      pin1 = TextEditingController(),
      pin2 = TextEditingController();
  bool hasToken = false, busy = false;
  String status = '';
  @override
  void initState() {
    super.initState();
    DB
        .get('admin_gh_token')
        .then((t) => setState(() => hasToken = t.isNotEmpty));
  }

  void _msg(String s) {
    setState(() => status = s);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _push() async {
    final t = await DB.get('admin_gh_token');
    if (t.isEmpty) {
      _msg('Chưa có token');
      return;
    }
    setState(() => busy = true);
    try {
      _msg(await pushHubData(t));
    } catch (e) {
      _msg('Lỗi: $e');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text(hasToken
              ? 'Token GitHub: đã lưu trên máy này'
              : 'Token GitHub: chưa có'),
          TextField(
              controller: token,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Dán token GitHub (chỉ lưu trên máy này)')),
          Row(children: [
            FilledButton(
                onPressed: () async {
                  if (token.text.trim().isEmpty) return;
                  await DB.set('admin_gh_token', token.text.trim());
                  token.clear();
                  setState(() => hasToken = true);
                  _msg('Đã lưu token');
                },
                child: const Text('Lưu token')),
            const SizedBox(width: 8),
            if (hasToken)
              TextButton(
                  onPressed: () async {
                    await DB.set('admin_gh_token', '');
                    setState(() => hasToken = false);
                    _msg('Đã xoá token');
                  },
                  child: const Text('Xoá token')),
          ]),
          const Divider(height: 32),
          FilledButton.icon(
              onPressed: busy ? null : _push,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_upload),
              label: const Text('Đẩy dữ liệu Hub lên')),
          if (status.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 8), child: Text(status)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      final r = await uploadContacts(force: true);
                      if (mounted) {
                        setState(() => busy = false);
                        _msg(r);
                      }
                    },
              icon: const Icon(Icons.upload),
              label: const Text('Tải SĐT lên ngay')),
          const Divider(height: 32),
          const Text('Đổi PIN Admin',
              style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(
              controller: pin1,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'PIN mới')),
          TextField(
              controller: pin2,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nhập lại PIN mới')),
          const SizedBox(height: 8),
          FilledButton(
              onPressed: () async {
                if (pin1.text.length < 4 || pin1.text != pin2.text) {
                  _msg('PIN tối thiểu 4 số và phải khớp');
                  return;
                }
                await DB.set('admin_pin_hash', pinHash(pin1.text));
                pin1.clear();
                pin2.clear();
                _msg('Đã đổi PIN');
              },
              child: const Text('Đổi PIN')),
        ]),
      );
}
