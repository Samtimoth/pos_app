import 'package:flutter/material.dart';

// ── Color Palette — Forest Green Fintech Theme ────────────────────────────────
class AppColors {
  // ── BRAND / ACCENT — static const (never change with theme) ──────────────
  static const primary = Color(0xFF065F46);
  static const primaryMid = Color(0xFF047857);
  static const primaryLt = Color(0xFF10B981);
  static const accent = Color(0xFFA3E635);
  static const accentBright = Color(0xFFBEF264);
  static const accentDk = Color(0xFF84CC16);
  static const primaryDk = Color(0xFF064E3B);

  // ── CHART colors — const ─────────────────────────────────────────────────
  static const chartBlue = Color(0xFF3B82F6);
  static const chartGreen = Color(0xFF22C55E);
  static const chartPurple = Color(0xFF8B5CF6);
  static const chartOrange = Color(0xFFF97316);
  static const chartRed = Color(0xFFEF4444);
  static const chartGray = Color(0xFF94A3B8);
  static const chartLime = Color(0xFFA3E635);

  // ── GRADIENTS — const ────────────────────────────────────────────────────
  static const gradPrimary = [Color(0xFF065F46), Color(0xFF047857)];
  static const gradGreen = [Color(0xFF16A34A), Color(0xFF15803D)];
  static const gradLime = [Color(0xFFA3E635), Color(0xFF84CC16)];
  static const gradPurple = [Color(0xFF7C3AED), Color(0xFF6D28D9)];
  static const gradOrange = [Color(0xFFF97316), Color(0xFFEA580C)];
  static const gradRed = [Color(0xFFDC2626), Color(0xFFB91C1C)];
  static const gradHeader = [
    Color(0xFF064E3B),
    Color(0xFF065F46),
    Color(0xFF047857),
  ];

  // ── HEADER bgs — always green (brand identity in both light & dark) ───────
  static const bgHeader = Color(0xFF064E3B);
  static const bgHeaderMid = Color(0xFF065F46);

  // ─────────────────────────────────────────────────────────────────────────
  // SURFACE COLORS — mutable, updated by ThemeProvider when theme changes.
  // Widgets read these at build time and get correct values after rebuild.
  // ─────────────────────────────────────────────────────────────────────────

  // Dark palette private seeds (used in ThemeData const contexts)
  static const _dBg = Color(0xFF0A1628);
  static const _dBgCard = Color(0xFF132134);
  static const _dBgDark = Color(0xFF060E1C);
  static const _dBgInput = Color(0xFF0A1628);
  static const _dBorder = Color(0xFF1E3A5F);
  static const _dTxtW = Color(0xFFFFFFFF);
  static const _dTxtM = Color(0xFF94A3B8);
  static const _dTxtL = Color(0xFFCBD5E1);
  static const _dTxtG = Color(0xFF6EE7B7);

  // Light palette private seeds
  static const _lBg = Color(0xFFF1F5F9);
  static const _lBgCard = Color(0xFFFFFFFF);
  static const _lBgDark = Color(0xFFE2E8F0);
  static const _lBgInput = Color(0xFFFFFFFF);
  static const _lBorder = Color(0xFFCBD5E1);
  static const _lTxtW = Color(0xFF0F172A); // near-black text (replaces "white")
  static const _lTxtM = Color(0xFF64748B);
  static const _lTxtL = Color(0xFF475569);
  static const _lTxtG = Color(0xFF047857);

  // ── Public surface fields — start as dark ────────────────────────────────
  static Color bg = _dBg;
  static Color bgCard = _dBgCard;
  static Color bgDark = _dBgDark;
  static Color bgInput = _dBgInput;
  static Color border = _dBorder;
  static Color textWhite = _dTxtW;
  static Color textMuted = _dTxtM;
  static Color textLight = _dTxtL;
  static Color textGreen = _dTxtG;

  // ── Apply helpers ─────────────────────────────────────────────────────────
  static void applyDark() {
    bg = _dBg;
    bgCard = _dBgCard;
    bgDark = _dBgDark;
    bgInput = _dBgInput;
    border = _dBorder;
    textWhite = _dTxtW;
    textMuted = _dTxtM;
    textLight = _dTxtL;
    textGreen = _dTxtG;
  }

  static void applyLight() {
    bg = _lBg;
    bgCard = _lBgCard;
    bgDark = _lBgDark;
    bgInput = _lBgInput;
    border = _lBorder;
    textWhite = _lTxtW;
    textMuted = _lTxtM;
    textLight = _lTxtL;
    textGreen = _lTxtG;
  }
}

// ── Themes ────────────────────────────────────────────────────────────────────
class AppTheme {
  static const _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: _PremiumPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: _PremiumPageTransitionsBuilder(),
      TargetPlatform.linux: _PremiumPageTransitionsBuilder(),
      TargetPlatform.fuchsia: _PremiumPageTransitionsBuilder(),
    },
  );

  // ─── DARK (existing, unchanged visually) ─────────────────────────────────
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors._dBg,
    pageTransitionsTheme: _pageTransitions,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryLt,
      brightness: Brightness.dark,
      surface: AppColors._dBgCard,
      primary: AppColors.primaryLt,
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgHeader,
      foregroundColor: AppColors._dTxtW,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        color: AppColors._dTxtW,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors._dBgCard,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors._dBorder, width: 0.5),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors._dBgInput,
      hintStyle: const TextStyle(color: AppColors._dTxtM, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors._dBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors._dBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accentDk, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors._dBgDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        elevation: 2,
        shadowColor: AppColors.primaryLt.withAlpha(60),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryLt,
      foregroundColor: Colors.white,
      elevation: 10,
      highlightElevation: 14,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbVisibility: WidgetStateProperty.all(false),
      radius: const Radius.circular(999),
      thickness: WidgetStateProperty.all(4),
      thumbColor: WidgetStateProperty.all(AppColors.primaryLt.withAlpha(120)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors._dBgCard,
      selectedColor: AppColors.primaryMid,
      labelStyle: const TextStyle(color: AppColors._dTxtL, fontSize: 12),
      side: const BorderSide(color: AppColors._dBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors._dBgCard,
      selectedItemColor: AppColors.primaryLt,
      unselectedItemColor: AppColors._dTxtM,
      elevation: 0,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors._dBgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors._dBorder),
      ),
    ),
  );

  // ─── LIGHT ───────────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors._lBg,
    pageTransitionsTheme: _pageTransitions,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      surface: AppColors._lBgCard,
      primary: AppColors.primary,
      onSurface: AppColors._lTxtW,
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgHeader, // stay green (brand)
      foregroundColor: Color(0xFFFFFFFF),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        color: Color(0xFFFFFFFF),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors._lBgCard,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors._lBorder, width: 0.5),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors._lBgCard,
      hintStyle: const TextStyle(color: AppColors._lTxtM, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors._lBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors._lBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors._dBgDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        elevation: 2,
        shadowColor: AppColors.primary.withAlpha(45),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 10,
      highlightElevation: 14,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbVisibility: WidgetStateProperty.all(false),
      radius: const Radius.circular(999),
      thickness: WidgetStateProperty.all(4),
      thumbColor: WidgetStateProperty.all(AppColors.primary.withAlpha(110)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors._lBgCard,
      selectedColor: AppColors.primaryMid,
      labelStyle: const TextStyle(color: AppColors._lTxtL, fontSize: 12),
      side: const BorderSide(color: AppColors._lBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors._lBgCard,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors._lTxtM,
      elevation: 0,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors._lBgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors._lBorder),
      ),
    ),
  );
}

class PremiumScrollBehavior extends MaterialScrollBehavior {
  const PremiumScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}

class _PremiumPageTransitionsBuilder extends PageTransitionsBuilder {
  const _PremiumPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.035, 0.025),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class PremiumPageEntrance extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Offset offset;

  const PremiumPageEntrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 460),
    this.offset = const Offset(0, 0.025),
  });

  @override
  State<PremiumPageEntrance> createState() => _PremiumPageEntranceState();
}

class _PremiumPageEntranceState extends State<PremiumPageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
    final curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(curve);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}

// ── Gradient Card ─────────────────────────────────────────────────────────────
class GradientCard extends StatelessWidget {
  final List<Color> colors;
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final List<Color>? gradientEnd;

  const GradientCard({
    super.key,
    required this.colors,
    required this.child,
    this.radius = 20,
    this.padding = const EdgeInsets.all(20),
    this.gradientEnd,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: colors.first.withAlpha(80),
          blurRadius: 20,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
      ],
    ),
    child: child,
  );
}

// ── Staggered Animated List Item ──────────────────────────────────────────────
class StaggeredItem extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration delay;

  const StaggeredItem({
    super.key,
    required this.index,
    required this.child,
    this.delay = const Duration(milliseconds: 60),
  });

  @override
  State<StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<StaggeredItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _opacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(widget.delay * widget.index, () {
      if (mounted) {
        _ctrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacity,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}

// ── Shimmer Loading Widget ─────────────────────────────────────────────────────
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 10,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, ch) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value, 0),
            colors: const [
              Color(0xFF1E293B),
              Color(0xFF2D4060),
              Color(0xFF1E293B),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Counter Animation Widget ──────────────────────────────────────────────────
class AnimatedCounter extends StatefulWidget {
  final double value;
  final String prefix;
  final String Function(double) formatter;
  final TextStyle style;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.value,
    required this.formatter,
    required this.style,
    this.prefix = '',
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _previous = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = Tween<double>(
      begin: 0,
      end: widget.value,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(AnimatedCounter old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _previous = old.value;
      _anim = Tween<double>(
        begin: _previous,
        end: widget.value,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (ctx, ch) => Text(
      '${widget.prefix}${widget.formatter(_anim.value)}',
      style: widget.style,
    ),
  );
}

// ── Animated Notification (overlay toast) ────────────────────────────────────
class AppNotification {
  /// Show a floating, auto-dismissing notification overlay.
  static void show(
    BuildContext context,
    String message,
    Color color, {
    IconData icon = Icons.check_circle_rounded,
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _AppNotificationToast(
        message: message,
        color: color,
        icon: icon,
        duration: duration,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

class _AppNotificationToast extends StatefulWidget {
  final String message;
  final Color color;
  final IconData icon;
  final Duration duration;
  final VoidCallback onDone;

  const _AppNotificationToast({
    required this.message,
    required this.color,
    required this.icon,
    required this.duration,
    required this.onDone,
  });

  @override
  State<_AppNotificationToast> createState() => _AppNotificationToastState();
}

class _AppNotificationToastState extends State<_AppNotificationToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slideY;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideY = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    Future.delayed(widget.duration - const Duration(milliseconds: 380), () {
      if (mounted) {
        _ctrl.reverse().then((_) {
          if (mounted) widget.onDone();
        });
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Positioned(
      top: mq.padding.top + 12,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, _slideY.value * 80),
          child: Opacity(opacity: _opacity.value, child: child),
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: widget.color.withAlpha(80), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withAlpha(50),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withAlpha(60),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: widget.color.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: widget.onDone,
                  child: Icon(
                    Icons.close_rounded,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pulse animation widget ────────────────────────────────────────────────────
class PulseWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  const PulseWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  State<PulseWidget> createState() => _PulseWidgetState();
}

class _PulseWidgetState extends State<PulseWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _anim, child: widget.child);
}
