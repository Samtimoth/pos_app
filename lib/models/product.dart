import 'product_unit.dart';

export 'product_unit.dart';

enum ExpiryStatus { none, ok, expiringSoon, expired }

class Product {
  final int              productId;
  final String           name;
  final String           category;
  final double           sellPrice;   // base sell price (per base unit)
  final double           buyPrice;
  final int              stock;       // quantity in BASE units
  final int              minStock;
  final String           unit;        // base unit name (e.g. "Bottle")
  final String           image;
  final String           barcode;
  final String?          expiryDate;
  final List<ProductUnit> units;      // selling units (may be empty)

  const Product({
    required this.productId,
    required this.name,
    required this.category,
    required this.sellPrice,
    required this.buyPrice,
    required this.stock,
    required this.minStock,
    required this.unit,
    required this.image,
    required this.barcode,
    this.expiryDate,
    this.units = const [],
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawUnits = json['units'];
    final unitList = rawUnits is List
        ? rawUnits
              .whereType<Map<String, dynamic>>()
              .map(ProductUnit.fromJson)
              .toList()
        : <ProductUnit>[];

    return Product(
      productId:  int.tryParse((json['product_id'] ?? 0).toString()) ?? 0,
      name:       json['name']       as String? ?? '',
      category:   json['category']   as String? ?? '',
      sellPrice:  double.tryParse((json['sellPrice'] ?? 0).toString()) ?? 0,
      buyPrice:   double.tryParse((json['buyPrice']  ?? 0).toString()) ?? 0,
      stock:      int.tryParse((json['qty']       ?? 0).toString()) ?? 0,
      minStock:   int.tryParse((json['min_stock'] ?? 5).toString()) ?? 5,
      unit:       json['unit']       as String? ?? '',
      image:      json['image']      as String? ?? '',
      barcode:    json['barcode']    as String? ?? '',
      expiryDate: json['expiry_date'] as String?,
      units:      unitList,
    );
  }

  // ── Expiry helpers ────────────────────────────────────────────────────────
  ExpiryStatus get expiryStatus {
    if (expiryDate == null || expiryDate!.isEmpty) return ExpiryStatus.none;
    final d = DateTime.tryParse(expiryDate!);
    if (d == null) return ExpiryStatus.none;
    final diff = d.difference(DateTime.now()).inDays;
    if (diff < 0)   return ExpiryStatus.expired;
    if (diff <= 30) return ExpiryStatus.expiringSoon;
    return ExpiryStatus.ok;
  }

  String get expiryDisplayDate {
    if (expiryDate == null || expiryDate!.isEmpty) return '';
    final d = DateTime.tryParse(expiryDate!);
    if (d == null) return expiryDate!;
    return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  }

  /// Whether this product has configured selling units beyond the base unit
  bool get hasMultipleUnits => units.isNotEmpty;
}
