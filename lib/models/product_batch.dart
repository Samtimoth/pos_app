class ProductBatch {
  final int     batchId;
  final int     productId;
  final String  batchNumber;
  final int     quantity;   // total units added in this batch
  final int     remaining;  // units still in stock
  final double  buyPrice;   // unit buy price for this batch
  final String  dateAdded;  // ISO "YYYY-MM-DD HH:mm:ss" or "YYYY-MM-DD"
  final String? expiryDate;
  final String  notes;

  const ProductBatch({
    required this.batchId,
    required this.productId,
    required this.batchNumber,
    required this.quantity,
    required this.remaining,
    required this.buyPrice,
    required this.dateAdded,
    this.expiryDate,
    this.notes = '',
  });

  factory ProductBatch.fromJson(Map<String, dynamic> json) => ProductBatch(
        batchId:     (json['batch_id']   as num).toInt(),
        productId:   (json['product_id'] as num).toInt(),
        batchNumber: json['batch_number'] as String? ?? '',
        quantity:    (json['quantity']   as num).toInt(),
        remaining:   (json['remaining']  as num?)?.toInt() ??
                     (json['quantity']   as num).toInt(),
        buyPrice:    (json['buy_price']  as num).toDouble(),
        dateAdded:   json['date_added']  as String? ?? '',
        expiryDate:  json['expiry_date'] as String?,
        notes:       json['notes']       as String? ?? '',
      );

  int  get soldQty    => quantity - remaining;
  bool get isExhausted => remaining <= 0;
  bool get isActive    => remaining > 0;

  double profitPerUnit(double sellPrice) => sellPrice - buyPrice;
  double totalProfit(double sellPrice)   => profitPerUnit(sellPrice) * soldQty;

  String get displayDate {
    if (dateAdded.isEmpty) return '';
    try {
      final d = DateTime.parse(dateAdded);
      return '${d.day.toString().padLeft(2,'0')}/'
             '${d.month.toString().padLeft(2,'0')}/'
             '${d.year}';
    } catch (_) {
      return dateAdded;
    }
  }
}
