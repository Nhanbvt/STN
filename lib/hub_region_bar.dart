import 'package:flutter/material.dart';
import 'hub_region.dart';

const kHubRed = Color(0xFFC62828);

/// Thanh 3 ô Nội thành | Nội vùng | Seller (theo mẫu).
class HubRegionBar extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const HubRegionBar({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: kHubRed, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(children: [
          for (var i = 0; i < kRegionOrder.length; i++) ...[
            if (i > 0) Container(width: 1.5, height: 40, color: kHubRed),
            Expanded(child: _Seg(
              label: kRegionLabels[kRegionOrder[i]]!,
              selected: value == kRegionOrder[i],
              onTap: () => onChanged(kRegionOrder[i]),
            )),
          ],
        ]),
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Seg({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: selected ? kHubRed : Colors.white,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 40,
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: selected ? Colors.white : kHubRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
          ),
        ),
      );
}

String hubRegionOf(Map<String, Object?> h) {
  final r = '${h['region'] ?? ''}'.trim();
  if (r == kRegionNoiThanh || r == kRegionNoiVung || r == kRegionSeller) return r;
  return classifyHubRegion('${h['name'] ?? ''}');
}
