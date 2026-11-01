import 'package:flutter_test/flutter_test.dart';
import 'package:so_thu_nhap/db.dart';
import 'package:so_thu_nhap/exchange.dart';
import 'package:so_thu_nhap/contacts.dart';
import 'package:so_thu_nhap/phones.dart';

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
  test('multi contacts: old row migrates, merge by phone, old & new files', () {
    final old = contactsOf({'phone': '0901 234 567', 'note': 'x'});
    expect(old.single.phone, '0901 234 567');
    final m = mergeContacts(old, [Contact(title: 'Chị', name: 'Lan', phone: '+84901234567'), Contact(name: 'Tuấn', phone: '0912000000')]);
    expect(m.length, 2);
    expect(m.first.label, 'Chị Lan – 0901 234 567');
    final oldCsv = parsePhoneFile('name,phone,note\nHub A,0901,\n');
    expect(oldCsv['hub a']!.$2.single.phone, '0901');
    final newCsv = parsePhoneFile('name,title,contact_name,phone,note\nHub A,Anh,Tuấn,0901,\nHub A,Chị,Lan,0902,\n');
    expect(newCsv['hub a']!.$2.length, 2);
    final js = parsePhoneFile('{"items":[{"name":"Hub B","contacts":[{"title":"Chị","name":"Mai","phone":"0903"}]}]}');
    expect(js['hub b']!.$2.single.label, 'Chị Mai – 0903');
  });
}
