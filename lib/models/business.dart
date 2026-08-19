class Branch {
  final int branchId;
  final String branchName;
  final String branchCode;
  final String phone;
  final String address;
  final bool isActive;

  const Branch({
    required this.branchId,
    required this.branchName,
    required this.branchCode,
    required this.phone,
    required this.address,
    required this.isActive,
  });

  factory Branch.fromJson(Map<String, dynamic> j) => Branch(
        branchId:   int.parse((j['branch_id'] ?? 0).toString()),
        branchName: j['branch_name'] as String? ?? '',
        branchCode: j['branch_code'] as String? ?? '',
        phone:      j['phone'] as String? ?? '',
        address:    j['address'] as String? ?? '',
        isActive:   (j['is_active'] ?? 1).toString() == '1',
      );
}

class Business {
  final int businessId;
  final String businessName;
  final String tradeName;
  final String receiptHeader;
  final String receiptFooter;
  final String role;
  final String country;
  final String currency;
  final String phone;
  final String timezone;
  final String address;
  final String logoPath;
  final String shopCode;
  final bool isActive;
  final int branchCount;
  final int? defaultBranchId;
  final List<Branch> branches;
  final String subscriptionStatus;
  final String? subscriptionEnd;
  final bool subscriptionActive;
  final int subscriptionDaysLeft;
  final String? planName;

  const Business({
    required this.businessId,
    required this.businessName,
    required this.tradeName,
    this.receiptHeader = '',
    this.receiptFooter = '',
    required this.role,
    required this.country,
    required this.currency,
    required this.phone,
    required this.timezone,
    required this.address,
    required this.logoPath,
    required this.shopCode,
    required this.isActive,
    required this.branchCount,
    this.defaultBranchId,
    required this.branches,
    this.subscriptionStatus = 'none',
    this.subscriptionEnd,
    this.subscriptionActive = true,
    this.subscriptionDaysLeft = 0,
    this.planName,
  });

  factory Business.fromJson(Map<String, dynamic> j) => Business(
        businessId:      int.parse((j['business_id'] ?? 0).toString()),
        businessName:    j['business_name'] as String? ?? '',
        tradeName:       j['trade_name'] as String? ?? '',
        receiptHeader:   j['receipt_header'] as String? ?? '',
        receiptFooter:   j['receipt_footer'] as String? ?? '',
        role:            j['role'] as String? ?? 'Viewer',
        country:         j['country'] as String? ?? 'TZ',
        currency:        j['currency'] as String? ?? 'TZS',
        phone:           j['phone'] as String? ?? '',
        timezone:        j['timezone'] as String? ?? 'Africa/Dar_es_Salaam',
        address:         j['address'] as String? ?? '',
        logoPath:        j['logo_path'] as String? ?? '',
        shopCode:        j['shop_code'] as String? ?? '',
        isActive:        j['is_active'] as bool? ?? true,
        branchCount:     int.parse((j['branch_count'] ?? 0).toString()),
        defaultBranchId: j['default_branch_id'] != null
            ? int.tryParse(j['default_branch_id'].toString())
            : null,
        branches: (j['branches'] as List<dynamic>? ?? [])
            .map((b) => Branch.fromJson(b as Map<String, dynamic>))
            .toList(),
        subscriptionStatus:   j['subscription_status'] as String? ?? 'none',
        subscriptionEnd:      j['subscription_end'] as String?,
        subscriptionActive:   j['subscription_active'] as bool? ?? true,
        subscriptionDaysLeft: int.tryParse((j['subscription_days_left'] ?? 0).toString()) ?? 0,
        planName:             j['plan_name'] as String?,
      );

  /// Icon for role
  static String roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'owner':   return '👑';
      case 'admin':   return '🔧';
      case 'manager': return '📊';
      case 'cashier': return '💰';
      case 'stockist':return '📦';
      default:        return '👤';
    }
  }
}
