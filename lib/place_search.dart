/// Tìm nhanh Nơi đi / Nơi đến trong bộ nhớ: bỏ dấu, không phân biệt hoa thường,
/// khớp đầu chuỗi (hoặc đầu từ) xếp trước, tối đa [limit] kết quả.
const _src = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
const _dst = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
final _map = {for (var i = 0; i < _src.length; i++) _src.codeUnitAt(i): _dst.codeUnitAt(i)};

String fold(String s) => String.fromCharCodes(s.toLowerCase().codeUnits.map((c) => _map[c] ?? c)).trim();

class PlaceIndex {
  final List<String> names;
  final List<String> _folded;
  PlaceIndex(Iterable<String> all) : names = _dedupe(all), _folded = [] { _folded.addAll(names.map(fold)); }
  static List<String> _dedupe(Iterable<String> all) { final seen = <String>{}; return [for (final n in all) if (n.trim().isNotEmpty && seen.add(fold(n))) n.trim()]; }

  List<String> search(String q, {int limit = 20}) {
    final f = fold(q);
    if (f.isEmpty) return const [];
    final a = <String>[], b = <String>[], c = <String>[];
    for (var i = 0; i < names.length; i++) {
      final s = _folded[i];
      if (s.startsWith(f)) { a.add(names[i]); if (a.length >= limit) break; }
      else if (s.contains(' $f')) { b.add(names[i]); }
      else if (s.contains(f)) { c.add(names[i]); }
    }
    return [...a, ...b, ...c].take(limit).toList();
  }
}

/// Bản cache dùng chung: mở form chuyến dùng ngay, nạp lại ngầm khi mở.
PlaceIndex placeCache = PlaceIndex(const []);
