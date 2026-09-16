class Supplier {
  final int supplierId;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String notes;
  final bool isActive;
  final int batchesCount;
  final double totalSpent;
  final String? lastPurchaseAt;

  const Supplier({
    required this.supplierId,
    required this.name,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.notes = '',
    this.isActive = true,
    this.batchesCount = 0,
    this.totalSpent = 0,
    this.lastPurchaseAt,
  });

  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
        supplierId: int.tryParse('${j['supplier_id'] ?? 0}') ?? 0,
        name: '${j['name'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        email: '${j['email'] ?? ''}',
        address: '${j['address'] ?? ''}',
        notes: '${j['notes'] ?? ''}',
        isActive: '${j['is_active'] ?? 1}' == '1',
        batchesCount: int.tryParse('${j['batches_count'] ?? 0}') ?? 0,
        totalSpent: double.tryParse('${j['total_spent'] ?? 0}') ?? 0,
        lastPurchaseAt: j['last_purchase_at'] as String?,
      );
}
