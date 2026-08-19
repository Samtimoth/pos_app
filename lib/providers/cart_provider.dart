import 'package:flutter/material.dart';
import '../models/product.dart'; // exports ProductUnit
import '../models/sale.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  int    get count   => _items.fold(0, (s, i) => s + i.qty);
  bool   get isEmpty => _items.isEmpty;
  double get total   => _items.fold(0.0, (s, i) => s + i.subtotal);

  // ── Add with BASE unit (backwards compatible) ─────────────────────────────
  void addProduct(Product p) {
    _addItem(
      cartKey:       '${p.productId}-0',
      productId:     p.productId,
      productName:   p.name,
      unitPrice:     p.sellPrice,
      maxStock:      p.stock,
      unitId:        0,
      unitName:      '',
      conversionQty: 1.0,
    );
  }

  // ── Add with a specific selling unit ─────────────────────────────────────
  void addProductWithUnit(Product p, ProductUnit unit) {
    final maxQty = unit.maxQty(p.stock);
    if (maxQty <= 0) return;
    _addItem(
      cartKey:       '${p.productId}-${unit.unitId}',
      productId:     p.productId,
      productName:   p.name,
      unitPrice:     unit.sellingPrice,
      maxStock:      maxQty,
      unitId:        unit.unitId,
      unitName:      unit.unitName,
      conversionQty: unit.conversionQty,
    );
  }

  void _addItem({
    required String cartKey,
    required int    productId,
    required String productName,
    required double unitPrice,
    required int    maxStock,
    required int    unitId,
    required String unitName,
    required double conversionQty,
  }) {
    final idx = _items.indexWhere((i) => i.cartKey == cartKey);
    if (idx >= 0) {
      if (_items[idx].qty < maxStock) {
        _items[idx].qty++;
        notifyListeners();
      }
    } else {
      if (maxStock > 0) {
        _items.add(CartItem(
          cartKey:       cartKey,
          productId:     productId,
          productName:   productName,
          qty:           1,
          unitPrice:     unitPrice,
          maxStock:      maxStock,
          unitId:        unitId,
          unitName:      unitName,
          conversionQty: conversionQty,
        ));
        notifyListeners();
      }
    }
  }

  // ── Qty controls (keyed by cartKey) ───────────────────────────────────────
  void increaseQty(String cartKey) {
    final idx = _items.indexWhere((i) => i.cartKey == cartKey);
    if (idx >= 0 && _items[idx].qty < _items[idx].maxStock) {
      _items[idx].qty++;
      notifyListeners();
    }
  }

  void decreaseQty(String cartKey) {
    final idx = _items.indexWhere((i) => i.cartKey == cartKey);
    if (idx >= 0) {
      if (_items[idx].qty <= 1) {
        _items.removeAt(idx);
      } else {
        _items[idx].qty--;
      }
      notifyListeners();
    }
  }

  void removeItem(String cartKey) {
    _items.removeWhere((i) => i.cartKey == cartKey);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  // ── Serialize for API ────────────────────────────────────────────────────
  List<Map<String, dynamic>> toApiItems() => _items.map((i) => {
    'product_id':     i.productId,
    'qty':            i.qty,
    'unit_price':     i.unitPrice,
    'unit_name':      i.unitName,
    'conversion_qty': i.conversionQty,
    'discount_total': 0,
  }).toList();
}
