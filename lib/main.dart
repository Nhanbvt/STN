import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'hubs.dart';
import 'phones.dart';
import 'about.dart';
import 'phone_seed.dart';
import 'updater.dart';
import 'db.dart';

const kRed = Color(0xFFD32F2F);
const kOrange = Color(0xFFFF7043);
final money = NumberFormat('#,###', 'vi_VN');
String vnd(num v) => '${money.format(v.round())} đ';
String ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String fmtNum(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DB.init();
  try { await DB.seedHubs(); } catch (_) {}
  try { await DB.syncPhones(phoneSeed); } catch (_) {}
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Sổ Thu Nhập',
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: kRed, primary: kRed), useMaterial3: true),
    home: const Home(),
  ));
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Trip> all = [];
  String q = '', name = '', driverId = '', vehicle = vehicles[0];

  @override
  void initState() { super.initState(); load(); WidgetsBinding.instance.addPostFrameCallback((_) => checkForUpdate(context, silent: true)); }

  Future<void> load() async {
    all = await DB.trips();
    name = await DB.get('name'); driverId = await DB.get('driver_id'); vehicle = await DB.get('vehicle', vehicles[0]);
    if (mounted) setState(() {});
  }

  List<Trip> get monthTrips => all.where((t) => t.date.startsWith(DateFormat('yyyy-MM').format(month))).toList();

  @override
  Widget build(BuildContext context) {
    final mt = monthTrips;
    final p = Payroll.of(mt);
    final shown = mt.where((t) => q.isEmpty || '${t.note} ${t.fromText} ${t.toText}'.toLowerCase().contains(q.toLowerCase())).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      floatingActionButton: FloatingActionButton(backgroundColor: kRed, foregroundColor: Colors.white, onPressed: () => editTrip(null), child: const Icon(Icons.add, size: 32)),
      body: Column(children: [
        Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [kRed, kOrange]), borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 8, 16),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('🚚 Sổ Thu Nhập', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white))),
                PopupMenuButton<String>(icon: const Icon(Icons.more_vert, color: Colors.white), onSelected: menu, itemBuilder: (_) => const [
                  PopupMenuItem(value: 'stats', child: Text('📊 Thống kê & Nhiên liệu')),
                  PopupMenuItem(value: 'fuel', child: Text('⛽ Cập nhật đổ xăng')),
                  PopupMenuItem(value: 'cal', child: Text('📅 Lịch vận hành')),
                  PopupMenuItem(value: 'hub', child: Text('📍 Vị trí Hub')),
                  PopupMenuItem(value: 'phone', child: Text('📞 Số ĐT Hub')),
                  PopupMenuItem(value: 'ghep', child: Text('⚙️ Cài đặt ghép chuyến')),
                  PopupMenuItem(value: 'bang', child: Text('💲 Bảng giá')),
                  PopupMenuItem(value: 'export', child: Text('📤 Xuất dữ liệu')),
                  PopupMenuItem(value: 'import', child: Text('📥 Nhập dữ liệu')),
                  PopupMenuItem(value: 'update', child: Text('🔄 Kiểm tra cập nhật')),
                  PopupMenuItem(value: 'about', child: Text('ℹ️ Thông tin App')),
                ]),
              ]),
              Row(children: [
                IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left, color: Colors.white)),
                Text('Tháng ${month.month}/${month.year}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right, color: Colors.white)),
              ]),
              GestureDetector(onTap: editProfile, child: Text('👤 ${name.isEmpty ? 'Tên tài xế' : name}   ·   ID: ${driverId.isEmpty ? '---' : driverId}', style: const TextStyle(color: Colors.white))),
              const SizedBox(height: 4),
              GestureDetector(onTap: chooseVehicle, child: Text('🚐 $vehicle ▾', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
              const SizedBox(height: 10),
              Wrap(spacing: 18, runSpacing: 6, children: [
                stat('Số chuyến', '${p.trips}'),
                stat('Ngày công', '${fmtNum(p.cong)}/$congChuan'),
                stat('Tiền chuyến', vnd(p.tripMoney)),
                stat('Tiền lương', vnd(p.luong)),
                if (p.congTangCa > 0) stat('Tăng ca (${fmtNum(p.congTangCa)} công x2)', vnd(p.tangCa)),
              ]),
              const SizedBox(height: 8),
              Center(child: Column(children: [
                const Text('TỔNG CỘNG', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70, letterSpacing: 1)),
                Text(vnd(p.tong), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.yellowAccent)),
              ])),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(onChanged: (v) => setState(() => q = v), decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Tìm mã trip, nơi đi, nơi đến...', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)))),
        ),
        Expanded(child: shown.isEmpty ? const Center(child: Text('Chưa có chuyến nào')) : ListView.builder(
          padding: const EdgeInsets.only(bottom: 90),
          itemCount: shown.length,
          itemBuilder: (_, i) {
            final t = shown[i];
            return Card(margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: InkWell(
              onTap: () => editTrip(t),
              onLongPress: () => deleteTrip(t),
              child: Padding(padding: const EdgeInsets.fromLTRB(10, 8, 0, 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: kOrange.withValues(alpha: .15), borderRadius: BorderRadius.circular(10)), child: Text(t.date.substring(5).split('-').reversed.join('/'), style: const TextStyle(color: kRed, fontWeight: FontWeight.bold, fontSize: 13))),
                    const SizedBox(width: 6),
                    Expanded(child: Text(t.note.isEmpty ? t.route : t.note, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), softWrap: true)),
                  ]),
                  const SizedBox(height: 4),
                  Text('${t.fromText} → ${t.toText}', softWrap: true, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Padding(padding: const EdgeInsets.only(left: 4, right: 2), child: Text(vnd(t.price), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13))),
                  IconButton(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 32), iconSize: 20, icon: const Icon(Icons.delete_outline), onPressed: () => deleteTrip(t)),
                ]),
              ])),
            ));
          },
        )),
      ]),
    );
  }

  Widget stat(String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
      ]);

  Future<void> editProfile() async {
    final n = TextEditingController(text: name), i = TextEditingController(text: driverId);
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Thông tin tài xế'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: n, decoration: const InputDecoration(labelText: 'Tên')),
      TextField(controller: i, decoration: const InputDecoration(labelText: 'ID')),
    ]), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('HUỶ')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('LƯU'))]));
    if (ok == true) { await DB.set('name', n.text); await DB.set('driver_id', i.text); load(); }
  }

  Future<void> chooseVehicle() async {
    final v = await showDialog<String>(context: context, builder: (c) => SimpleDialog(title: const Text('Chọn loại xe'), children: [
      for (final x in vehicles) SimpleDialogOption(onPressed: () => Navigator.pop(c, x), child: Text(x, style: TextStyle(fontWeight: x == vehicle ? FontWeight.bold : null))),
    ]));
    if (v != null) { await DB.set('vehicle', v); load(); }
  }

  Future<void> deleteTrip(Trip t) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Xoá chuyến?'), content: Text('${t.fromText} → ${t.toText}'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('HUỶ')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('XOÁ'))]));
    if (ok == true) { await DB.deleteTrip(t.id!); load(); }
  }

  Future<void> editTrip(Trip? t) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => TripDialog(trip: t, vehicle: vehicle));
    if (saved == true) load();
  }

  Future<void> menu(String v) async {
    switch (v) {
      case 'stats': await Navigator.push(context, MaterialPageRoute(builder: (_) => StatsPage(trips: monthTrips, month: month)));
      case 'fuel': await showDialog(context: context, builder: (_) => const FuelDialog());
      case 'cal': await Navigator.push(context, MaterialPageRoute(builder: (_) => CalendarPage(trips: all, month: month)));
      case 'about': await showAppInfo(context);
      case 'update': await checkForUpdate(context, silent: false);
      case 'phone': await Navigator.push(context, MaterialPageRoute(builder: (_) => const PhonePage()));
      case 'hub': await Navigator.push(context, MaterialPageRoute(builder: (_) => const HubPage()));
      case 'ghep': await showDialog(context: context, builder: (_) => const GhepDialog());
      case 'bang': await Navigator.push(context, MaterialPageRoute(builder: (_) => const PricePage()));
      case 'export':
        final f = File('${(await getTemporaryDirectory()).path}/so_thu_nhap_${ymd(DateTime.now())}.json');
        await f.writeAsString(const JsonEncoder.withIndent(' ').convert(await DB.exportAll()));
        await Share.shareXFiles([XFile(f.path)], text: 'Dữ liệu Sổ Thu Nhập');
      case 'import':
        final r = await FilePicker.pickFiles(type: FileType.any, withData: true);
        if (r == null) break;
        try {
          final bytes = r.files.single.bytes ?? await File(r.files.single.path!).readAsBytes();
          final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
          if (!mounted) break;
          final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Nhập dữ liệu'), content: Text('${DB.isOldFormat(data) ? 'File từ app cũ. ' : ''}${DB.isOldFormat(data) ? 'Chuyến mới sẽ được thêm vào, chuyến trùng mã trip sẽ bỏ qua.' : 'Toàn bộ dữ liệu hiện tại sẽ được thay bằng bản sao lưu.'} Tiếp tục?'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('HUỶ')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('NHẬP'))]));
          if (ok != true) break;
          if (DB.isOldFormat(data)) {
            final msg = await DB.importOld(data);
            if (!mounted) break;
            await showDialog(context: context, builder: (c) => AlertDialog(title: const Text('Kết quả nhập'), content: SingleChildScrollView(child: Text(msg + (DB.lastDupCodes.isEmpty ? '' : '\n\nMã trip đã có (không thêm):\n${DB.lastDupCodes.join('\n')}'))), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))]));
          } else { await DB.importAll(data); snack('Đã nhập dữ liệu'); }
        } catch (e) { snack('Lỗi nhập: $e'); }
    }
    load();
  }

  void snack(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
}

// ---------------- Thêm chuyến ----------------
class TripDialog extends StatefulWidget {
  final Trip? trip;
  final String vehicle;
  const TripDialog({super.key, this.trip, required this.vehicle});
  @override
  State<TripDialog> createState() => _TripDialogState();
}

class _TripDialogState extends State<TripDialog> {
  late TextEditingController date, note;
  late List<TextEditingController> from, to;
  late String route, vehicle;
  int? bandId;
  List<Band> bands = [];
  List<String> places = [];
  int gd = 30000, gn = 30000;

  @override
  void initState() {
    super.initState();
    final t = widget.trip;
    date = TextEditingController(text: t?.date ?? ymd(DateTime.now()));
    note = TextEditingController(text: t?.note ?? '');
    from = (t?.from ?? ['']).map((e) => TextEditingController(text: e)).toList();
    to = (t?.to ?? ['']).map((e) => TextEditingController(text: e)).toList();
    route = t?.route ?? routeTypes[0];
    vehicle = t?.vehicle ?? widget.vehicle;
    bandId = t?.bandId;
    () async { bands = await DB.bands(); places = await DB.places(); final g = await DB.ghep(); gd = g.$1; gn = g.$2; if (mounted) setState(() {}); }();
  }

  List<Band> get options => bands.where((b) => b.vehicle == vehicle && b.route == route).toList();
  int get price {
    final b = options.where((b) => b.id == bandId).firstOrNull;
    final ef = from.where((c) => c.text.trim().isNotEmpty).length - 1, et = to.where((c) => c.text.trim().isNotEmpty).length - 1;
    return (b?.price ?? 0) + (ef < 0 ? 0 : ef) * gd + (et < 0 ? 0 : et) * gn;
  }

  Widget placeField(TextEditingController c, String label, VoidCallback? onRemove) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Expanded(child: RawAutocomplete<String>(
            textEditingController: c,
            focusNode: FocusNode(),
            optionsBuilder: (v) => v.text.isEmpty ? const [] : places.where((p) => p.toLowerCase().contains(v.text.toLowerCase())),
            onSelected: (_) => setState(() {}),
            fieldViewBuilder: (ctx, ctl, fn, _) => TextField(controller: ctl, focusNode: fn, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder())),
            optionsViewBuilder: (ctx, onSel, opts) => Align(alignment: Alignment.topLeft, child: Material(elevation: 4, child: SizedBox(width: 250, height: 200, child: ListView(children: [for (final o in opts) ListTile(dense: true, title: Text(o), onTap: () => onSel(o))])))),
          )),
          if (onRemove != null) IconButton(icon: const Icon(Icons.remove_circle, color: kRed), onPressed: onRemove),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    if (!options.any((b) => b.id == bandId)) bandId = options.isEmpty ? null : options.first.id;
    return AlertDialog(
      title: Text(widget.trip == null ? 'Thêm Chuyến' : 'Sửa Chuyến', style: const TextStyle(color: kRed, fontWeight: FontWeight.bold)),
      content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: date, readOnly: true, decoration: const InputDecoration(labelText: 'Ngày (YYYY-MM-DD)'), onTap: () async {
          final d = await showDatePicker(context: context, initialDate: DateTime.tryParse(date.text) ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
          if (d != null) setState(() => date.text = ymd(d));
        }),
        const SizedBox(height: 8),
        DropdownButtonFormField(value: route, decoration: const InputDecoration(labelText: 'Loại hành trình'), items: [for (final r in routeTypes) DropdownMenuItem(value: r, child: Text(r))], onChanged: (v) => setState(() => route = v!)),
        const SizedBox(height: 12),
        for (var i = 0; i < from.length; i++) placeField(from[i], i == 0 ? 'Nơi đi (điểm chính)' : 'Điểm đi ghép $i', i == 0 ? null : () => setState(() => from.removeAt(i))),
        TextButton(onPressed: () => setState(() => from.add(TextEditingController())), child: const Text('+ GHÉP THÊM ĐIỂM ĐI')),
        for (var i = 0; i < to.length; i++) placeField(to[i], i == 0 ? 'Nơi đến (điểm chính)' : 'Điểm đến ghép $i', i == 0 ? null : () => setState(() => to.removeAt(i))),
        TextButton(onPressed: () => setState(() => to.add(TextEditingController())), child: const Text('+ GHÉP THÊM ĐIỂM ĐẾN')),
        DropdownButtonFormField<int>(value: bandId, isExpanded: true, decoration: const InputDecoration(labelText: 'Khoảng cách'), items: [for (final b in options) DropdownMenuItem(value: b.id, child: Text('${b.label}: ${vnd(b.price)}${b.placeholder ? ' (tạm)' : ''}'))], onChanged: (v) => setState(() => bandId = v)),
        const SizedBox(height: 10),
        Text('Giá tính toán: ${vnd(price)}', style: const TextStyle(fontSize: 18, color: Colors.blue, fontWeight: FontWeight.bold)),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Ghi chú / Mã trip')),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('HUỶ')),
        FilledButton(onPressed: () async {
          if (from.first.text.trim().isEmpty || to.first.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nhập nơi đi và nơi đến')));
            return;
          }
          if (await DB.codeExists(note.text, exceptId: widget.trip?.id)) {
            if (!context.mounted) return;
            await showDialog(context: context, builder: (c) => AlertDialog(title: const Text('Trùng mã trip'), content: Text('Mã trip "${note.text.trim()}" đã có trong sổ. Chuyến này sẽ không được lưu thêm.'), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))]));
            return;
          }
          await DB.saveTrip(Trip(id: widget.trip?.id, date: date.text, route: route, vehicle: vehicle, from: from.map((c) => c.text.trim()).where((e) => e.isNotEmpty).toList(), to: to.map((c) => c.text.trim()).where((e) => e.isNotEmpty).toList(), bandId: bandId, note: note.text.trim()));
          if (context.mounted) Navigator.pop(context, true);
        }, child: const Text('LƯU')),
      ],
    );
  }
}

// ---------------- Ghép ----------------
class GhepDialog extends StatefulWidget {
  const GhepDialog({super.key});
  @override
  State<GhepDialog> createState() => _GhepDialogState();
}

class _GhepDialogState extends State<GhepDialog> {
  final di = TextEditingController(), den = TextEditingController();
  @override
  void initState() { super.initState(); DB.ghep().then((g) => setState(() { di.text = '${g.$1}'; den.text = '${g.$2}'; })); }
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Cài đặt giá ghép điểm'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: di, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá ghép điểm đi (đ)')),
          TextField(controller: den, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá ghép điểm đến (đ)')),
          const SizedBox(height: 8),
          const Text('Lưu xong sẽ tự tính lại tất cả chuyến đã lưu.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('HUỶ')),
          FilledButton(onPressed: () async {
            await DB.set('gia_ghep_di', '${int.tryParse(di.text) ?? 30000}');
            await DB.set('gia_ghep_den', '${int.tryParse(den.text) ?? 30000}');
            await DB.recomputeAll();
            if (context.mounted) Navigator.pop(context);
          }, child: const Text('LƯU')),
        ],
      );
}

// ---------------- Xăng ----------------
/// Kỳ xăng 26 tháng này → 25 tháng sau, chứa ngày d.
(DateTime, DateTime) fuelPeriod(DateTime d) {
  final start = d.day >= 26 ? DateTime(d.year, d.month, 26) : DateTime(d.year, d.month - 1, 26);
  return (start, DateTime(start.year, start.month + 1, 25));
}

class FuelDialog extends StatefulWidget {
  const FuelDialog({super.key});
  @override
  State<FuelDialog> createState() => _FuelDialogState();
}

class _FuelDialogState extends State<FuelDialog> {
  final date = TextEditingController(text: ymd(DateTime.now())), lit = TextEditingController(), km = TextEditingController();
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Cập nhật đổ xăng'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: date, readOnly: true, decoration: const InputDecoration(labelText: 'Ngày'), onTap: () async {
            final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (d != null) setState(() => date.text = ymd(d));
          }),
          TextField(controller: lit, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Số lít')),
          TextField(controller: km, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Số km đã chạy')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('HUỶ')),
          FilledButton(onPressed: () async {
            final l = double.tryParse(lit.text.replaceAll(',', '.')), k = double.tryParse(km.text.replaceAll(',', '.'));
            if (l == null || k == null) return;
            await DB.saveFuel(Fuel(date: date.text, liters: l, km: k));
            if (context.mounted) Navigator.pop(context);
          }, child: const Text('LƯU')),
        ],
      );
}

// ---------------- Thống kê ----------------
class StatsPage extends StatefulWidget {
  final List<Trip> trips;
  final DateTime month;
  const StatsPage({super.key, required this.trips, required this.month});
  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  List<Fuel> fuels = [];
  late DateTime periodStart = fuelPeriod(DateTime.now()).$1;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async { fuels = await DB.fuels(); setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final p = Payroll.of(widget.trips);
    final (s, e) = fuelPeriod(periodStart);
    final inP = fuels.where((f) { final d = DateTime.parse(f.date); return !d.isBefore(s) && !d.isAfter(e); }).toList();
    final tl = inP.fold<double>(0, (a, f) => a + f.liters), tk = inP.fold<double>(0, (a, f) => a + f.km);
    final delta = tk * dinhMuc / 100 - tl;
    final df = DateFormat('dd/MM/yyyy');
    row(String k, String v, [Color? c]) => ListTile(dense: true, title: Text(k), trailing: Text(v, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: c)));
    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê & Nhiên liệu'), backgroundColor: kRed, foregroundColor: Colors.white),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(child: Column(children: [
          ListTile(title: Text('Tháng ${widget.month.month}/${widget.month.year}', style: const TextStyle(fontWeight: FontWeight.bold, color: kRed))),
          row('Số ngày chạy', '${p.days}'),
          row('Tổng chuyến', '${p.trips}'),
          row('Ngày công', '${fmtNum(p.cong)}/$congChuan'),
          row('Tiền chuyến', vnd(p.tripMoney), Colors.blue),
          row('Tiền công (${fmtNum(p.congThuong)} công)', vnd(p.luong)),
          if (p.congTangCa > 0) row('Tăng ca (${fmtNum(p.congTangCa)} công x2)', vnd(p.tangCa), Colors.deepOrange),
          row('TỔNG', vnd(p.tong), kRed),
        ])),
        Card(child: Column(children: [
          ListTile(
            leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => periodStart = DateTime(s.year, s.month - 1, 26))),
            title: Text('⛽ Kỳ 26-25: ${df.format(s)} → ${df.format(e)}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => periodStart = DateTime(s.year, s.month + 1, 26))),
          ),
          row('Tổng lít đổ', '${fmtNum(tl)} L'),
          row('Tổng km chạy', '${fmtNum(tk)} KM'),
          row('Định mức ($dinhMuc L/100km)', '${(tk * dinhMuc / 100).toStringAsFixed(2)} L'),
          row(delta >= 0 ? 'Dư' : 'Thiếu', '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)} L', delta >= 0 ? Colors.green : kRed),
          const Divider(),
          for (final f in inP) ListTile(
            dense: true,
            title: Text('${f.date}:  Đổ ${fmtNum(f.liters)} L | Chạy ${fmtNum(f.km)} KM'),
            subtitle: Text('${f.delta >= 0 ? '+' : ''}${f.delta.toStringAsFixed(2)} L', style: TextStyle(color: f.delta >= 0 ? Colors.green : kRed, fontWeight: FontWeight.bold)),
            trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { await DB.deleteFuel(f.id!); load(); }),
          ),
          TextButton.icon(onPressed: () async { await showDialog(context: context, builder: (_) => const FuelDialog()); load(); }, icon: const Icon(Icons.add), label: const Text('Cập nhật đổ xăng')),
        ])),
      ]),
    );
  }
}

// ---------------- Lịch ----------------
class CalendarPage extends StatefulWidget {
  final List<Trip> trips;
  final DateTime month;
  const CalendarPage({super.key, required this.trips, required this.month});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime m = widget.month;
  @override
  Widget build(BuildContext context) {
    final count = <String, int>{};
    for (final t in widget.trips) { count[t.date] = (count[t.date] ?? 0) + 1; }
    final first = DateTime(m.year, m.month, 1), days = DateTime(m.year, m.month + 1, 0).day, lead = first.weekday - 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch vận hành'), backgroundColor: kRed, foregroundColor: Colors.white),
      body: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(onPressed: () => setState(() => m = DateTime(m.year, m.month - 1)), icon: const Icon(Icons.chevron_left)),
          Text('Tháng ${m.month}/${m.year}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(onPressed: () => setState(() => m = DateTime(m.year, m.month + 1)), icon: const Icon(Icons.chevron_right)),
        ]),
        Row(children: [for (final d in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']) Expanded(child: Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold))))]),
        Expanded(child: GridView.count(crossAxisCount: 7, padding: const EdgeInsets.all(4), children: [
          for (var i = 0; i < lead; i++) const SizedBox(),
          for (var d = 1; d <= days; d++) () {
            final n = count[ymd(DateTime(m.year, m.month, d))] ?? 0;
            return Container(margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: n >= 2 ? Colors.green : n == 1 ? Colors.orange : Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('$d', style: TextStyle(fontWeight: FontWeight.bold, color: n > 0 ? Colors.white : Colors.black)),
                  if (n > 0) Text('$n cuốc', style: const TextStyle(fontSize: 10, color: Colors.white)),
                ]));
          }(),
        ])),
        const Padding(padding: EdgeInsets.all(12), child: Text('🟧 1 cuốc = 0.5 công    🟩 ≥2 cuốc = 1 công')),
      ]),
    );
  }
}

// ---------------- Bảng giá ----------------
class PricePage extends StatefulWidget {
  const PricePage({super.key});
  @override
  State<PricePage> createState() => _PricePageState();
}

class _PricePageState extends State<PricePage> {
  List<Band> bands = [];
  String vehicle = vehicles[0];
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async { bands = await DB.bands(); setState(() {}); }

  Future<void> edit(Band? b, String route) async {
    final l = TextEditingController(text: b?.label ?? ''), pr = TextEditingController(text: b == null ? '' : '${b.basePrice}');
    final r = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: Text('${b == null ? 'Thêm' : 'Sửa'} mức giá – $route'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: l, decoration: const InputDecoration(labelText: 'Khoảng cách (vd: 0-15 KM)')),
        TextField(controller: pr, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Giá gốc (đ)', helperText: route == 'Nội Thành' ? 'Nội Thành tự nhân x$noiThanhMultiplier' : null)),
      ]),
      actions: [
        if (b != null) TextButton(onPressed: () => Navigator.pop(c, 'del'), child: const Text('XOÁ', style: TextStyle(color: kRed))),
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('HUỶ')),
        FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: const Text('LƯU')),
      ],
    ));
    if (r == 'del') await DB.deleteBand(b!.id!);
    if (r == 'save' && int.tryParse(pr.text) != null) {
      await DB.saveBand(Band(id: b?.id, vehicle: vehicle, route: route, label: l.text.trim(), basePrice: int.parse(pr.text)));
    }
    load();
  }

  Future<void> importFile() async {
    final res = await FilePicker.pickFiles(type: FileType.any, withData: true);
    if (res == null) return;
    final bytes = res.files.single.bytes ?? await File(res.files.single.path!).readAsBytes();
    final text = utf8.decode(bytes).trim();
    List<Map<String, dynamic>> rows;
    if (text.startsWith('[') || text.startsWith('{')) {
      final j = jsonDecode(text);
      rows = List<Map<String, dynamic>>.from((j is Map ? j['bands'] : j) as List);
    } else {
      final lines = const LineSplitter().convert(text).where((e) => e.trim().isNotEmpty).toList();
      final sep = lines.first.contains(';') ? ';' : ',';
      rows = [
        for (final ln in lines.skip(lines.first.toLowerCase().contains('vehicle') ? 1 : 0))
          if (ln.split(sep).length >= 4) {'vehicle': ln.split(sep)[0], 'route': ln.split(sep)[1], 'label': ln.split(sep)[2], 'base_price': ln.split(sep).sublist(3).join()}
      ];
    }
    if (!mounted) return;
    final replace = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text('Nhập ${rows.length} mức giá'), content: const Text('Thay thế toàn bộ bảng giá cũ hay thêm vào?'), actions: [
      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('THÊM VÀO')),
      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('THAY THẾ')),
    ]));
    if (replace == null) return;
    final n = await DB.importBands(rows, replace: replace);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã nhập $n mức giá, đã tính lại các chuyến')));
    load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Bảng giá'), backgroundColor: kRed, foregroundColor: Colors.white, actions: [
          IconButton(tooltip: 'Nhập CSV/JSON', icon: const Icon(Icons.file_upload), onPressed: importFile),
        ]),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          DropdownButtonFormField(value: vehicle, decoration: const InputDecoration(labelText: 'Loại xe'), items: [for (final v in vehicles) DropdownMenuItem(value: v, child: Text(v))], onChanged: (v) => setState(() => vehicle = v!)),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Nhập giá gốc. Nội Thành tự nhân x1.28. Sửa giá sẽ tự tính lại tất cả chuyến.\nCSV: vehicle,route,label,base_price', style: TextStyle(fontSize: 12, color: Colors.grey))),
          for (final r in routeTypes) Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ListTile(title: Text(r, style: const TextStyle(fontWeight: FontWeight.bold, color: kRed)), trailing: IconButton(icon: const Icon(Icons.add), onPressed: () => edit(null, r))),
            for (final b in bands.where((b) => b.vehicle == vehicle && b.route == r)) ListTile(
              dense: true, onTap: () => edit(b, r),
              title: Text(b.label + (b.placeholder ? '  (tạm)' : ''), style: TextStyle(color: b.placeholder ? Colors.orange : null)),
              subtitle: r == 'Nội Thành' ? Text('Gốc ${vnd(b.basePrice)} x1.28') : null,
              trailing: Text(vnd(b.price), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
          ])),
        ]),
      );
}
