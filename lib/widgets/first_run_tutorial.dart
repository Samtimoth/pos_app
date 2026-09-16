import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// One tutorial step. When [targetId] names a [TutorialTarget] that is on
/// screen, the step is shown as a coach mark: the screen dims, the target is
/// cut out with a glowing spotlight and the explanation card sits right next
/// to it with an arrow. Steps without a target fall back to a bottom card.
class TutorialStep {
  const TutorialStep({
    required this.icon,
    required this.title,
    required this.body,
    this.targetId,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? targetId;
}

/// Wrap any widget you want a tutorial step to point at.
///
///     TutorialTarget(id: 'dash_avatar', child: CircleAvatar(...))
///
/// Ids are global; the last mounted widget with a given id wins, so the same
/// id can be used in the phone and desktop layouts.
class TutorialTarget extends StatefulWidget {
  const TutorialTarget({super.key, required this.id, required this.child});
  final String id;
  final Widget child;

  @override
  State<TutorialTarget> createState() => _TutorialTargetState();
}

class _TutorialTargetState extends State<TutorialTarget> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    TutorialTargets._register(widget.id, _key);
  }

  @override
  void didUpdateWidget(TutorialTarget old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      TutorialTargets._unregister(old.id, _key);
      TutorialTargets._register(widget.id, _key);
    }
  }

  @override
  void dispose() {
    TutorialTargets._unregister(widget.id, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(key: _key, child: widget.child);
}

class TutorialTargets {
  TutorialTargets._();
  static final Map<String, List<GlobalKey>> _keys = {};

  static void _register(String id, GlobalKey key) =>
      (_keys[id] ??= []).add(key);

  static void _unregister(String id, GlobalKey key) {
    _keys[id]?.remove(key);
    if (_keys[id]?.isEmpty ?? false) _keys.remove(id);
  }

  /// The most recently mounted, currently attached key for [id].
  static GlobalKey? find(String id) {
    final list = _keys[id];
    if (list == null) return null;
    for (final k in list.reversed) {
      if (k.currentContext?.mounted ?? false) return k;
    }
    return null;
  }
}

class FirstRunTutorial {
  static final Set<String> _showing = <String>{};

  /// Reset every "seen" flag (used by the Help → "Onyesha tutorial tena").
  static Future<void> resetAll() async {
    for (final k in const [
      'login', 'business_select',
      'dashboard_nav_0', 'dashboard_nav_1', 'dashboard_nav_2',
      'dashboard_nav_3', 'dashboard_nav_4',
    ]) {
      await StorageService.remove('tutorial_seen_$k');
    }
  }

  static Future<void> showIfNeeded(
    BuildContext context, {
    required String storageKey,
    required List<TutorialStep> steps,
    bool force = false,
  }) async {
    if (steps.isEmpty || _showing.contains(storageKey)) return;

    final key = 'tutorial_seen_$storageKey';
    if (!force && StorageService.getBool(key) == true) return;
    if (!context.mounted) return;

    _showing.add(storageKey);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Tutorial',
      barrierColor: Colors.transparent, // we paint our own dim + spotlight
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, _) => _CoachMarks(
        steps: steps,
        onDone: () async {
          await StorageService.saveBool(key, true);
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
        },
      ),
      transitionBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
    _showing.remove(storageKey);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Coach-mark overlay
// ─────────────────────────────────────────────────────────────────────────────
class _CoachMarks extends StatefulWidget {
  const _CoachMarks({required this.steps, required this.onDone});
  final List<TutorialStep> steps;
  final Future<void> Function() onDone;

  @override
  State<_CoachMarks> createState() => _CoachMarksState();
}

class _CoachMarksState extends State<_CoachMarks>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _closing = false;
  Rect? _target; // global rect of the highlighted widget, null = none
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  TutorialStep get _step => widget.steps[_index];

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Scroll the target into view (if it is inside a scrollable) and measure it.
  Future<void> _locate() async {
    // Let page-entrance / tab-switch animations finish before measuring.
    await Future.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    final id = _step.targetId;
    final key = id == null ? null : TutorialTargets.find(id);
    Rect? rect;
    if (key != null && key.currentContext != null) {
      try {
        await Scrollable.ensureVisible(
          key.currentContext!,
          alignment: 0.35,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      } catch (_) {}
      // wait a frame so the scroll settles before measuring
      await WidgetsBinding.instance.endOfFrame;
      final box = key.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize && box.attached) {
        final origin = box.localToGlobal(Offset.zero);
        rect = origin & box.size;
      }
    }
    if (mounted) setState(() => _target = rect);
  }

  Future<void> _finish() async {
    if (_closing) return;
    setState(() => _closing = true);
    await widget.onDone();
  }

  void _next() {
    if (_index >= widget.steps.length - 1) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _target = null;
    });
    _locate();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final target = _target;

    // Spotlight rect (a little larger than the widget, rounded)
    final spot = target == null
        ? null
        : Rect.fromLTRB(
            math.max(0, target.left - 8),
            math.max(0, target.top - 8),
            math.min(size.width, target.right + 8),
            math.min(size.height, target.bottom + 8),
          );

    // Card placement: below the target if there is room, else above,
    // else (no target) docked at the bottom.
    const cardMaxW = 400.0;
    final cardW = math.min(cardMaxW, size.width - 32);
    final cardEstH = 190.0;
    double? cardTop, cardBottom;
    bool arrowUp = true; // arrow points up (card below target)
    double arrowX = size.width / 2;
    if (spot != null) {
      final roomBelow = size.height - pad.bottom - spot.bottom;
      final roomAbove = spot.top - pad.top;
      if (roomBelow >= cardEstH + 20 || roomBelow >= roomAbove) {
        cardTop = spot.bottom + 14;
        arrowUp = true;
      } else {
        cardBottom = size.height - spot.top + 14;
        arrowUp = false;
      }
      arrowX = spot.center.dx;
    } else {
      cardBottom = pad.bottom + 20;
    }
    // Keep the card horizontally around the target but inside the screen.
    double cardLeft = (spot?.center.dx ?? size.width / 2) - cardW / 2;
    cardLeft = cardLeft.clamp(16.0, math.max(16.0, size.width - cardW - 16));
    final arrowLeft = (arrowX - 10).clamp(cardLeft + 18, cardLeft + cardW - 38);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dim + spotlight
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, _) => CustomPaint(
                painter: _SpotlightPainter(
                  spot: spot,
                  glow: 0.35 + 0.65 * _pulse.value,
                ),
              ),
            ),
          ),
          // Tap on the dimmed area → next
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closing ? null : _next,
            ),
          ),
          // Arrow
          if (spot != null)
            Positioned(
              left: arrowLeft,
              top: arrowUp ? spot.bottom + 2 : null,
              bottom: arrowUp ? null : size.height - spot.top + 2,
              child: CustomPaint(
                size: const Size(20, 12),
                painter: _ArrowPainter(up: arrowUp),
              ),
            ),
          // Card
          Positioned(
            left: cardLeft,
            width: cardW,
            top: cardTop,
            bottom: cardBottom,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _card(context, key: ValueKey(_index)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, {required Key key}) => Container(
        key: key,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primaryLt.withAlpha(90)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(120),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: AppColors.gradPrimary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_step.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _step.title,
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${_index + 1}/${widget.steps.length}',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _step.body,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ...List.generate(widget.steps.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: active ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: active ? AppColors.accent : AppColors.border,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  );
                }),
                const Spacer(),
                TextButton(
                  onPressed: _closing ? null : _finish,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: Text(
                    'Ruka',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: _closing ? null : _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _index == widget.steps.length - 1 ? 'Maliza' : 'Endelea',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _SpotlightPainter extends CustomPainter {
  final Rect? spot;
  final double glow;
  const _SpotlightPainter({required this.spot, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final dim = Paint()..color = Colors.black.withAlpha(178);
    if (spot == null) {
      canvas.drawPath(full, dim);
      return;
    }
    final rr = RRect.fromRectAndRadius(spot!, const Radius.circular(16));
    final hole = Path()..addRRect(rr);
    canvas.drawPath(
      Path.combine(PathOperation.difference, full, hole),
      dim,
    );
    // pulsing ring
    canvas.drawRRect(
      rr.inflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.accentBright.withAlpha((90 + 140 * glow).round()),
    );
    canvas.drawRRect(
      rr.inflate(6 + 4 * glow),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.accentBright.withAlpha((20 + 60 * (1 - glow)).round()),
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      old.spot != spot || old.glow != glow;
}

class _ArrowPainter extends CustomPainter {
  final bool up;
  const _ArrowPainter({required this.up});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path();
    if (up) {
      p
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    } else {
      p
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close();
    }
    canvas.drawPath(p, Paint()..color = AppColors.primaryLt);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter old) => old.up != up;
}
