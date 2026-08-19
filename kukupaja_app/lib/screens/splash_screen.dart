import 'package:flutter/material.dart';

import '../core/api_config.dart';
import '../core/local_store.dart';
import 'customer/customer_shell.dart';

const _ink = Color(0xFF070708);
const _charcoal = Color(0xFF242426);
const _brandRed = Color(0xFFFF1710);
const _brandOrange = Color(0xFFFF6A00);
const _brandGold = Color(0xFFFFC400);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _glowController;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..forward();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    )..repeat(reverse: true);
    _scale = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutBack,
    );
    _fade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0, .7, curve: Curves.easeOut),
    );
    _prepareAndNavigate();
  }

  Future<void> _prepareAndNavigate() async {
    final configFuture = ApiConfig.init();
    final sessionFuture = SessionStore.load();
    final delayFuture = Future<void>.delayed(
      const Duration(milliseconds: 2300),
    );
    final session = await sessionFuture;
    await configFuture;
    await delayFuture;
    if (!mounted) return;
    final page = session == null
        ? const CustomerShell()
        : session.role == 'customer'
        ? CustomerShell(session: session)
        : CustomerShell(pendingElevatedSession: session);
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, secondaryAnimation) => page,
        transitionsBuilder: (_, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _ink,
    body: Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -.25),
              radius: 1.05,
              colors: [_charcoal, Color(0xFF130A08), _ink],
              stops: [0, .52, 1],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            final glow = _glowController.value;
            return Center(
              child: FadeTransition(
                opacity: _fade,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: _scale,
                      child: Container(
                        width: 292,
                        height: 292,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(66),
                          boxShadow: [
                            BoxShadow(
                              color: _brandRed.withValues(
                                alpha: .20 + glow * .13,
                              ),
                              blurRadius: 58 + glow * 24,
                              spreadRadius: glow * 5,
                            ),
                            BoxShadow(
                              color: _brandOrange.withValues(
                                alpha: .13 + glow * .08,
                              ),
                              blurRadius: 90,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(66),
                          child: Image.asset(
                            'assets/kukupaja_icon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'TUNAUZA LADHA YA KUKU',
                      style: TextStyle(
                        color: _brandGold,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Soko la kuku, moja kwa moja.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .62),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 62,
          child: FadeTransition(
            opacity: _fade,
            child: Center(
              child: SizedBox(
                width: 156,
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: AnimatedBuilder(
                    animation: _glowController,
                    builder: (context, child) => LinearProgressIndicator(
                      value: .18 + _glowController.value * .72,
                      backgroundColor: const Color(0xFF2D1610),
                      valueColor: const AlwaysStoppedAnimation(_brandOrange),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
