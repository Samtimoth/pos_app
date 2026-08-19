/// A single selling unit for a product.
/// e.g. Pepsi → Bottle (×1, TZS 1,000), Half Dozen (×6, TZS 5,800), Crate (×24, TZS 22,000)
class ProductUnit {
  final int    unitId;
  final int    productId;
  final String unitName;
  final double conversionQty;  // how many BASE units = 1 of this selling unit
  final double sellingPrice;   // price for ONE of this selling unit

  const ProductUnit({
    required this.unitId,
    required this.productId,
    required this.unitName,
    required this.conversionQty,
    required this.sellingPrice,
  });

  factory ProductUnit.fromJson(Map<String, dynamic> json) => ProductUnit(
    unitId:        int.tryParse('${json['unit_id']        ?? 0}') ?? 0,
    productId:     int.tryParse('${json['product_id']     ?? 0}') ?? 0,
    unitName:      (json['unit_name']  ?? '').toString().trim(),
    conversionQty: double.tryParse('${json['conversion_qty'] ?? 1}') ?? 1.0,
    sellingPrice:  double.tryParse('${json['selling_price']  ?? 0}') ?? 0.0,
  );

  Map<String, dynamic> toSaveJson() => {
    'unit_name':      unitName,
    'conversion_qty': conversionQty,
    'selling_price':  sellingPrice,
  };

  /// Max qty of this unit that can be sold given [stockInBaseUnits]
  int maxQty(int stockInBaseUnits) =>
      conversionQty > 0 ? (stockInBaseUnits / conversionQty).floor() : stockInBaseUnits;

  /// Human-readable conversion label, e.g. "= 12 Bottles"
  String conversionLabel(String baseUnit) {
    if (conversionQty == 1) return '1 $baseUnit';
    final qty = conversionQty == conversionQty.truncateToDouble()
        ? conversionQty.toInt().toString()
        : conversionQty.toStringAsFixed(2);
    return '$qty ${baseUnit}s';
  }
}
