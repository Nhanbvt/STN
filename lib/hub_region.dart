import 'hub_seed_vung.dart';

/// Nhóm hub trên màn Vị trí Hub / Số ĐT Hub.
const kRegionNoiThanh = 'noi_thanh';
const kRegionNoiVung = 'noi_vung';
const kRegionSeller = 'seller';

const kRegionLabels = {
  kRegionNoiThanh: 'Nội thành',
  kRegionNoiVung: 'Nội vùng',
  kRegionSeller: 'Seller',
};

const kRegionOrder = [kRegionNoiThanh, kRegionNoiVung, kRegionSeller];

final _provincePrefix = RegExp(r'^\d\d-[A-Z]{3}\b');

/// Phân loại hub theo tên. [extraNoiVung] bổ sung tên (lowercase) coi là nội vùng.
String classifyHubRegion(String name, {Set<String>? extraNoiVung}) {
  final n = name.trim();
  if (n.isEmpty) return kRegionNoiThanh;
  final lower = n.toLowerCase();
  if (lower.contains('seller')) return kRegionSeller;
  // HCM Mega SOC và 51-HCM… luôn nội thành.
  if (lower == 'hcm mega soc' || n.startsWith('51-HCM')) return kRegionNoiThanh;
  if (_provincePrefix.hasMatch(n) && !n.startsWith('51-HCM')) return kRegionNoiVung;
  final vung = extraNoiVung ?? hubSeedVungNames;
  if (vung.contains(lower)) return kRegionNoiVung;
  return kRegionNoiThanh;
}
