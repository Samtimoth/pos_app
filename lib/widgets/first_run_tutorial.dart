import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class TutorialStep {
  const TutorialStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class FirstRunTutorial {
  static final Set<String> _showing = <String>{};

  static Future<void> showIfNeeded(
    BuildContext context, {
    required String storageKey,
    required List<TutorialStep> steps,
  }) async {
    if (steps.isEmpty || _showing.contains(storageKey)) return;

    final key = 'tutorial_seen_$storageKey';
    if (StorageService.getBool(key) == true) return;
    if (!context.mounted) return;

    _showing.add(storageKey);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Tutorial',
      barrierColor: Colors.black.withAlpha(170),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, _, _) {
        return _TutorialDialog(
          steps: steps,
          onDone: () async {
            await StorageService.saveBool(key, true);
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          },
        );
      },
      transitionBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: .94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
    _showing.remove(storageKey);
  }
}

class _TutorialDialog extends StatefulWidget {
  const _TutorialDialog({required this.steps, required this.onDone});

  final List<TutorialStep> steps;
  final Future<void> Function() onDone;

  @override
  State<_TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<_TutorialDialog> {
  int _index = 0;
  bool _closing = false;

  TutorialStep get _step => widget.steps[_index];

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
    setState(() => _index++);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.primaryLt.withAlpha(70)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(95),
                      blurRadius: 34,
                      offset: const Offset(0, 18),
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
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: AppColors.gradPrimary,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryLt.withAlpha(55),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            _step.icon,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_index + 1}/${widget.steps.length}',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(.04, 0),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Column(
                        key: ValueKey(_index),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _step.title,
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 22,
                              height: 1.12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _step.body,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        ...List.generate(widget.steps.length, (i) {
                          final active = i == _index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: active ? 24 : 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.accent
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(100),
                            ),
                          );
                        }),
                        const Spacer(),
                        TextButton(
                          onPressed: _closing ? null : _finish,
                          child: Text(
                            'Ruka',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _closing ? null : _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _index == widget.steps.length - 1
                                ? 'Maliza'
                                : 'Endelea',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
