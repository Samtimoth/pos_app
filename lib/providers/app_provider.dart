import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/business.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../l10n/app_l10n.dart';

class AppProvider extends ChangeNotifier {
  User? _user;
  ApiService? _api;
  bool _loading = false;

  // Selected business/branch (set during business-select flow)
  Business? _selectedBusiness;
  Branch? _selectedBranch;
  List<Business> _businesses = [];

  User? get user => _user;
  ApiService? get api => _api;
  Business? get selectedBusiness => _selectedBusiness;
  Branch? get selectedBranch => _selectedBranch;
  List<Business> get businesses => _businesses;
  bool get loading => _loading;

  // ── Language ───────────────────────────────────────────
  AppLang _lang = AppLang.sw;
  AppLang get lang => _lang;
  bool get isSw => _lang == AppLang.sw;

  void toggleLanguage() {
    _lang = _lang == AppLang.sw ? AppLang.en : AppLang.sw;
    L.setLang(_lang);
    StorageService.saveString('app_lang', _lang == AppLang.sw ? 'sw' : 'en');
    notifyListeners();
  }

  /// Fully ready if user + business + branch are all set
  bool get isReady =>
      _user != null && _selectedBusiness != null && _selectedBranch != null;

  /// Logged in (user known) but may still need business selection
  bool get isLoggedIn => _user != null;

  bool get isSuperAdmin => _user?.globalRole.toLowerCase() == 'superadmin';

  // ── Load persisted session ─────────────────────────────
  Future<void> loadSavedUser() async {
    final serverUrl = StorageService.getString('server_url');
    final userId = StorageService.getInt('user_id');
    final username = StorageService.getString('username');
    // Restore language
    final savedLang = StorageService.getString('app_lang');
    _lang = savedLang == 'en' ? AppLang.en : AppLang.sw;
    L.setLang(_lang);

    if (serverUrl == null || userId == null || username == null) return;

    _user = User(
      userId: userId,
      username: username,
      fullname: StorageService.getString('fullname') ?? username,
      globalRole: StorageService.getString('global_role') ?? 'User',
      role: StorageService.getString('role') ?? 'Viewer',
      businessId: StorageService.getInt('business_id'),
      branchId: StorageService.getInt('branch_id'),
      serverUrl: serverUrl,
    );
    _api = ApiService(serverUrl);

    // Restore selected business/branch if saved
    final bizId = StorageService.getInt('selected_business_id');
    final branchId = StorageService.getInt('selected_branch_id');
    if (bizId != null && branchId != null) {
      try {
        final res = await _api!.getMyBusinesses(userId);
        if (res['success'] == true) {
          final list = (res['businesses'] as List)
              .map((b) => Business.fromJson(b as Map<String, dynamic>))
              .toList();
          _businesses = list;
          _selectedBusiness = list.firstWhere(
            (b) => b.businessId == bizId,
            orElse: () => list.first,
          );
          final branches = _selectedBusiness!.branches;
          _selectedBranch = branches.firstWhere(
            (b) => b.branchId == branchId,
            orElse: () => branches.first,
          );
        }
      } catch (_) {
        // Silently fail — splash will redirect to login if needed
      }
    }

    notifyListeners();
  }

  // ── Set user after login ───────────────────────────────
  Future<void> setUser(User user) async {
    _user = user;
    _api = ApiService(user.serverUrl);

    await StorageService.saveString('server_url', user.serverUrl);
    await StorageService.saveInt('user_id', user.userId);
    await StorageService.saveString('username', user.username);
    await StorageService.saveString('fullname', user.fullname);
    await StorageService.saveString('global_role', user.globalRole);
    await StorageService.saveString('role', user.role);
    notifyListeners();
  }

  // ── Load businesses for a user ─────────────────────────
  Future<List<Business>> loadBusinesses() async {
    if (_api == null || _user == null) return [];
    setLoading(true);
    try {
      final res = await _api!.getMyBusinesses(_user!.userId);
      if (res['success'] == true) {
        _businesses = (res['businesses'] as List)
            .map((b) => Business.fromJson(b as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
      return _businesses;
    } finally {
      setLoading(false);
    }
  }

  // ── Select business + branch ───────────────────────────
  Future<void> selectBusinessAndBranch(Business biz, Branch branch) async {
    _selectedBusiness = biz;
    _selectedBranch = branch;

    // Update user role for this business
    _user = _user?.copyWith(
      businessId: biz.businessId,
      branchId: branch.branchId,
      role: biz.role,
    );

    await StorageService.saveInt('selected_business_id', biz.businessId);
    await StorageService.saveInt('selected_branch_id', branch.branchId);
    await StorageService.saveInt('business_id', biz.businessId);
    await StorageService.saveInt('branch_id', branch.branchId);
    await StorageService.saveString('role', biz.role);
    notifyListeners();
  }

  // ── Update local profile fields after edit ─────────────
  void updateUserFullname(String fullname) {
    if (_user == null) return;
    _user = _user!.copyWith(fullname: fullname);
    StorageService.saveString('fullname', fullname);
    notifyListeners();
  }

  // ── Update a business already present in the local list ─
  void updateLocalBusiness(Business updated) {
    final idx = _businesses.indexWhere(
      (b) => b.businessId == updated.businessId,
    );
    if (idx != -1) {
      _businesses[idx] = updated;
    }
    if (_selectedBusiness?.businessId == updated.businessId) {
      _selectedBusiness = updated;
    }
    notifyListeners();
  }

  // ── Logout ────────────────────────────────────────────
  Future<void> logout() async {
    _user = null;
    _api = null;
    _selectedBusiness = null;
    _selectedBranch = null;
    _businesses = [];
    await StorageService.clearSession();
    notifyListeners();
  }

  void setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }
}
