import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

const vehicles = ['Xe Van < 1 Tấn', 'Xe Tải 2 Tấn', 'Xe Tải 5 Tấn', 'Xe Tải 8 Tấn'];
const routeTypes = ['Nội Thành', 'Nội Vùng', 'Liên Vùng'];
const noiThanhMultiplier = 1.28;
const luongThang = 5310000;
const congChuan = 26;
const dinhMuc = 12.5; // L/100km

class Band {
  int? id;
  String vehicle, route, label;
  int basePrice;
  bool placeholder;
  Band({this.id, required this.vehicle, required this.route, required this.label, required this.basePrice, this.placeholder = false});
  int get price => route == 'Nội Thành' ? (basePrice * noiThanhMultiplier).round() : basePrice;
  Map<String, Object?> toMap() => {'id': id, 'vehicle': vehicle, 'route': route, 'label': label, 'base_price': basePrice, 'placeholder': placeholder ? 1 : 0};
  static Band from(Map m) => Band(id: m['id'] as int?, vehicle: '${m['vehicle']}', route: '${m['route']}', label: '${m['label']}', basePrice: (m['base_price'] as num).toInt(), placeholder: (m['placeholder'] ?? 0) == 1);
}

class Trip {
  int? id;
  String date, route, note, vehicle;
  List<String> from, to;
  int? bandId;
  int price;
  Trip({this.id, required this.date, required this.route, required this.from, required this.to, this.bandId, this.price = 0, this.note = '', required this.vehicle});
  String get fromText => from.where((e) => e.trim().isNotEmpty).join(' + ');
  String get toText => to.where((e) => e.trim().isNotEmpty).join(' + ');
  Map<String, Object?> toMap() => {'id': id, 'date': date, 'route': route, 'from_pts': from.join('\n'), 'to_pts': to.join('\n'), 'band_id': bandId, 'price': price, 'note': note, 'vehicle': vehicle};
  static Trip from_(Map m) => Trip(id: m['id'] as int?, date: '${m['date']}', route: '${m['route']}', from: '${m['from_pts']}'.split('\n'), to: '${m['to_pts']}'.split('\n'), bandId: m['band_id'] as int?, price: (m['price'] as num? ?? 0).toInt(), note: '${m['note'] ?? ''}', vehicle: '${m['vehicle'] ?? vehicles[0]}');
}

class Fuel {
  int? id;
  String date;
  double liters, km;
  Fuel({this.id, required this.date, required this.liters, required this.km});
  double get allowed => km * dinhMuc / 100;
  double get delta => allowed - liters;
  Map<String, Object?> toMap() => {'id': id, 'date': date, 'liters': liters, 'km': km};
  static Fuel from(Map m) => Fuel(id: m['id'] as int?, date: '${m['date']}', liters: (m['liters'] as num).toDouble(), km: (m['km'] as num).toDouble());
}

class DB {
  static late Database db;
  static Future<void> init() async {
    db = await openDatabase(p.join(await getDatabasesPath(), 'so_thu_nhap.db'), version: 1, onCreate: (d, v) async {
      await d.execute('CREATE TABLE trips(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT, route TEXT, from_pts TEXT, to_pts TEXT, band_id INTEGER, price INTEGER, note TEXT, vehicle TEXT)');
      await d.execute('CREATE TABLE bands(id INTEGER PRIMARY KEY AUTOINCREMENT, vehicle TEXT, route TEXT, label TEXT, base_price INTEGER, placeholder INTEGER)');
      await d.execute('CREATE TABLE fuel(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT, liters REAL, km REAL)');
      await d.execute('CREATE TABLE places(name TEXT PRIMARY KEY, uses INTEGER)');
      await d.execute('CREATE TABLE settings(k TEXT PRIMARY KEY, v TEXT)');
      // Seed: chỉ 0-15KM Xe Van là giá thật; còn lại là giá TẠM, cần sửa.
      final seeds = <Band>[];
      for (final v in vehicles) {
        for (final r in routeTypes) {
          final real = v == vehicles[0];
          seeds.add(Band(vehicle: v, route: r, label: '0-15 KM', basePrice: 56000, placeholder: !real));
          seeds.add(Band(vehicle: v, route: r, label: '15-30 KM (TẠM - sửa)', basePrice: 0, placeholder: true));
        }
      }
      for (final b in seeds) { await d.insert('bands', b.toMap()..remove('id')); }
      for (final e in {'gia_ghep_di': '30000', 'gia_ghep_den': '30000', 'name': 'Bùi Văn Trung Nhân', 'driver_id': '', 'vehicle': vehicles[0]}.entries) {
        await d.insert('settings', {'k': e.key, 'v': e.value});
      }
    });
  }

  static Future<String> get(String k, [String def = '']) async {
    final r = await db.query('settings', where: 'k=?', whereArgs: [k]);
    return r.isEmpty ? def : '${r.first['v']}';
  }
  static Future<void> set(String k, String v) => db.insert('settings', {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<List<Band>> bands() async => (await db.query('bands', orderBy: 'vehicle, route, id')).map(Band.from).toList();
  static Future<void> saveBand(Band b) async {
    if (b.id == null) { await db.insert('bands', b.toMap()..remove('id')); } else { await db.update('bands', b.toMap(), where: 'id=?', whereArgs: [b.id]); }
    await recomputeAll();
  }
  static Future<void> deleteBand(int id) async { await db.delete('bands', where: 'id=?', whereArgs: [id]); await recomputeAll(); }

  static Future<int> computePrice(Trip t, List<Band> bs, int ghepDi, int ghepDen) async {
    final b = bs.where((x) => x.id == t.bandId).firstOrNull;
    final extraFrom = (t.from.where((e) => e.trim().isNotEmpty).length - 1).clamp(0, 99);
    final extraTo = (t.to.where((e) => e.trim().isNotEmpty).length - 1).clamp(0, 99);
    return (b?.price ?? 0) + extraFrom * ghepDi + extraTo * ghepDen;
  }
  static Future<(int, int)> ghep() async => (int.tryParse(await get('gia_ghep_di', '30000')) ?? 30000, int.tryParse(await get('gia_ghep_den', '30000')) ?? 30000);

  static Future<void> recomputeAll() async {
    final bs = await bands();
    final (gd, gn) = await ghep();
    for (final t in await trips()) {
      await db.update('trips', {'price': await computePrice(t, bs, gd, gn)}, where: 'id=?', whereArgs: [t.id]);
    }
  }

  static Future<List<Trip>> trips() async => (await db.query('trips', orderBy: 'date DESC, id DESC')).map(Trip.from_).toList();
  static Future<void> saveTrip(Trip t) async {
    final (gd, gn) = await ghep();
    t.price = await computePrice(t, await bands(), gd, gn);
    if (t.id == null) { await db.insert('trips', t.toMap()..remove('id')); } else { await db.update('trips', t.toMap(), where: 'id=?', whereArgs: [t.id]); }
    for (final pl in [...t.from, ...t.to].map((e) => e.trim()).where((e) => e.isNotEmpty)) {
      await db.rawInsert('INSERT INTO places(name, uses) VALUES(?,1) ON CONFLICT(name) DO UPDATE SET uses=uses+1', [pl]);
    }
  }
  static Future<void> deleteTrip(int id) => db.delete('trips', where: 'id=?', whereArgs: [id]);
  static Future<List<String>> places() async => (await db.query('places', orderBy: 'uses DESC')).map((e) => '${e['name']}').toList();

  static Future<List<Fuel>> fuels() async => (await db.query('fuel', orderBy: 'date DESC, id DESC')).map(Fuel.from).toList();
  static Future<void> saveFuel(Fuel f) async => f.id == null ? await db.insert('fuel', f.toMap()..remove('id')) : await db.update('fuel', f.toMap(), where: 'id=?', whereArgs: [f.id]);
  static Future<void> deleteFuel(int id) => db.delete('fuel', where: 'id=?', whereArgs: [id]);

  static Future<Map<String, dynamic>> exportAll() async => {
        'app': 'so_thu_nhap', 'version': 1,
        for (final t in ['trips', 'bands', 'fuel', 'places', 'settings']) t: await db.query(t),
      };
  static Future<void> importAll(Map<String, dynamic> data) async {
    await db.transaction((tx) async {
      for (final t in ['trips', 'bands', 'fuel', 'places', 'settings']) {
        if (data[t] is! List) continue;
        await tx.delete(t);
        for (final row in data[t]) { await tx.insert(t, Map<String, Object?>.from(row)); }
      }
    });
    await recomputeAll();
  }

  /// CSV: vehicle,route,label,base_price  (giá gốc, Nội Thành tự x1.28). Hoặc JSON list cùng khoá.
  static Future<int> importBands(List<Map<String, dynamic>> rows, {bool replace = false}) async {
    if (replace) await db.delete('bands');
    var n = 0;
    for (final r in rows) {
      final price = int.tryParse('${r['base_price'] ?? r['price']}'.replaceAll(RegExp(r'[^0-9]'), ''));
      if (price == null) continue;
      await db.insert('bands', {'vehicle': '${r['vehicle']}'.trim(), 'route': '${r['route']}'.trim(), 'label': '${r['label']}'.trim(), 'base_price': price, 'placeholder': 0});
      n++;
    }
    await recomputeAll();
    return n;
  }
}

/// Công & lương cho danh sách chuyến (đã lọc theo tháng).
class Payroll {
  final int days, trips, tripMoney;
  final double cong, congThuong, congTangCa;
  Payroll(this.days, this.trips, this.tripMoney, this.cong, this.congThuong, this.congTangCa);
  static double get donGia => luongThang / congChuan;
  int get luong => (congThuong * donGia).round();
  int get tangCa => (congTangCa * donGia * 2).round();
  int get tong => tripMoney + luong + tangCa;
  static Payroll of(List<Trip> ts) {
    final perDay = <String, int>{};
    for (final t in ts) { perDay[t.date] = (perDay[t.date] ?? 0) + 1; }
    final cong = perDay.values.fold<double>(0, (s, n) => s + (n >= 2 ? 1 : 0.5));
    final thuong = cong > congChuan ? congChuan.toDouble() : cong;
    return Payroll(perDay.length, ts.length, ts.fold(0, (s, t) => s + t.price), cong, thuong, cong - thuong);
  }
}
