class User {
  final int userId;
  final String username;
  final String fullname;
  final String globalRole;
  final String role;
  final int? businessId;
  final int? branchId;
  final String serverUrl;

  const User({
    required this.userId,
    required this.username,
    required this.fullname,
    required this.globalRole,
    required this.role,
    this.businessId,
    this.branchId,
    required this.serverUrl,
  });

  bool get isSuperAdmin => globalRole.toLowerCase() == 'superadmin';

  // ── Role helpers (Hatua 1) — viwango vya ruhusa kwenye UI ──
  static const _managerPlus = {'owner', 'admin', 'superadmin', 'manager'};

  String get _r => role.toLowerCase();

  /// Kusoma data (mauzo, bidhaa, ripoti)
  bool get canView => true;

  /// Kuuza / kufanya mauzo mapya
  bool get canSell =>
      isSuperAdmin || _managerPlus.contains(_r) || _r == 'cashier' || _r == 'supporter';

  /// Kuongeza/kuhariri bidhaa na stock
  bool get canManageProducts =>
      isSuperAdmin || _managerPlus.contains(_r) || _r == 'stockist';

  /// Kufuta bidhaa
  bool get canDeleteProducts => isSuperAdmin || _r == 'owner' || _r == 'admin';

  /// Kuona bei ya kununua na faida
  bool get canSeeCosts =>
      isSuperAdmin || _managerPlus.contains(_r) || _r == 'accountant';

  /// Kuhariri matumizi (expenses)
  bool get canManageExpenses =>
      isSuperAdmin || _managerPlus.contains(_r) || _r == 'accountant';

  /// Kusimamia wafanyakazi
  bool get canManageStaff => isSuperAdmin || _r == 'owner' || _r == 'admin';

  /// Kuhariri taarifa za biashara
  bool get canEditBusiness => isSuperAdmin || _r == 'owner' || _r == 'admin';

  /// Kuona faida na ripoti za P&L
  bool get canSeeReports =>
      isSuperAdmin || _managerPlus.contains(_r) || _r == 'accountant';

  /// Kuvunja/kufuta mauzo (void) — Manager na wakuu pekee
  bool get canVoidSales => isSuperAdmin || _managerPlus.contains(_r);

  /// Kurudisha bidhaa (return/refund) — routine zaidi kuliko void, cashier anaweza
  bool get canReturnSales =>
      isSuperAdmin || _managerPlus.contains(_r) || _r == 'cashier';

  factory User.fromJson(Map<String, dynamic> json, String serverUrl) => User(
        userId:     int.parse((json['user_id'] ?? 0).toString()),
        username:   json['username']    as String? ?? '',
        fullname:   json['fullname']    as String? ?? json['username'] as String? ?? '',
        globalRole: json['global_role'] as String? ?? 'User',
        role:       json['role']        as String? ?? 'Viewer',
        businessId: json['business_id'] != null
            ? int.tryParse(json['business_id'].toString())
            : null,
        branchId: json['branch_id'] != null
            ? int.tryParse(json['branch_id'].toString())
            : null,
        serverUrl: serverUrl,
      );

  User copyWith({
    int? userId,
    String? username,
    String? fullname,
    String? globalRole,
    String? role,
    int? businessId,
    int? branchId,
    String? serverUrl,
  }) =>
      User(
        userId:     userId     ?? this.userId,
        username:   username   ?? this.username,
        fullname:   fullname   ?? this.fullname,
        globalRole: globalRole ?? this.globalRole,
        role:       role       ?? this.role,
        businessId: businessId ?? this.businessId,
        branchId:   branchId   ?? this.branchId,
        serverUrl:  serverUrl  ?? this.serverUrl,
      );
}
