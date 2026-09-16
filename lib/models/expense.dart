/// One business expense (matumizi): rent, electricity, salaries…
class Expense {
  final int expenseId; // negative = created offline, not yet synced
  final int businessId;
  final int? branchId;
  final String category;
  final String description;
  final double amount;
  final String expenseDate; // YYYY-MM-DD
  final String createdAt;
  final String syncStatus; // synced | pending | failed

  const Expense({
    required this.expenseId,
    required this.businessId,
    required this.branchId,
    required this.category,
    required this.description,
    required this.amount,
    required this.expenseDate,
    required this.createdAt,
    this.syncStatus = 'synced',
  });

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        expenseId: int.tryParse('${j['expense_id']}') ?? 0,
        businessId: int.tryParse('${j['business_id'] ?? 0}') ?? 0,
        branchId: j['branch_id'] == null ? null : int.tryParse('${j['branch_id']}'),
        category: (j['category'] ?? 'Nyingine').toString(),
        description: (j['description'] ?? '').toString(),
        amount: double.tryParse('${j['amount'] ?? 0}') ?? 0,
        expenseDate: (j['expense_date'] ?? '').toString().substring(0, 10),
        createdAt: (j['created_at'] ?? '').toString(),
        syncStatus: (j['sync_status'] ?? 'synced').toString(),
      );

  Map<String, dynamic> toJson() => {
        'expense_id': expenseId,
        'business_id': businessId,
        'branch_id': branchId,
        'category': category,
        'description': description,
        'amount': amount,
        'expense_date': expenseDate,
        'created_at': createdAt,
        'sync_status': syncStatus,
      };

  bool get isSynced => syncStatus == 'synced';

  /// Common expense categories (Swahili first — the app's main audience).
  static const categories = [
    'Kodi ya duka', 'Umeme', 'Maji', 'Mishahara', 'Usafiri', 'Mawasiliano',
    'Ununuzi wa vifaa', 'Ukarabati', 'Kodi (TRA)', 'Nyingine',
  ];
}
