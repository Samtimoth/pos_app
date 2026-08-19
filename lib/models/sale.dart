class CartItem {
  /// Unique key in cart: "$productId-$unitId"  (unitId=0 → base unit)
  final String cartKey;
  final int    productId;
  final String productName;
  int          qty;
  final double unitPrice;   // selling price for ONE of this unit
  final int    maxStock;    // max qty in SELLING units
  // ── unit info ────────────────────────────────────────────
  final int    unitId;        // 0 = base unit (no specific selling unit)
  final String unitName;      // e.g. "Dozen"  ('' = base unit)
  final double conversionQty; // base units per 1 selling unit (1.0 for base)

  CartItem({
    required this.cartKey,
    required this.productId,
    required this.productName,
    required this.qty,
    required this.unitPrice,
    required this.maxStock,
    this.unitId        = 0,
    this.unitName      = '',
    this.conversionQty = 1.0,
  });

  double get subtotal => qty * unitPrice;

  /// Total base units this cart line represents
  double get totalBaseUnits => qty * conversionQty;

  /// Label shown in cart, e.g. "Pepsi × 2 Dozen" or "Pepsi × 3"
  String get displayLabel =>
      unitName.isNotEmpty ? '$productName ($unitName)' : productName;
}

class Sale {
  final int saleId;
  final String saleNo;
  final String customerName;
  final String customerPhone;
  final double subtotalAmount;
  final double discountAmount;
  final double totalAmount;
  final double paidAmount;
  final double balanceAmount;
  final String saleType;       // cash | loan | partial
  final String paymentStatus;  // paid | unpaid | partial
  final String paymentMethod;
  final String notes;
  final String createdAt;
  final int itemCount;

  const Sale({
    required this.saleId,
    required this.saleNo,
    required this.customerName,
    required this.customerPhone,
    required this.subtotalAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.balanceAmount,
    required this.saleType,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.notes,
    required this.createdAt,
    required this.itemCount,
  });

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
        saleId:         _i(json['sale_id']),
        saleNo:         _s(json['sale_no']),
        customerName:   _s(json['customer_name']),
        customerPhone:  _s(json['customer_phone']),
        subtotalAmount: _d(json['subtotal_amount'] ?? json['subtotal']),
        discountAmount: _d(json['discount_amount']),
        totalAmount:    _d(json['total_amount']    ?? json['subtotal']),
        paidAmount:     _d(json['paid_amount']),
        balanceAmount:  _d(json['balance_amount']  ?? json['due_amount']),
        saleType:       _s(json['sale_type']),
        paymentStatus:  _s(json['payment_status']  ?? json['status']),
        paymentMethod:  _s(json['payment_method']),
        notes:          _s(json['notes']),
        createdAt:      _s(json['created_at']),
        itemCount:      _i(json['item_count']),
      );

  static int    _i(dynamic v) => int.tryParse('$v')    ?? 0;
  static double _d(dynamic v) => double.tryParse('$v') ?? 0.0;
  static String _s(dynamic v) => (v ?? '').toString().trim();

  // ── Payment status helpers ───────────────────────────────────────────
  bool get isPaid    => paymentStatus == 'paid';
  bool get isUnpaid  => paymentStatus == 'unpaid';
  bool get isPartial => paymentStatus == 'partial';
  bool get isPending => paymentStatus == 'pending';
  bool get isVoided  => paymentStatus == 'voided' || saleType == 'voided';
  bool get hasBalance => balanceAmount > 0;

  // ── Sale type helpers ────────────────────────────────────────────────
  bool get isCash             => saleType == 'cash';
  bool get isLoan             => saleType == 'loan';
  bool get isInstallment      => saleType == 'partial';
  bool get isCashNotCollected => saleType == 'cash_not_collected';
  bool get isBankTransfer     => saleType == 'bank_transfer';
}

// ─────────────────────────────────────────────────────────────────────────────
// SalePayment — one payment event for a loan/partial sale
// ─────────────────────────────────────────────────────────────────────────────
class SalePayment {
  final int    id;
  final double amount;
  final String note;
  final String createdAt;

  const SalePayment({
    required this.id,
    required this.amount,
    required this.note,
    required this.createdAt,
  });

  factory SalePayment.fromJson(Map<String, dynamic> json) => SalePayment(
    id:        int.tryParse('${json['id'] ?? json['payment_id']}') ?? 0,
    amount:    double.tryParse('${json['amount'] ?? json['paid_amount'] ?? 0}') ?? 0.0,
    note:      (json['note'] ?? json['notes'] ?? '').toString().trim(),
    createdAt: (json['created_at'] ?? json['payment_date'] ?? '').toString().trim(),
  );
}
