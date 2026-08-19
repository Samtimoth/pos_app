import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Deterministic category colour + icon from string hash.
class CatStyle {
  static const _palette = <Color>[
    Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFFEF4444),
    Color(0xFFF59E0B), Color(0xFF8B5CF6), Color(0xFFEC4899),
    Color(0xFF06B6D4), Color(0xFF84CC16), Color(0xFFF97316),
    Color(0xFF14B8A6), Color(0xFFA855F7), Color(0xFFE11D48),
  ];

  static Color color(String cat) {
    if (cat.isEmpty) return AppColors.primary;
    final idx = cat.codeUnits.fold(0, (h, c) => h * 31 + c).abs() % _palette.length;
    return _palette[idx];
  }

  static IconData icon(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('drink') || c.contains('maji') || c.contains('juice') ||
        c.contains('soda')  || c.contains('bia')  || c.contains('mvinyo')) {
      return Icons.local_drink_rounded;
    }
    if (c.contains('food')  || c.contains('chakula') || c.contains('mkate') ||
        c.contains('uji')   || c.contains('ugali')   || c.contains('wali')) {
      return Icons.lunch_dining_rounded;
    }
    if (c.contains('cloth') || c.contains('nguo')    || c.contains('shoe') ||
        c.contains('viatu') || c.contains('dress')) {
      return Icons.checkroom_rounded;
    }
    if (c.contains('electron') || c.contains('simu') || c.contains('phone') ||
        c.contains('laptop')   || c.contains('gadget')) {
      return Icons.devices_rounded;
    }
    if (c.contains('pharma') || c.contains('dawa')   || c.contains('medicine') ||
        c.contains('health') || c.contains('afya')) {
      return Icons.medication_rounded;
    }
    if (c.contains('beauty') || c.contains('urembo') || c.contains('cream') ||
        c.contains('soap')   || c.contains('sabuni')) {
      return Icons.spa_rounded;
    }
    if (c.contains('stationer') || c.contains('kalamu') || c.contains('daftari') ||
        c.contains('karatasi')) {
      return Icons.edit_note_rounded;
    }
    if (c.contains('fish') || c.contains('samaki')) {
      return Icons.set_meal_rounded;
    }
    if (c.contains('fruit') || c.contains('mboga')   || c.contains('matunda')) {
      return Icons.eco_rounded;
    }
    if (c.contains('grain') || c.contains('nafaka')  || c.contains('mchele') ||
        c.contains('mahindi')) {
      return Icons.grass_rounded;
    }
    if (c.contains('clean') || c.contains('sabuni')  || c.contains('detergent')) {
      return Icons.cleaning_services_rounded;
    }
    if (c.contains('toy')   || c.contains('mchezo')) {
      return Icons.sports_esports_rounded;
    }
    if (c.contains('build') || c.contains('ujenzi')  || c.contains('cement')) {
      return Icons.construction_rounded;
    }
    return Icons.inventory_2_rounded;
  }
}
