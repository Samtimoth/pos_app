import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/sale.dart';
import '../services/local_db.dart';

/// A cart "parked" mid-checkout so the cashier can serve another customer,
/// then come back and finish it. Purely local (kv_cache, no server sync) —
/// it isn't a sale until it's actually checked out, so there's nothing to
/// sync until then.
class HeldSale {
  final String id;
  final DateTime heldAt;
  final String label;
  final List<CartItem> items;
  final String customerName;
  final String customerPhone;
  final String customerMode;
  final String payType;

  const HeldSale({
    required this.id,
    required this.heldAt,
    required this.label,
    required this.items,
    required this.customerName,
    required this.customerPhone,
    required this.customerMode,
    required this.payType,
  });

  double get total => items.fold(0.0, (s, i) => s + i.subtotal);
  int get count => items.fold(0, (s, i) => s + i.qty);

  Map<String, dynamic> toJson() => {
        'id': id,
        'heldAt': heldAt.toIso8601String(),
        'label': label,
        'items': items.map((e) => e.toJson()).toList(),
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerMode': customerMode,
        'payType': payType,
      };

  factory HeldSale.fromJson(Map<String, dynamic> json) => HeldSale(
        id: '${json['id']}',
        heldAt: DateTime.tryParse('${json['heldAt']}') ?? DateTime.now(),
        label: '${json['label'] ?? ''}',
        items: ((json['items'] as List?) ?? [])
            .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        customerName: '${json['customerName'] ?? ''}',
        customerPhone: '${json['customerPhone'] ?? ''}',
        customerMode: '${json['customerMode'] ?? 'walkin'}',
        payType: '${json['payType'] ?? 'cash'}',
      );
}

class HeldSalesProvider extends ChangeNotifier {
  static const _uuid = Uuid();
  final _db = LocalDb.instance;

  int? _businessId;
  List<HeldSale> _items = [];
  List<HeldSale> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get count => _items.length;

  Future<void> load(int businessId) async {
    if (_businessId == businessId) return; // already loaded for this business
    _businessId = businessId;
    try {
      final raw = await _db.getCache('held_sales:$businessId');
      _items = ((raw as List?) ?? [])
          .map((e) => HeldSale.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      _items = [];
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    if (_businessId == null) return;
    await _db.putCache('held_sales:$_businessId', _items.map((e) => e.toJson()).toList());
  }

  Future<void> hold({
    required String label,
    required List<CartItem> items,
    String customerName = '',
    String customerPhone = '',
    String customerMode = 'walkin',
    String payType = 'cash',
  }) async {
    _items.insert(
      0,
      HeldSale(
        id: _uuid.v4(),
        heldAt: DateTime.now(),
        label: label,
        items: items,
        customerName: customerName,
        customerPhone: customerPhone,
        customerMode: customerMode,
        payType: payType,
      ),
    );
    notifyListeners();
    await _persist();
  }

  /// Removes and returns the held sale for resuming, or null if not found.
  Future<HeldSale?> take(String id) async {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0) return null;
    final h = _items.removeAt(idx);
    notifyListeners();
    await _persist();
    return h;
  }

  Future<void> discard(String id) async {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
    await _persist();
  }
}
