/// A customer of the business (mteja). Balance = sum of unpaid sale balances.
class Customer {
  final int customerId; // negative = created offline, not yet synced
  final String name;
  final String phone;
  final String email;
  final String address;
  final String customerType; // retail | wholesale | vip
  final double creditLimit;
  final String notes;
  final int salesCount;
  final double totalBought;
  final double balance;
  final String lastSaleAt;
  final String syncStatus;

  const Customer({
    required this.customerId,
    required this.name,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.customerType = 'retail',
    this.creditLimit = 0,
    this.notes = '',
    this.salesCount = 0,
    this.totalBought = 0,
    this.balance = 0,
    this.lastSaleAt = '',
    this.syncStatus = 'synced',
  });

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        customerId: int.tryParse('${j['customer_id']}') ?? 0,
        name: (j['name'] ?? j['full_name'] ?? '').toString(),
        phone: (j['phone'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        address: (j['address'] ?? j['location_text'] ?? '').toString(),
        customerType: (j['customer_type'] ?? 'retail').toString(),
        creditLimit: double.tryParse('${j['credit_limit'] ?? 0}') ?? 0,
        notes: (j['notes'] ?? '').toString(),
        salesCount: int.tryParse('${j['sales_count'] ?? 0}') ?? 0,
        totalBought: double.tryParse('${j['total_bought'] ?? 0}') ?? 0,
        balance: double.tryParse('${j['balance'] ?? 0}') ?? 0,
        lastSaleAt: (j['last_sale_at'] ?? '').toString(),
        syncStatus: (j['sync_status'] ?? 'synced').toString(),
      );

  Map<String, dynamic> toJson() => {
        'customer_id': customerId,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'customer_type': customerType,
        'credit_limit': creditLimit,
        'notes': notes,
        'sales_count': salesCount,
        'total_bought': totalBought,
        'balance': balance,
        'last_sale_at': lastSaleAt,
        'sync_status': syncStatus,
      };

  bool get hasDebt => balance > 0;
  bool get overLimit => creditLimit > 0 && balance > creditLimit;
  bool get isSynced => syncStatus == 'synced';

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

/// One line of a product's stock card (ledger).
class StockMovement {
  final int movementId;
  final int productId;
  final String productName;
  final String type; // opening|sale|void|batch|adjustment|edit|…
  final double qtyDelta;
  final double stockAfter;
  final double? costPrice;
  final String? refType;
  final int? refId;
  final String reason;
  final String userName;
  final String saleNo;
  final String createdAt;

  const StockMovement({
    required this.movementId,
    required this.productId,
    required this.productName,
    required this.type,
    required this.qtyDelta,
    required this.stockAfter,
    required this.costPrice,
    required this.refType,
    required this.refId,
    required this.reason,
    required this.userName,
    required this.saleNo,
    required this.createdAt,
  });

  factory StockMovement.fromJson(Map<String, dynamic> j) => StockMovement(
        movementId: int.tryParse('${j['movement_id']}') ?? 0,
        productId: int.tryParse('${j['product_id']}') ?? 0,
        productName: (j['product_name'] ?? '').toString(),
        type: (j['movement_type'] ?? '').toString(),
        qtyDelta: double.tryParse('${j['qty_delta'] ?? 0}') ?? 0,
        stockAfter: double.tryParse('${j['stock_after'] ?? 0}') ?? 0,
        costPrice: j['cost_price'] == null ? null : double.tryParse('${j['cost_price']}'),
        refType: j['ref_type']?.toString(),
        refId: j['ref_id'] == null ? null : int.tryParse('${j['ref_id']}'),
        reason: (j['reason'] ?? '').toString(),
        userName: (j['user_name'] ?? '').toString(),
        saleNo: (j['sale_no'] ?? '').toString(),
        createdAt: (j['created_at'] ?? '').toString(),
      );

  bool get isIn => qtyDelta > 0;

  /// Swahili label for the movement type.
  String get typeLabel => switch (type) {
        'opening' => 'Stock ya kwanza',
        'sale' => 'Mauzo',
        'void' => 'Mauzo yamefutwa',
        'batch' => 'Stock imeingia',
        'adjustment' => 'Marekebisho',
        'return' => 'Marejesho',
        'transfer_in' => 'Uhamisho (ndani)',
        'transfer_out' => 'Uhamisho (nje)',
        'edit' => 'Imehaririwa',
        _ => type,
      };

  /// e.g. "[damaged] Ilivunjika" → ("damaged", "Ilivunjika")
  (String, String) get parsedReason {
    final m = RegExp(r'^\[(\w+)\]\s*(.*)$').firstMatch(reason);
    return m == null ? ('', reason) : (m.group(1)!, m.group(2)!);
  }
}

/// Adjustment kinds a user can record from the app.
class StockAdjustType {
  static const all = [
    ('damaged', 'Imeharibika', '−'),
    ('lost', 'Imepotea / wizi', '−'),
    ('expired', 'Imeisha muda', '−'),
    ('return_supplier', 'Imerudishwa kwa muuzaji', '−'),
    ('return_in', 'Mteja amerudisha', '+'),
    ('correction', 'Marekebisho (kosa la kuhesabu)', '±'),
    ('count', 'Hesabu ya stock (stock take)', '='),
  ];
}
