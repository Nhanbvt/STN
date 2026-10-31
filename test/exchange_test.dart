import 'package:flutter_test/flutter_test.dart';
import 'package:so_thu_nhap/db.dart';
import 'package:so_thu_nhap/exchange.dart';

void main() {
  test('parse csv & json, diff by name', () {
    final csv = parseItems('\uFEFFname,phone,note\n"Hub A, Q1",0901,"x"\nhub b,0902,\n', 'phones', ['name', 'phone', 'note']);
    expect(csv.length, 2);
    expect(csv.first['name'], 'Hub A, Q1');
    final js = parseItems('{"app":"so_thu_nhap","kind":"hubs","items":[{"name":"H1","lat":10.5,"lng":106.1,"note":""}]}', 'hubs', ['name', 'lat', 'lng', 'note']);
    expect(js.first['lat'], 10.5);
    final (add, chg) = DB.diff([{'id': 1, 'name': 'HUB B', 'phone': '0999', 'note': ''}], csv, ['phone', 'note']);
    expect(add.map((e) => e['name']), ['Hub A, Q1']);
    expect(chg.length, 1);
  });
}
