import 'hub_sync.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'db.dart';
import 'exchange.dart';

const hubFields = ['name', 'lat', 'lng', 'note'];

const _red = Color(0xFFD32F2F);

/// Lấy toạ độ từ link Google Maps / Zalo / chuỗi "lat,lng".
(double, double)? parseLatLng(String s) {
  final pats = [
    RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)'),
    RegExp(r'@(-?\d+\.\d+),\s*(-?\d+\.\d+)'),
    RegExp(r'(?:q|query|destination|ll|center|daddr)=(-?\d+\.\d+)(?:,|%2C)\s*(-?\d+\.\d+)'),
    RegExp(r'(-?\d{1,2}\.\d{3,})\s*,\s*(-?\d{1,3}\.\d{3,})'),
  ];
  for (final p in pats) {
    final m = p.firstMatch(s);
    if (m != null) {
      final la = double.parse(m.group(1)!), ln = double.parse(m.group(2)!);
      if (la.abs() <= 90 && ln.abs() <= 180) return (la, ln);
    }
  }
  return null;
}

/// Link rút gọn (maps.app.goo.gl, goo.gl) → lần theo redirect để lấy toạ độ.
Future<(double, double)?> resolveLatLng(String s) async {
  final direct = parseLatLng(s);
  if (direct != null) return direct;
  final url = RegExp(r'https?://\S+').firstMatch(s)?.group(0);
  if (url == null) return null;
  final c = HttpClient();
  try {
    var u = Uri.parse(url);
    for (var i = 0; i < 6; i++) {
      final req = await c.getUrl(u)..followRedirects = false;
      final res = await req.close();
      final loc = res.headers.value('location');
      if (loc == null) {
        final body = await res.transform(const SystemEncoding().decoder).join();
        return parseLatLng(body);
      }
      await res.drain();
      final r = parseLatLng(Uri.decodeFull(loc));
      if (r != null) return r;
      u = u.resolve(loc);
    }
  } catch (_) {} finally { c.close(); }
  return null;
}

/// Lấy vị trí GPS thực tế hiện tại (độ chính xác cao).
Future<Position> currentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) throw 'Hãy bật GPS / Dịch vụ định vị';
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
  if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) throw 'Chưa cấp quyền vị trí cho app';
  return Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 30)));
}

String mapsLink(num lat, num lng) => 'https://maps.google.com/?q=$lat,$lng';

Future<void> navigateTo(double lat, double lng) async {
  final nav = Uri.parse('google.navigation:q=$lat,$lng');
  if (Platform.isAndroid && await canLaunchUrl(nav)) { await launchUrl(nav); return; }
  final gm = Uri.parse('comgooglemaps://?daddr=$lat,$lng&directionsmode=driving');
  if (Platform.isIOS && await canLaunchUrl(gm)) { await launchUrl(gm); return; }
  await launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving'), mode: LaunchMode.externalApplication);
}

class HubPage extends StatefulWidget {
  const HubPage({super.key});
  @override
  State<HubPage> createState() => _HubPageState();
}

class _HubPageState extends State<HubPage> {
  List<Map<String, Object?>> hubs = [];
  String q = '';
  @override
  void initState() { super.initState(); load(); syncHubData().then((ch) { if (ch) load(); }); }
  Future<void> load() async { hubs = await DB.hubs(); if (mounted) setState(() {}); }

  Future<void> edit([Map<String, Object?>? h]) async {
    final r = await showDialog<bool>(context: context, builder: (_) => HubDialog(hub: h));
    if (r == true) load();
  }

  @override
  Widget build(BuildContext context) {
    final shown = hubs.where((h) => q.isEmpty || '${h['name']} ${h['note']}'.toLowerCase().contains(q.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Vị trí Hub'), backgroundColor: _red, foregroundColor: Colors.white, actions: [
        PopupMenuButton<String>(onSelected: (v) async {
          if (v == 'exp') await exportItems(context, 'hubs', 'Vị trí Hub', hubs, hubFields);
          if (v == 'imp' && await importItems(context, 'hubs', 'Vị trí Hub', hubFields, DB.hubs, DB.saveHub)) load();
        }, itemBuilder: (_) => const [PopupMenuItem(value: 'exp', child: Text('📤 Xuất file')), PopupMenuItem(value: 'imp', child: Text('📥 Nhập & đối chiếu file'))]),
      ]),
      floatingActionButton: FloatingActionButton(backgroundColor: _red, foregroundColor: Colors.white, onPressed: () => edit(), child: const Icon(Icons.add_location_alt)),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(onChanged: (v) => setState(() => q = v), decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Tìm hub...', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30))))),
        Expanded(child: shown.isEmpty ? const Center(child: Text('Chưa có hub. Bấm + để thêm.')) : ListView(children: [
          for (final h in shown) Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(
            leading: const Icon(Icons.place, color: _red),
            title: Text('${h['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(h['lat'] == null ? 'Chưa có định vị' : '${(h['lat'] as num).toStringAsFixed(6)}, ${(h['lng'] as num).toStringAsFixed(6)}${'${h['note'] ?? ''}'.isEmpty ? '' : '\n${h['note']}'}'),
            onTap: h['lat'] == null ? () => edit(h) : () => navigateTo((h['lat'] as num).toDouble(), (h['lng'] as num).toDouble()),
            trailing: PopupMenuButton<String>(onSelected: (v) async {
              if (v == 'edit') edit(h);
              if (v == 'share') {
                final link = h['lat'] == null ? RegExp(r'https?://\S+').firstMatch('${h['note'] ?? ''}')?.group(0) : mapsLink(h['lat'] as num, h['lng'] as num);
                if (link == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hub chưa có định vị để chia sẻ'))); return; }
                await Share.share('📍 ${h['name']}\n$link', subject: '${h['name']}');
              }
              if (v == 'pin') {
                final m = ScaffoldMessenger.of(context);
                m.showSnackBar(const SnackBar(content: Text('Đang lấy vị trí GPS...')));
                try {
                  if (await DB.locEditsLeft(h['name']) <= 0) { m.showSnackBar(const SnackBar(content: Text(kLocLimitMsg))); return; }
                  final p = await currentPosition();
                  if (!await DB.useLocEdit(h['name'])) { m.showSnackBar(const SnackBar(content: Text(kLocLimitMsg))); return; }
                  await DB.saveHub({...h, 'lat': p.latitude, 'lng': p.longitude});
                  m.showSnackBar(SnackBar(content: Text('Đã ghim vị trí thực tế (±${p.accuracy.toStringAsFixed(0)} m)')));
                  load();
                } catch (e) { m.showSnackBar(SnackBar(content: Text('$e'))); }
              }
            }, itemBuilder: (_) => const [PopupMenuItem(value: 'share', child: Text('📤 Chia sẻ (Zalo...)')), PopupMenuItem(value: 'pin', child: Text('📍 Ghim vị trí hiện tại')), PopupMenuItem(value: 'edit', child: Text('Sửa'))]),
          )),
        ])),
      ]),
    );
  }
}

class HubDialog extends StatefulWidget {
  final Map<String, Object?>? hub;
  const HubDialog({super.key, this.hub});
  @override
  State<HubDialog> createState() => _HubDialogState();
}

class _HubDialogState extends State<HubDialog> {
  late final name = TextEditingController(text: '${widget.hub?['name'] ?? ''}');
  late final note = TextEditingController(text: '${widget.hub?['note'] ?? ''}');
  final link = TextEditingController();
  late double? lat = (widget.hub?['lat'] as num?)?.toDouble(), lng = (widget.hub?['lng'] as num?)?.toDouble();
  List<String> places = [];
  bool busy = false;
  String? msg;

  @override
  void initState() { super.initState(); DB.places().then((p) => setState(() => places = p)); }

  Future<void> gps() async {
    setState(() { busy = true; msg = null; });
    try {
      final p = await currentPosition();
      setState(() { lat = p.latitude; lng = p.longitude; msg = 'Độ chính xác ±${p.accuracy.toStringAsFixed(0)} m'; });
    } catch (e) { setState(() => msg = '$e'); }
    setState(() => busy = false);
  }

  Future<void> fromLink() async {
    setState(() { busy = true; msg = null; });
    final r = await resolveLatLng(link.text);
    setState(() { busy = false; if (r == null) { msg = 'Không đọc được toạ độ từ link'; } else { lat = r.$1; lng = r.$2; msg = 'Đã lấy toạ độ từ link'; } });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.hub == null ? 'Thêm Hub' : 'Sửa Hub'),
        content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Autocomplete<String>(
            initialValue: name.value,
            optionsBuilder: (v) => places.where((p) => v.text.isEmpty || p.toLowerCase().contains(v.text.toLowerCase())),
            onSelected: (v) => name.text = v,
            fieldViewBuilder: (c, ctl, fn, _) { ctl.addListener(() => name.text = ctl.text); return TextField(controller: ctl, focusNode: fn, decoration: const InputDecoration(labelText: 'Tên hub (chọn từ địa điểm đã lưu)')); },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: busy ? null : gps, icon: const Icon(Icons.my_location), label: const Text('Ghim vị trí hiện tại (GPS)')),
          const SizedBox(height: 8),
          TextField(controller: link, decoration: InputDecoration(labelText: 'Dán link Google Maps / Zalo hoặc "lat, lng"', suffixIcon: IconButton(icon: const Icon(Icons.download), onPressed: busy ? null : fromLink))),
          TextButton.icon(onPressed: () => launchUrl(Uri.parse(lat == null ? 'https://www.google.com/maps' : 'https://www.google.com/maps/search/?api=1&query=$lat,$lng'), mode: LaunchMode.externalApplication), icon: const Icon(Icons.map), label: const Text('Mở bản đồ để chọn điểm, rồi Chia sẻ → Sao chép link → dán vào ô trên')),
          if (busy) const LinearProgressIndicator(),
          if (msg != null) Text(msg!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(lat == null ? '📍 Chưa có toạ độ' : '📍 ${lat!.toStringAsFixed(6)}, ${lng!.toStringAsFixed(6)}', style: const TextStyle(fontWeight: FontWeight.bold, color: _red)),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Ghi chú (cổng, giờ nhận hàng...)')),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('HUỶ')),
          FilledButton(onPressed: () async {
            if (name.text.trim().isEmpty) return;
            final oLat = (widget.hub?['lat'] as num?)?.toDouble(), oLng = (widget.hub?['lng'] as num?)?.toDouble();
            if (lat != oLat || lng != oLng) {
              if (!await DB.useLocEdit(widget.hub?['name'] ?? name.text.trim())) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(kLocLimitMsg)));
                return;
              }
            }
            await DB.saveHub({'id': widget.hub?['id'], 'name': name.text.trim(), 'lat': lat, 'lng': lng, 'note': note.text.trim()});
            if (context.mounted) Navigator.pop(context, true);
          }, child: const Text('LƯU')),
        ],
      );
}
