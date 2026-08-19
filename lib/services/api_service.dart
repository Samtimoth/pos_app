import 'dart:convert';
import 'package:http/http.dart' as http;
import 'device_id_service.dart';

class ApiService {
  final String baseUrl; // e.g. http://192.168.1.100/pos/api

  ApiService(this.baseUrl);

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  // ── Auth ──────────────────────────────────────────────
  Future<Map<String, dynamic>> register({
    required String fullname,
    required String username,
    required String email,
    required String phone,
    required String password,
    required String businessName,
    required String tradeName,
    required String businessPhone,
    required String address,
    required String country,
    required String currency,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/register.php'),
          headers: _headers,
          body: jsonEncode({
            'fullname':       fullname,
            'username':       username,
            'email':          email,
            'phone':          phone,
            'password':       password,
            'business_name':  businessName,
            'trade_name':     tradeName,
            'business_phone': businessPhone,
            'address':        address,
            'country':        country,
            'currency':       currency,
          }),
        )
        .timeout(const Duration(seconds: 20));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final deviceId = await DeviceIdService.getDeviceId();
    final res = await http
        .post(
          Uri.parse('$baseUrl/login.php'),
          headers: _headers,
          body: jsonEncode({
            'username': username,
            'password': password,
            'device_id': deviceId,
            'device_name': DeviceIdService.getDeviceName(),
          }),
        )
        .timeout(const Duration(seconds: 15));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── My Businesses ─────────────────────────────────────
  Future<Map<String, dynamic>> getMyBusinesses(int userId) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/my_businesses.php'),
          headers: _headers,
          body: jsonEncode({'user_id': userId}),
        )
        .timeout(const Duration(seconds: 15));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Dashboard ─────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboard(int businessId, {int? branchId, String? dateFrom, String? dateTo}) async {
    final params = <String, String>{'business_id': businessId.toString()};
    if (branchId != null) params['branch_id'] = branchId.toString();
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    final uri = Uri.parse('$baseUrl/dashboard.php').replace(queryParameters: params);
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Products ──────────────────────────────────────────
  Future<List<dynamic>> getProducts(int businessId, {int? branchId, String search = '', String? category}) async {
    final params = {'business_id': businessId.toString()};
    if (branchId != null) params['branch_id'] = branchId.toString();
    if (search.isNotEmpty) params['search'] = search;
    if (category != null && category.isNotEmpty) params['category'] = category;
    final uri = Uri.parse('$baseUrl/get_products.php').replace(queryParameters: params);
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] == true) return body['products'] as List;
    throw Exception(body['message'] ?? 'Imeshindwa kupata bidhaa');
  }

  // ── Categories ────────────────────────────────────────
  Future<List<dynamic>> getCategories(int businessId) async {
    final uri = Uri.parse('$baseUrl/get_categories.php')
        .replace(queryParameters: {'business_id': businessId.toString()});
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] == true) return body['categories'] as List;
    return [];
  }

  // ── Sales ─────────────────────────────────────────────
  Future<List<dynamic>> getSales(int businessId,
      {int? branchId, String? dateFrom, String? dateTo, String? status}) async {
    final params = {'business_id': businessId.toString()};
    if (branchId != null) params['branch_id'] = branchId.toString();
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    if (status != null) params['status'] = status;
    final uri = Uri.parse('$baseUrl/get_sales.php').replace(queryParameters: params);
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] == true) return body['sales'] as List;
    return [];
  }

  // ── Create Sale ───────────────────────────────────────
  Future<Map<String, dynamic>> createSale({
    required int businessId,
    required int branchId,
    required String customerName,
    required String transactionType, // cash | loan | slow_payment
    required List<Map<String, dynamic>> items,
    double? amountPaid,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/create_sale.php'),
          headers: _headers,
          body: jsonEncode({
            'business_id': businessId,
            'branch_id': branchId,
            'customer_name': customerName,
            'customer_type': 'normal',
            'transaction_type': transactionType,
            'items': items,
            'amount_paid': amountPaid,
          }),
        )
        .timeout(const Duration(seconds: 30));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Add single product (multipart) ───────────────────────
  Future<Map<String, dynamic>> addProduct({
    required int    businessId,
    required int    branchId,
    required String name,
    required String category,
    required String unit,
    required double buyPrice,
    required double sellPrice,
    required int    stock,
    int    minStock       = 5,
    String barcode        = '',
    String description    = '',
    String productCode    = '',
    double? wholesalePrice,
    String expiryDate     = '',
    String? imagePath,
  }) async {
    final req = http.MultipartRequest(
      'POST', Uri.parse('$baseUrl/add_product.php'));
    req.fields.addAll({
      'business_id':      businessId.toString(),
      'branch_id':        branchId.toString(),
      'product_name':     name,
      'product_category': category,
      'product_satuan':   unit,
      'purchase_price':   buyPrice.toString(),
      'sell_price':       sellPrice.toString(),
      'stock':            stock.toString(),
      'min_stock':        minStock.toString(),
      'barcode':          barcode,
      'description':      description,
      'product_code':     productCode,
    });
    if (wholesalePrice != null) {
      req.fields['wholesale_price'] = wholesalePrice.toString();
    }
    if (expiryDate.isNotEmpty) {
      req.fields['expiry_date'] = expiryDate;
    }
    if (imagePath != null && imagePath.isNotEmpty) {
      req.files.add(await http.MultipartFile.fromPath('image', imagePath));
    }
    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final res      = await http.Response.fromStream(streamed);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Update product (multipart) ────────────────────────────────────────────────
  Future<Map<String, dynamic>> updateProduct({
    required int    productId,
    required int    businessId,
    required int    branchId,
    required String name,
    required String category,
    required String unit,
    required double buyPrice,
    required double sellPrice,
    required int    stock,
    int    minStock       = 5,
    String barcode        = '',
    String description    = '',
    String productCode    = '',
    double? wholesalePrice,
    String expiryDate     = '',
    String? imagePath,
  }) async {
    final req = http.MultipartRequest(
      'POST', Uri.parse('$baseUrl/update_product.php'));
    req.fields.addAll({
      'product_id':       productId.toString(),
      'business_id':      businessId.toString(),
      'branch_id':        branchId.toString(),
      'product_name':     name,
      'product_category': category,
      'product_satuan':   unit,
      'purchase_price':   buyPrice.toString(),
      'sell_price':       sellPrice.toString(),
      'stock':            stock.toString(),
      'min_stock':        minStock.toString(),
      'barcode':          barcode,
      'description':      description,
      'product_code':     productCode,
    });
    if (wholesalePrice != null) {
      req.fields['wholesale_price'] = wholesalePrice.toString();
    }
    if (expiryDate.isNotEmpty) {
      req.fields['expiry_date'] = expiryDate;
    }
    if (imagePath != null && imagePath.isNotEmpty) {
      req.files.add(await http.MultipartFile.fromPath('image', imagePath));
    }
    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final res      = await http.Response.fromStream(streamed);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Product Batch ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> addProductBatch({
    required int    productId,
    required int    businessId,
    required int    quantity,
    required double buyPrice,
    String batchNumber = '',
    String expiryDate  = '',
    String notes       = '',
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/add_product_batch.php'),
          headers: _headers,
          body: jsonEncode({
            'product_id':   productId,
            'business_id':  businessId,
            'quantity':     quantity,
            'buy_price':    buyPrice,
            'batch_number': batchNumber,
            'expiry_date':  expiryDate,
            'notes':        notes,
          }),
        )
        .timeout(const Duration(seconds: 20));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getProductBatches(int productId, int businessId) async {
    try {
      final uri = Uri.parse('$baseUrl/get_product_batches.php').replace(
        queryParameters: {
          'product_id':  productId.toString(),
          'business_id': businessId.toString(),
        },
      );
      final res  = await http.get(uri).timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] == true) return body['batches'] as List? ?? [];
    } catch (_) {}
    return [];
  }

  // ── Product Units ────────────────────────────────────────────────────────────
  /// Replace ALL selling units for a product with [units] list.
  /// units = [{unit_name, conversion_qty, selling_price}, ...]
  Future<Map<String, dynamic>> manageProductUnits({
    required int    productId,
    required int    businessId,
    required List<Map<String, dynamic>> units,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/manage_product_units.php'),
          headers: _headers,
          body: jsonEncode({
            'action':      'save_all',
            'product_id':  productId,
            'business_id': businessId,
            'units':       units,
          }),
        )
        .timeout(const Duration(seconds: 20));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Delete product ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> deleteProduct({
    required int productId,
    required int businessId,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/delete_product.php'),
          headers: _headers,
          body: jsonEncode({
            'product_id':  productId,
            'business_id': businessId,
          }),
        )
        .timeout(const Duration(seconds: 15));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Bulk import products (JSON) ───────────────────────────
  Future<Map<String, dynamic>> importProductsBulk({
    required int    businessId,
    required int    branchId,
    required List<Map<String, dynamic>> products,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/import_products.php'),
      headers: _headers,
      body: jsonEncode({
        'business_id': businessId,
        'branch_id':   branchId,
        'products':    products,
      }),
    ).timeout(const Duration(seconds: 60));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Units ─────────────────────────────────────────────────
  Future<List<String>> getUnits(int businessId) async {
    final uri = Uri.parse('$baseUrl/get_units.php')
        .replace(queryParameters: {'business_id': businessId.toString()});
    final res  = await http.get(uri).timeout(const Duration(seconds: 10));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] == true) {
      return (body['units'] as List)
          .map((u) => (u['name'] as String? ?? '').trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  // ── Sale Actions ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> saleAction(
    int saleId,
    String action, {
    double? amount,
  }) async {
    final body = <String, dynamic>{'sale_id': saleId, 'action': action};
    if (amount != null) body['amount'] = amount;
    final res = await http
        .post(Uri.parse('$baseUrl/sale_action.php'),
            headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Sale Detail (items) ───────────────────────────────────────────
  Future<Map<String, dynamic>> getSaleDetail(int saleId) async {
    final uri = Uri.parse('$baseUrl/get_sale_detail.php')
        .replace(queryParameters: {'sale_id': saleId.toString()});
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Category CRUD ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> manageCategory(int businessId, String action,
      {int? id, String? name}) async {
    final body = <String, dynamic>{
      'business_id': businessId,
      'action': action,
      'id': id,
      'name': name,
    }..removeWhere((_, v) => v == null);
    final res = await http
        .post(Uri.parse('$baseUrl/manage_categories.php'),
            headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> listCategories(int businessId) async {
    final uri = Uri.parse('$baseUrl/manage_categories.php').replace(
        queryParameters: {'action': 'list', 'business_id': businessId.toString()});
    final res  = await http.get(uri).timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] == true) return body['categories'] as List;
    return [];
  }

  // ── Unit CRUD ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> manageUnit(int businessId, String action,
      {int? id, String? name, String? shortName}) async {
    final body = <String, dynamic>{
      'business_id': businessId,
      'action': action,
      'id': id,
      'name': name,
      'short_name': shortName,
    }..removeWhere((_, v) => v == null);
    final res = await http
        .post(Uri.parse('$baseUrl/manage_units.php'),
            headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> listUnits(int businessId) async {
    final uri = Uri.parse('$baseUrl/manage_units.php').replace(
        queryParameters: {'action': 'list', 'business_id': businessId.toString()});
    final res  = await http.get(uri).timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] == true) return body['units'] as List;
    return [];
  }

  // ── Sale Payments history ─────────────────────────────────────────────────
  /// Returns a list of payment events for a sale.
  /// Falls back to empty list if the endpoint doesn't exist yet (graceful).
  Future<List<dynamic>> getSalePayments(int saleId) async {
    try {
      final uri = Uri.parse('$baseUrl/get_sale_payments.php')
          .replace(queryParameters: {'sale_id': saleId.toString()});
      final res  = await http.get(uri).timeout(const Duration(seconds: 10));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] == true) return body['payments'] as List? ?? [];
    } catch (_) {}
    return [];
  }

  // ── Staff / Workers ────────────────────────────────────
  Future<Map<String, dynamic>> manageStaff({
    required int businessId,
    required String action,
    int? requesterUserId,
    int? userId,
    String? fullname,
    String? username,
    String? password,
    String? role,
    int? branchId,
  }) async {
    final body = <String, dynamic>{
      'business_id':        businessId,
      'action':             action,
      'requester_user_id':  requesterUserId,
      'user_id':            userId,
      'fullname':           fullname,
      'username':           username,
      'password':           password,
      'role':               role,
      'branch_id':          branchId,
    }..removeWhere((_, v) => v == null);
    final res = await http
        .post(Uri.parse('$baseUrl/manage_staff.php'),
            headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── My Subscription (owner-scoped overview) ────────────
  Future<Map<String, dynamic>> getMySubscription(int userId) async {
    final uri = Uri.parse('$baseUrl/get_my_subscription.php')
        .replace(queryParameters: {'user_id': userId.toString()});
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Plans ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPlans() async {
    final res = await http.get(Uri.parse('$baseUrl/get_plans.php'))
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] == true) {
      return (body['plans'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  // ── Payments (submit + superadmin review) ──────────────
  Future<Map<String, dynamic>> submitPayment({
    required int userId,
    required int businessId,
    required int planId,
    required String refCode,
    String notes = '',
    String? proofPath,
  }) async {
    final req = http.MultipartRequest(
        'POST', Uri.parse('$baseUrl/submit_payment.php'));
    req.fields.addAll({
      'user_id':     userId.toString(),
      'business_id': businessId.toString(),
      'plan_id':     planId.toString(),
      'ref_code':    refCode,
      'notes':       notes,
    });
    if (proofPath != null && proofPath.isNotEmpty) {
      req.files.add(await http.MultipartFile.fromPath('proof', proofPath));
    }
    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final res      = await http.Response.fromStream(streamed);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMyPayments(int userId) async {
    final uri = Uri.parse('$baseUrl/get_my_payments.php')
        .replace(queryParameters: {'user_id': userId.toString()});
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSuperAdminPayments({
    required int requesterUserId,
    String status = '',
  }) async {
    final uri = Uri.parse('$baseUrl/superadmin_payments.php').replace(
      queryParameters: {
        'requester_user_id': requesterUserId.toString(),
        'action': 'list',
        if (status.isNotEmpty) 'status': status,
      },
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> reviewPayment({
    required int requesterUserId,
    required int paymentId,
    required String action,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/superadmin_payments.php'),
          headers: _headers,
          body: jsonEncode({
            'requester_user_id': requesterUserId,
            'action':            action,
            'payment_id':        paymentId,
          }),
        )
        .timeout(const Duration(seconds: 20));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Super Admin: Dashboard Stats ───────────────────────
  Future<Map<String, dynamic>> getSuperAdminStats(int requesterUserId) async {
    final uri = Uri.parse('$baseUrl/superadmin_stats.php')
        .replace(queryParameters: {'requester_user_id': requesterUserId.toString()});
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Super Admin: Subscriptions ────────────────────────
  Future<Map<String, dynamic>> getSuperAdminBusinesses({
    required int requesterUserId,
    String q = '',
  }) async {
    final uri = Uri.parse('$baseUrl/superadmin_businesses.php').replace(
      queryParameters: {
        'requester_user_id': requesterUserId.toString(),
        if (q.isNotEmpty) 'q': q,
      },
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> manageSubscription({
    required int requesterUserId,
    required int businessId,
    required String action,
    int? planId,
    int? days,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/superadmin_subscription.php'),
          headers: _headers,
          body: jsonEncode({
            'requester_user_id': requesterUserId,
            'business_id':       businessId,
            'action':            action,
            'plan_id':           planId,
            'days':              days,
          }),
        )
        .timeout(const Duration(seconds: 20));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Add Business ───────────────────────────────────────
  Future<Map<String, dynamic>> createBusiness({
    required int userId,
    required String businessName,
    String country = '',
    String address = '',
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/business/create_business.php'),
          headers: _headers,
          body: jsonEncode({
            'user_id':       userId,
            'business_name': businessName,
            'country':       country,
            'address':       address,
          }),
        )
        .timeout(const Duration(seconds: 20));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Business Edit ─────────────────────────────────────
  Future<Map<String, dynamic>> updateBusiness({
    required int userId,
    required int businessId,
    required String businessName,
    required String tradeName,
    required String phone,
    required String address,
    required String country,
    required String currency,
    String receiptHeader = '',
    String receiptFooter = '',
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/update_business.php'),
          headers: _headers,
          body: jsonEncode({
            'user_id':        userId,
            'business_id':    businessId,
            'business_name':  businessName,
            'trade_name':     tradeName,
            'phone':          phone,
            'address':        address,
            'country':        country,
            'currency':       currency,
            'receipt_header': receiptHeader,
            'receipt_footer': receiptFooter,
          }),
        )
        .timeout(const Duration(seconds: 20));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Profile ───────────────────────────────────────────
  Future<Map<String, dynamic>> getProfile(int userId) async {
    final uri = Uri.parse('$baseUrl/get_profile.php')
        .replace(queryParameters: {'user_id': userId.toString()});
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile({
    required int userId,
    required String fullname,
    required String email,
    String currentPassword = '',
    String newPassword = '',
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/update_profile.php'),
          headers: _headers,
          body: jsonEncode({
            'user_id':          userId,
            'fullname':         fullname,
            'email':            email,
            'current_password': currentPassword,
            'new_password':     newPassword,
          }),
        )
        .timeout(const Duration(seconds: 20));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Chart Data ────────────────────────────────────────
  Future<Map<String, dynamic>> getChartData(int businessId, {int? branchId, String? period}) async {
    final params = {'business_id': businessId.toString()};
    if (branchId != null) params['branch_id'] = branchId.toString();
    if (period != null) params['period'] = period;
    final uri = Uri.parse('$baseUrl/chart_data.php').replace(queryParameters: params);
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
