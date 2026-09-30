import 'dart:convert';

/// Sehemu za risiti zinazoonekana/kuficha (Hatua 6: receipt template
/// designer). Default zinalingana na tabia ya risiti KABLA ya feature hii
/// kuwepo (logo/QR/cashier/customer = onyesha, kama zilivyokuwa siku zote),
/// address/phone ni nyongeza mpya, hivyo zimezimwa kwa default ili risiti
/// za wateja wa zamani zisibadilike bila wao kuomba.
class ReceiptTemplate {
  final bool showLogo;
  final bool showQr;
  final bool showCashier;
  final bool showCustomer;
  final bool showAddress;
  final bool showPhone;

  const ReceiptTemplate({
    this.showLogo = true,
    this.showQr = true,
    this.showCashier = true,
    this.showCustomer = true,
    this.showAddress = false,
    this.showPhone = false,
  });

  factory ReceiptTemplate.fromRaw(dynamic raw) {
    if (raw == null) return const ReceiptTemplate();
    Map<String, dynamic>? j;
    if (raw is String && raw.isNotEmpty) {
      try {
        j = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {
        j = null;
      }
    } else if (raw is Map) {
      j = Map<String, dynamic>.from(raw);
    }
    if (j == null) return const ReceiptTemplate();
    return ReceiptTemplate(
      showLogo: j['show_logo'] as bool? ?? true,
      showQr: j['show_qr'] as bool? ?? true,
      showCashier: j['show_cashier'] as bool? ?? true,
      showCustomer: j['show_customer'] as bool? ?? true,
      showAddress: j['show_address'] as bool? ?? false,
      showPhone: j['show_phone'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'show_logo': showLogo,
        'show_qr': showQr,
        'show_cashier': showCashier,
        'show_customer': showCustomer,
        'show_address': showAddress,
        'show_phone': showPhone,
      };

  ReceiptTemplate copyWith({
    bool? showLogo,
    bool? showQr,
    bool? showCashier,
    bool? showCustomer,
    bool? showAddress,
    bool? showPhone,
  }) =>
      ReceiptTemplate(
        showLogo: showLogo ?? this.showLogo,
        showQr: showQr ?? this.showQr,
        showCashier: showCashier ?? this.showCashier,
        showCustomer: showCustomer ?? this.showCustomer,
        showAddress: showAddress ?? this.showAddress,
        showPhone: showPhone ?? this.showPhone,
      );
}

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
  final ReceiptTemplate receiptTemplate;
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
    this.receiptTemplate = const ReceiptTemplate(),
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
        receiptTemplate: ReceiptTemplate.fromRaw(j['receipt_template']),
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
