import 'package:flutter_test/flutter_test.dart';
import 'package:so_thu_nhap/place_search.dart';

void main() {
  test('accent-insensitive, prefix first, limit, fast on 500', () {
    final names = [for (var i = 0; i < 500; i++) 'Kho Số $i Quận ${i % 12}', 'Hub Bình Dương', 'Thủ Đức Hub', 'Bình Thạnh'];
    final idx = PlaceIndex(names);
    expect(idx.search('binh').first, 'Bình Thạnh');
    expect(idx.search('BINH DUONG'), ['Hub Bình Dương']);
    expect(idx.search('thu duc'), ['Thủ Đức Hub']);
    expect(idx.search('kho').length, 20);
    final sw = Stopwatch()..start();
    for (var i = 0; i < 200; i++) { idx.search('quan 1'); }
    expect(sw.elapsedMilliseconds < 500, true);
  });
}
