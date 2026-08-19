import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/app_theme.dart';
import '../../services/api_service.dart';

class AdminWebPortal extends StatefulWidget {
  const AdminWebPortal({super.key});

  @override
  State<AdminWebPortal> createState() => _AdminWebPortalState();
}

class _AdminWebPortalState extends State<AdminWebPortal> {
  late final WebViewController controller;
  int progress = 0;
  String? loadError;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF7F4F1))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) setState(() => progress = value);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => loadError = null);
          },
          onPageFinished: (_) async {
            await controller.runJavaScript(
              "document.documentElement.classList.add('flutter-embed');"
              "document.body.classList.add('flutter-embed');",
            );
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() => loadError = error.description);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(ApiService.adminUrl));
  }

  Future<bool> _goBack() async {
    if (await controller.canGoBack()) {
      await controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop) return;
      if (await _goBack() && context.mounted) Navigator.pop(context);
    },
    child: Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: loadError == null
                  ? WebViewWidget(controller: controller)
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.cloud_off,
                              size: 58,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Admin panel haijafunguka',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(loadError!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => controller.loadRequest(
                                Uri.parse(ApiService.adminUrl),
                              ),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Jaribu tena'),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            if (progress < 100)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: progress == 0 ? null : progress / 100,
                  minHeight: 3,
                  backgroundColor: const Color(0x33000000),
                  color: yellow,
                ),
              ),
            Positioned(
              right: 12,
              bottom: 14,
              child: Material(
                elevation: 8,
                color: green,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: controller.reload,
                  child: const Padding(
                    padding: EdgeInsets.all(13),
                    child: Icon(Icons.refresh, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
