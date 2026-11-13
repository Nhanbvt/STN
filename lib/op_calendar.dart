import 'package:flutter/material.dart';
import 'db.dart';
import 'holidays.dart';

const _kRed = Color(0xFFD32F2F);
const kHolidayColor = Color(0xFF8E24AA);
String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

Widget _legend(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 4),
      Text(t, style: const TextStyle(fontSize: 12)),
    ]);

// ---------------- Lịch vận hành ----------------
/// Ô tím = ngày lễ (mặc định 1 công; đi làm = 3 công). Chạm 1 ngày để bật/tắt ngày lễ (lưu trong máy).
class CalendarPage extends StatefulWidget {
  final List<Trip> trips;
  final DateTime month;
  final Map<String, String> hubRegion;
  /// Chỉ dùng cho test: ghi đè ngày lễ ban đầu & không đọc/ghi DB.
  final Map<String, bool>? testOverrides;
  const CalendarPage({super.key, required this.trips, required this.month, this.hubRegion = const {}, this.testOverrides});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime m = widget.month;
  Map<String, bool> ov = {};

  @override
  void initState() {
    super.initState();
    if (widget.testOverrides != null) {
      ov = Map.of(widget.testOverrides!);
    } else {
      DB.holidayOverrides().then((v) { if (mounted) setState(() => ov = v); });
    }
  }

  bool _nv(Trip t) => tripIsNoiVung(t, widget.hubRegion);

  Future<void> toggle(String date) async {
    final before = ov[date];
    final v = toggledOverride(date, ov);
    setState(() { if (v == null) { ov.remove(date); } else { ov[date] = v; } });
    if (widget.testOverrides == null) await DB.setHolidayOverride(date, v);
    if (!mounted) return;
    final d = date.substring(5).split('-').reversed.join('/');
    final on = isHoliday(date, ov);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(on ? 'Đã đặt $d là ngày lễ (mặc định 1 công, đi làm = 3 công)' : 'Đã bỏ ngày lễ $d'),
        action: SnackBarAction(label: 'HOÀN TÁC', onPressed: () async {
          setState(() { if (before == null) { ov.remove(date); } else { ov[date] = before; } });
          if (widget.testOverrides == null) await DB.setHolidayOverride(date, before);
        }),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final byDay = <String, List<Trip>>{};
    for (final t in widget.trips) { (byDay[normDate(t.date)] ??= []).add(t); }
    final first = DateTime(m.year, m.month, 1), days = DateTime(m.year, m.month + 1, 0).day, lead = first.weekday - 1;
    final hol = holidaysInMonth(m, ov);
    final std = congChuanThang(m);
    final mk = '${m.year}-${m.month.toString().padLeft(2, '0')}';
    final p = Payroll.of(widget.trips.where((t) => normDate(t.date).startsWith(mk)).toList(), month: m, holidays: hol, isNoiVung: _nv);
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch vận hành'), backgroundColor: _kRed, foregroundColor: Colors.white),
      body: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(onPressed: () => setState(() => m = DateTime(m.year, m.month - 1)), icon: const Icon(Icons.chevron_left)),
          Text('Tháng ${m.month}/${m.year}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(onPressed: () => setState(() => m = DateTime(m.year, m.month + 1)), icon: const Icon(Icons.chevron_right)),
        ]),
        Text('Công chuẩn: $std  ·  Ngày lễ: ${hol.length}  ·  Đã có: ${_fmt(p.cong)} công', style: const TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 6),
        Row(children: [for (final d in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']) Expanded(child: Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold))))]),
        Expanded(child: GridView.count(crossAxisCount: 7, padding: const EdgeInsets.all(4), children: [
          for (var i = 0; i < lead; i++) const SizedBox(),
          for (var d = 1; d <= days; d++) () {
            final key = _ymd(DateTime(m.year, m.month, d));
            final ts = byDay[key] ?? const <Trip>[];
            final h = hol.contains(key);
            final c = Payroll.congOfDay(ts, holiday: h, isNoiVung: _nv);
            final n = ts.length;
            final color = h ? kHolidayColor : c >= 1 ? Colors.green : n > 0 ? Colors.orange : Colors.grey.shade200;
            final light = h || n > 0;
            return GestureDetector(
              key: ValueKey('cal-$key'),
              onTap: () => toggle(key),
              child: Container(
                alignment: Alignment.center,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8), border: h && n > 0 ? Border.all(color: Colors.amber, width: 2.5) : null),
                padding: const EdgeInsets.all(2),
                child: FittedBox(fit: BoxFit.scaleDown, child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$d', style: TextStyle(fontWeight: FontWeight.bold, color: light ? Colors.white : Colors.black)),
                  if (h) Text(n > 0 ? 'Lễ · ${_fmt(c)} công' : 'Lễ', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600))
                  else if (n > 0) Text('$n cuốc', style: const TextStyle(fontSize: 10, color: Colors.white)),
                ])),
              ),
            );
          }(),
        ])),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 4, children: [
            _legend(Colors.orange, '1 cuốc Nội thành = 0.5 công'),
            _legend(Colors.green, '≥2 cuốc hoặc Nội vùng = 1 công'),
            _legend(kHolidayColor, 'Ngày lễ: nghỉ = 1 công, đi làm = 3 công'),
            const Text('Chạm vào ngày để bật/tắt ngày lễ', style: TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic)),
          ]),
        ),
      ]),
    );
  }
}
