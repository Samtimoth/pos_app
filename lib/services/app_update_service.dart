import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

import '../theme/app_theme.dart';

/// Sasisho la ndani ya app (In-App Update, Google Play pekee) — inaangalia
/// kama toleo jipya limechapishwa kwenye Play Store, kisha inapakua kimya
/// kimya nyuma (flexible — si ya kulazimisha) na kuonyesha ujumbe wa
/// kubonyeza "Weka Upya" ukishakamilika. Haiathiri Android isiyotoka Play
/// Store, iOS, wavuti au desktop — inajilinda kimya kwenye hizo zote.
class AppUpdateService {
  static bool _checked = false;

  /// Piga mara moja tu kwa kila mzunguko wa app (mfano: ndani ya
  /// dashboard's initState). Haiwahi kutupa (throw) nje — matatizo yote
  /// yanamezwa kimya, sasisho si jambo la lazima kwa kuendelea kutumia app.
  static Future<void> checkAndPrompt(BuildContext context) async {
    if (_checked) return;
    _checked = true;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;

      if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        if (!context.mounted) return;
        _showReadyBanner(context);
      } else if (info.immediateUpdateAllowed) {
        // Play Store haikubali flexible kwa toleo hili (mfano: sasisho la
        // lazima la usalama) — tumia mwongozo wake wa immediate update.
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (_) {
      // Kimya — si tatizo la mtumiaji (mfano: app haikupakuliwa Play Store,
      // hakuna intaneti, au Play Store haipatikani kwenye kifaa hiki).
    }
  }

  static void _showReadyBanner(BuildContext context) {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        backgroundColor: AppColors.bgCard,
        content: Text(
          'Sasisho jipya la app limepakuliwa. Bonyeza "Weka Upya" kulitumia.',
          style: TextStyle(color: AppColors.textWhite, fontSize: 13),
        ),
        leading: Icon(Icons.system_update_rounded, color: AppColors.accent),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              InAppUpdate.completeFlexibleUpdate();
            },
            child: Text('Weka Upya', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
            child: Text('Baadaye', style: TextStyle(color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }
}
