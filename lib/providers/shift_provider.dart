import 'package:flutter/material.dart';

import '../services/crm_api.dart';

/// Zamu (shift/register) inayoendelea kwa cashier aliyeingia sasa — huhifadhi
/// hali ili vitufe vya POS (desktop+simu) vionyeshe hali ile ile bila kila
/// moja kufanya ombi lake kwa server (angalia HeldSalesProvider kwa muundo
/// kama huu, tofauti ni hii inasoma kutoka server, si local cache).
class ShiftProvider extends ChangeNotifier {
  Map<String, dynamic>? _current;
  bool _loading = false;

  Map<String, dynamic>? get current => _current;
  bool get isOpen => _current != null;
  bool get loading => _loading;

  Future<void> refresh(CrmApi crm, int businessId, int userId) async {
    _loading = true;
    notifyListeners();
    try {
      _current = await crm.getCurrentShift(businessId, userId);
    } catch (_) {
      // haiathiri UI kubwa — kitufe kitaonyesha "Fungua Zamu" kwa default
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clear() {
    _current = null;
    notifyListeners();
  }
}
