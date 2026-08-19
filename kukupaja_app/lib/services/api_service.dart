import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../core/api_config.dart';
import '../models/models.dart';

class ApiService {
  static String get baseUrl => ApiConfig.baseUrl;
  static String get adminUrl => ApiConfig.adminUrl;

  static Future<Session> login(String phone, String password) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': phone, 'password': password}),
        )
        .timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Imeshindikana kuingia');
    }
    final user = data['user'] as Map<String, dynamic>;
    return Session(
      '${data['token']}',
      int.parse('${user['id']}'),
      '${user['name']}',
      '${user['role']}',
    );
  }

  static Future<Map<String, dynamic>> me(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Taarifa hazijapatikana');
    }
    return (data['user'] as Map).cast<String, dynamic>();
  }

  static Future<void> registerDeviceToken(
    String token,
    String deviceToken, {
    String platform = 'android',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register-device-token'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'token': deviceToken, 'platform': platform}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Token haijasajiliwa');
    }
  }

  static Future<Session> register(
    String name,
    String phone,
    String password,
    String location, {
    String role = 'customer',
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name,
            'phone': phone,
            'password': password,
            'location': location,
            'role': role,
          }),
        )
        .timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Usajili umeshindikana');
    }
    final user = data['user'] as Map<String, dynamic>;
    return Session(
      '${data['token']}',
      int.parse('${user['id']}'),
      '${user['name']}',
      '${user['role']}',
    );
  }

  static Future<String> createOrder(
    String token,
    List<Product> products,
    String address,
    String paymentMethod, {
    int? paymentMethodId,
    String? paymentReference,
    String? paymentPayerName,
    String? paymentProofImage,
  }) async {
    final quantities = <int, int>{};
    for (final product in products) {
      quantities.update(product.id, (value) => value + 1, ifAbsent: () => 1);
    }
    final response = await http.post(
      Uri.parse('$baseUrl/orders'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'delivery_address': address,
        'payment_method': paymentMethod,
        'payment_method_id': paymentMethodId,
        'payment_reference': paymentReference,
        'payment_payer_name': paymentPayerName,
        'payment_proof_image': paymentProofImage,
        'items': quantities.entries
            .map((entry) => {'product_id': entry.key, 'quantity': entry.value})
            .toList(),
      }),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Oda imeshindikana');
    }
    return '${data['order_number']}';
  }

  static Future<List<Map<String, dynamic>>> paymentMethods() async {
    final response = await http
        .get(Uri.parse('$baseUrl/payment-methods'))
        .timeout(const Duration(seconds: 6));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Njia za malipo hazijapatikana');
    }
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }

  static Future<String> uploadPaymentProof(
    String token,
    XFile file,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/upload/payment-proof'),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Upakiaji wa picha umeshindikana');
    }
    return '${data['url']}';
  }

  static Future<String> uploadProductImage(String token, XFile file) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/upload/product-image'),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Upakiaji wa picha umeshindikana');
    }
    return '${data['url']}';
  }

  static Future<List<Map<String, dynamic>>> adminPaymentMethods(
    String token,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/payment-methods'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Njia za malipo hazijapatikana');
    }
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }

  static Future<void> addPaymentMethod(
    String token,
    Map<String, dynamic> method,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/payment-methods'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(method),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Imeshindikana kuongeza');
    }
  }

  static Future<void> updatePaymentMethod(
    String token,
    Map<String, dynamic> method,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/payment-methods'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(method),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Imeshindikana kusasisha');
    }
  }

  static Future<List<Map<String, dynamic>>> adminPaymentVerifications(
    String token,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/payment-verifications'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Uthibitisho hazijapatikana');
    }
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }

  static Future<void> verifyPayment(
    String token,
    int orderId,
    String status,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/verify-payment'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'order_id': orderId, 'status': status}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Imeshindikana kusasisha malipo');
    }
  }

  static Future<List<Map<String, dynamic>>> orders(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/orders'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Oda hazijapatikana');
    }
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> adminDashboard(String token) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/admin/dashboard'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Dashboard haijapatikana');
    }
    return (data['data'] as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> orderDetails(
    String token,
    int orderId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/orders/$orderId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Maelezo ya oda hayajapatikana');
    }
    return (data['data'] as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> brokerProducts(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/broker/products'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Stock haijapatikana');
    }
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> brokerDashboard(String token) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/broker/dashboard'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Dashboard haijapatikana');
    }
    return (data['data'] as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> brokerPayouts(String token) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/broker/payouts'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Malipo hayajapatikana');
    }
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }

  static Future<void> submitBrokerProduct(
    String token,
    Map<String, dynamic> product,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/broker/products'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(product),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Listing imeshindikana');
    }
  }

  static Future<void> respondAssignment(
    String token,
    int assignmentId,
    bool accept,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/broker/respond-assignment'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'assignment_id': assignmentId, 'accept': accept}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Jibu halijatumwa');
    }
  }

  static Future<List<Map<String, dynamic>>> messages(String token) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/messages'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Ujumbe haujapatikana');
    }
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }

  static Future<void> sendMessage(String token, String message) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/messages'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'message': message}),
        )
        .timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Ujumbe haujatumwa');
    }
  }

  static Future<List<Product>> products({String category = 'wote'}) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/products?category=$category'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return (body['data'] as List)
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return demoProducts;
  }

  static Future<List<Advertisement>> advertisements() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/ads'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return (body['data'] as List)
            .map((e) => Advertisement.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return const [
      Advertisement(
        id: 0,
        advertiser: 'KukuPaja',
        title: 'Kuku Bora Wamefika!',
        subtitle: 'Nunua kuku wenye afya kwa bei maalum.',
        image: '',
        buttonText: 'Angalia Sasa',
        category: 'wote',
      ),
      Advertisement(
        id: -1,
        advertiser: 'KukuPaja Broiler',
        title: 'Broiler Tayari kwa Oda',
        subtitle: 'Stock mpya kwa migahawa na familia.',
        image: 'https://images.unsplash.com/photo-1569396116180-210c182bedb8',
        buttonText: 'Nunua Sasa',
        category: 'broiler',
      ),
    ];
  }

  static Map<String, String> _authHeaders(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  static Future<List<Map<String, dynamic>>> _adminGet(
    String token,
    String path,
    String errorFallback,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$path'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? errorFallback);
    }
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }

  static Future<void> _adminAction(
    String token,
    String method,
    String path,
    Map<String, dynamic> body,
    String errorFallback, {
    int okStatus = 200,
  }) async {
    final uri = Uri.parse('$baseUrl/$path');
    final response = method == 'POST'
        ? await http.post(uri, headers: _authHeaders(token), body: jsonEncode(body))
        : await http.put(uri, headers: _authHeaders(token), body: jsonEncode(body));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != okStatus || data['success'] != true) {
      throw Exception(data['message'] ?? errorFallback);
    }
  }

  // ---- Admin: order management ----

  static Future<void> assignOrderItem(
    String token,
    int orderItemId, {
    DateTime? deadline,
  }) => _adminAction(
    token,
    'PUT',
    'admin/assign-order-item',
    {
      'order_item_id': orderItemId,
      if (deadline != null) 'deadline': deadline.toIso8601String(),
    },
    'Imeshindikana kutuma kwa broker',
  );

  static Future<void> updateOrderStatus(
    String token,
    int orderId,
    String status,
  ) => _adminAction(
    token,
    'PUT',
    'admin/order-status',
    {'order_id': orderId, 'status': status},
    'Imeshindikana kubadilisha hali ya oda',
  );

  // ---- Admin: product listings ----

  static Future<List<Map<String, dynamic>>> adminProducts(String token) =>
      _adminGet(token, 'admin/products', 'Bidhaa hazijapatikana');

  static Future<void> approveProduct(
    String token,
    int productId,
    num customerPrice,
  ) => _adminAction(
    token,
    'PUT',
    'admin/approve-product',
    {'product_id': productId, 'customer_price': customerPrice},
    'Imeshindikana kuidhinisha',
  );

  static Future<void> rejectProduct(
    String token,
    int productId,
    String reason,
  ) => _adminAction(
    token,
    'PUT',
    'admin/reject-product',
    {'product_id': productId, 'reason': reason},
    'Imeshindikana kukataa',
  );

  static Future<void> expireProduct(String token, int productId) =>
      _adminAction(
        token,
        'PUT',
        'admin/expire-product',
        {'product_id': productId},
        'Imeshindikana kuondoa sokoni',
      );

  // ---- Admin: brokers ----

  static Future<List<Map<String, dynamic>>> adminBrokers(String token) =>
      _adminGet(token, 'admin/brokers', 'Brokers hawajapatikana');

  static Future<List<Map<String, dynamic>>> adminAssignments(String token) =>
      _adminGet(token, 'admin/assignments', 'Majibu ya broker hayajapatikana');

  static Future<void> toggleBrokerVerified(String token, int brokerId) =>
      _adminAction(
        token,
        'PUT',
        'admin/toggle-broker-verified',
        {'broker_id': brokerId},
        'Imeshindikana kubadilisha uthibitisho',
      );

  // ---- Admin: ads ----

  static Future<List<Map<String, dynamic>>> adminAds(String token) =>
      _adminGet(token, 'admin/ads', 'Matangazo hayajapatikana');

  static Future<void> createAd(String token, Map<String, dynamic> ad) =>
      _adminAction(
        token,
        'POST',
        'admin/ads',
        ad,
        'Imeshindikana kuchapisha tangazo',
        okStatus: 201,
      );

  static Future<void> toggleAd(String token, int id) => _adminAction(
    token,
    'PUT',
    'admin/ads',
    {'id': id},
    'Imeshindikana kubadilisha hali ya tangazo',
  );

  // ---- Admin: messages ----

  static Future<List<Map<String, dynamic>>> adminMessageContacts(
    String token,
  ) => _adminGet(token, 'admin/message-contacts', 'Mazungumzo hayajapatikana');

  static Future<List<Map<String, dynamic>>> messagesWith(
    String token,
    int otherUserId,
  ) => _adminGet(
    token,
    'messages?with_user_id=$otherUserId',
    'Ujumbe haujapatikana',
  );

  static Future<void> sendMessageTo(
    String token,
    int receiverId,
    String message,
  ) => _adminAction(
    token,
    'POST',
    'messages',
    {'receiver_id': receiverId, 'message': message},
    'Ujumbe haujatumwa',
    okStatus: 201,
  );
}
