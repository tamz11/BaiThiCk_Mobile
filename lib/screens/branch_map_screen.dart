import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class BranchMapScreen extends StatefulWidget {
  const BranchMapScreen({super.key});

  @override
  State<BranchMapScreen> createState() => _BranchMapScreenState();
}

class _BranchMapScreenState extends State<BranchMapScreen> {
  late final WebViewController _webViewController;
  static const double _fixedOriginLat = 21.007163688438013;
  static const double _fixedOriginLng = 105.82222491143253;
  static const String _embedMapUrl =
      'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d4456.95553737361!2d105.82222491143253!3d21.007163688438013!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x3135ac8109765ba5%3A0xd84740ece05680ee!2zVHLGsOG7nW5nIMSQ4bqhaSBo4buNYyBUaOG7p3kgbOG7o2k!5e1!3m2!1svi!2s!4v1775669957608!5m2!1svi!2s';

  static const List<_BranchInfo> _branches = [
    _BranchInfo(
      id: 'ha_noi_1',
      name: 'Chi nhánh Hà Nội Trung Tâm',
      address: '89 Trần Hưng Đạo, Hoàn Kiếm',
      lat: 21.0285,
      lng: 105.8542,
    ),
    _BranchInfo(
      id: 'ha_noi_2',
      name: 'Chi nhánh Cầu Giấy',
      address: '201 Trần Thái Tông, Cầu Giấy',
      lat: 21.0367,
      lng: 105.7827,
    ),
    _BranchInfo(
      id: 'ha_noi_3',
      name: 'Chi nhánh Đống Đa',
      address: '120 Chùa Bộc, Đống Đa',
      lat: 21.0082,
      lng: 105.8246,
    ),
  ];

  Future<void> _openDirections(_BranchInfo branch) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=$_fixedOriginLat,$_fixedOriginLng&destination=${branch.lat},${branch.lng}&travelmode=driving',
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở Google Maps để dẫn đường.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _webViewController =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..loadHtmlString('''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <style>
      html, body {
        margin: 0;
        padding: 0;
        height: 100%;
        overflow: hidden;
        background: transparent;
      }
      iframe {
        border: 0;
        width: 100%;
        height: 100%;
      }
    </style>
  </head>
  <body>
    <iframe
      src="$_embedMapUrl"
      allowfullscreen
      loading="lazy"
      referrerpolicy="no-referrer-when-downgrade">
    </iframe>
  </body>
</html>
''');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Chi nhánh',
          style: GoogleFonts.lato(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 240,
              child: WebViewWidget(controller: _webViewController),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Text(
              'Chọn chi nhánh để mở Google Maps và dẫn đường',
              style: GoogleFonts.lato(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._branches.map(
            (branch) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    child: Icon(Icons.location_on_rounded, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branch.name,
                          style: GoogleFonts.lato(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          branch.address,
                          style: GoogleFonts.lato(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _openDirections(branch),
                    icon: const Icon(Icons.directions_rounded, size: 16),
                    label: const Text('Dẫn đường'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchInfo {
  const _BranchInfo({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
}
