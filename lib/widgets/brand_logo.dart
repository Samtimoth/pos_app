import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 84,
    this.radius,
    this.showShadow = true,
  });

  static const assetPath = 'assets/branding/duka_kiganjani.png';

  final double size;
  final double? radius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final logoRadius = radius ?? size * 0.22;

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.02),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(logoRadius),
        border: Border.all(color: Colors.white.withAlpha(130), width: 1),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: AppColors.primaryLt.withAlpha(70),
                  blurRadius: size * 0.22,
                  offset: Offset(0, size * 0.08),
                ),
                BoxShadow(
                  color: Colors.black.withAlpha(45),
                  blurRadius: size * 0.12,
                  offset: Offset(0, size * 0.04),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(assetPath, fit: BoxFit.cover),
    );
  }
}
