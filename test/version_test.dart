import 'package:flutter_test/flutter_test.dart';
import 'package:so_thu_nhap/updater.dart';

void main() {
  test('compareVersions numeric', () {
    expect(compareVersions('1.1.9', '1.0.18'), 1);
    expect(compareVersions('2.0.0', '1.9.9'), 1);
    expect(compareVersions('v1.1.0', '1.0.9'), 1);
    expect(compareVersions('1.1.9', '1.1.9'), 0);
  });
}
