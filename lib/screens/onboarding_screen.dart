import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_logo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.nextPage});

  final Widget nextPage;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _index = 0;

  late final List<_OnboardingItem> _items = const [
    _OnboardingItem(
      icon: Icons.storefront_rounded,
      title: 'Duka lako mkononi',
      body:
          'Simamia mauzo, bidhaa, madeni na wafanyakazi kupitia simu au desktop kwa mwonekano mmoja safi.',
    ),
    _OnboardingItem(
      icon: Icons.qr_code_scanner_rounded,
      title: 'Uza haraka zaidi',
      body:
          'Tumia POS, barcode scanner, vikapu vya mauzo na malipo yaliyopangwa vizuri kupunguza muda wa foleni.',
    ),
    _OnboardingItem(
      icon: Icons.insights_rounded,
      title: 'Fuatilia biashara yako',
      body:
          'Dashboard, ripoti za mauzo na stock zinakupa picha ya biashara yako kila siku.',
    ),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await StorageService.saveBool('onboarding_done_v1', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => widget.nextPage,
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  void _next() {
    if (_index == _items.length - 1) {
      _finish();
      return;
    }
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _items[_index];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF06130F), Color(0xFF0B2A24), Color(0xFF0E3B2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _finish,
                    child: const Text(
                      'Ruka',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: _items.length,
                    onPageChanged: (value) => setState(() => _index = value),
                    itemBuilder: (context, index) {
                      final data = _items[index];
                      return _OnboardingPage(item: data);
                    },
                  ),
                ),
                Row(
                  children: [
                    ...List.generate(_items.length, (i) {
                      final active = i == _index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: active ? 28 : 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 7),
                        decoration: BoxDecoration(
                          color: active ? AppColors.accent : Colors.white24,
                          borderRadius: BorderRadius.circular(100),
                        ),
                      );
                    }),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _next,
                      icon: Icon(
                        _index == _items.length - 1
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(
                        _index == _items.length - 1 ? 'Anza' : 'Endelea',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.bgDark,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Semantics(label: item.title),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.item});

  final _OnboardingItem item;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 650),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLt.withAlpha(35),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryLt.withAlpha(60),
                      blurRadius: 80,
                      spreadRadius: 16,
                    ),
                  ],
                ),
              ),
              const BrandLogo(size: 166, radius: 34),
              Positioned(
                right: 40,
                bottom: 34,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: AppColors.gradLime),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withAlpha(120)),
                  ),
                  child: Icon(item.icon, color: AppColors.bgDark, size: 30),
                ),
              ),
            ],
          ),
          const SizedBox(height: 42),
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 31,
              height: 1.06,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              item.body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingItem {
  const _OnboardingItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}
