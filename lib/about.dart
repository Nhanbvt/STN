import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const zaloGroup = 'https://zalo.me/g/9bxfh7yuvs5drkegefpp';

Future<void> showAppInfo(BuildContext context) async {
  final info = await PackageInfo.fromPlatform();
  if (!context.mounted) return;
  await showDialog(context: context, builder: (c) => AlertDialog(
    title: const Text('Thông tin App', textAlign: TextAlign.center),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.asset('assets/app_icon.png', height: 96, width: 96)),
      const SizedBox(height: 8),
      Text(info.appName.isEmpty ? 'Sổ Thu Nhập' : info.appName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Text('Phiên bản ${info.version} (build ${info.buildNumber})'),
      const SizedBox(height: 4),
      const Text('Design: Bùi Văn Trung Nhân', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset('assets/zalo_group_qr.jpg', height: 300, fit: BoxFit.contain)),
      const SizedBox(height: 8),
      const Text('Quét mã để xin vào nhóm STN Định Vị SĐT Hub', textAlign: TextAlign.center),
      const SizedBox(height: 8),
      FilledButton.icon(onPressed: () => launchUrl(Uri.parse(zaloGroup), mode: LaunchMode.externalApplication), icon: const Icon(Icons.group_add), label: const Text('Vào nhóm Zalo')),
      TextButton.icon(onPressed: () async {
        await Clipboard.setData(const ClipboardData(text: zaloGroup));
        if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Đã sao chép link nhóm')));
      }, icon: const Icon(Icons.copy), label: const Text('Sao chép link nhóm')),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('ĐÓNG'))],
  ));
}
