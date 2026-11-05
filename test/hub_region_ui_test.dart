import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:so_thu_nhap/hub_region.dart';
import 'package:so_thu_nhap/hub_region_bar.dart';

void main() {
  testWidgets('region bar renders 3 segments', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: HubRegionBar(value: kRegionNoiThanh, onChanged: (_) {})),
    ));
    expect(find.text('Nội thành'), findsOneWidget);
    expect(find.text('Nội vùng'), findsOneWidget);
    expect(find.text('Seller'), findsOneWidget);
    await tester.tap(find.text('Nội vùng'));
    await tester.pump();
    await tester.tap(find.text('Seller'));
    await tester.pump();
  });
}
