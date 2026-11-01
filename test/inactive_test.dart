import 'package:flutter_test/flutter_test.dart';
import 'package:so_thu_nhap/contacts.dart';
import 'package:so_thu_nhap/phones.dart';

void main() {
  test('old JSON without flag stays active', () {
    final m = parsePhoneFile('{"items":[{"name":"Hub A","phone":"0901234567"}]}');
    expect(m.values.single.$2.single.inactive, false);
  });
  test('CSV status inactive parsed; merge marks inactive, never deletes', () {
    final m = parsePhoneFile('name,title,contact_name,phone,status,note\nHub A,Anh,Ba,0901234567,inactive,\n');
    final inc = m.values.single.$2;
    expect(inc.single.inactive, true);
    final mine = [Contact(phone: '0901234567'), Contact(phone: '0911111111')];
    final out = mergeContacts(mine, inc);
    expect(out.length, 2);
    expect(out.first.inactive, true);
    expect(sameContacts(mine, out), false);
    expect(sortActiveFirst(out).first.phone, '0911111111');
  });
  test('JSON active=false roundtrip', () {
    final c = Contact.from(Contact(phone: '1', inactive: true).toJson());
    expect(c.inactive, true);
  });
}
