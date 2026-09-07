import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/api_client.dart';

final dealerRepositoryProvider = Provider((ref) => DealerRepository(companyApi));

class DealerRepository {
  final Dio _dio;
  DealerRepository(this._dio);

  // --- Handshake / Receiving ---
  Future<List<dynamic>> getPendingReceives({int? page, int? limit, String? search, bool? all}) async {
    try {
      final params = <String, dynamic>{};
      if (page != null) params['page'] = page;
      if (limit != null) params['limit'] = limit;
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (all != null) params['all'] = all;

      final response = await _dio.get('/shipments-v2/pending-receive', queryParameters: params);
      return response.data is List ? response.data : (response.data['items'] ?? response.data['data'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getShipmentDetail(String id) async {
    final response = await _dio.get('/shipments-v2/$id');
    return response.data;
  }

  Future<void> confirmReceive(String shipmentId) async {
    await _dio.post('/shipments-v2/$shipmentId/confirm-receive');
  }

  Future<Map<String, dynamic>> repairInbound(String shipmentId) async {
    final response = await _dio.post('/shipments-v2/$shipmentId/repair-inbound');
    return response.data;
  }

  // --- POS / Pricing ---
  Future<Map<String, dynamic>> lookupPrice(String serialNumber, {String? customerId}) async {
    final params = <String, dynamic>{};
    if (customerId != null) params['customerId'] = customerId;
    final response = await _dio.get('/dealer-prices/lookup/${Uri.encodeComponent(serialNumber)}', queryParameters: params);
    return response.data;
  }

  // --- Customers ---
  Future<List<dynamic>> getDealerCustomers({int? page, int? limit, String? search}) async {
    try {
      final params = <String, dynamic>{};
      if (page != null) params['page'] = page;
      if (limit != null) params['limit'] = limit;
      if (search != null && search.isNotEmpty) params['search'] = search;

      final response = await _dio.get('/dealer-customers', queryParameters: params);
      return response.data is List ? response.data : (response.data['items'] ?? response.data['data'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> searchCustomers(String query) async {
    if (query.isEmpty) return [];
    try {
      final response = await _dio.get('/dealer-customers/search', queryParameters: {'q': query});
      return response.data is List ? response.data : (response.data['items'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> data) async {
    final response = await _dio.post('/dealer-customers', data: data);
    return response.data;
  }

  Future<void> updateCustomer(String id, Map<String, dynamic> data) async {
    await _dio.put('/dealer-customers/$id', data: data);
  }

  // --- Checkout ---
  Future<Map<String, dynamic>> checkoutSale(Map<String, dynamic> payload) async {
    final response = await _dio.post('/dealer-dashboard/sale', data: payload);
    return response.data;
  }

  // --- Inventory & History ---
  Future<List<dynamic>> getDealerStock({int? page, int? limit, String? search}) async {
    try {
      final params = <String, dynamic>{};
      if (page != null) params['page'] = page;
      if (limit != null) params['limit'] = limit;
      if (search != null && search.isNotEmpty) params['search'] = search;

      final response = await _dio.get('/dealer-dashboard/inventory', queryParameters: params);
      return response.data is List ? response.data : (response.data['items'] ?? response.data['data'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getSalesHistory({int? page, int? limit}) async {
    try {
      final params = <String, dynamic>{};
      if (page != null) params['page'] = page;
      if (limit != null) params['limit'] = limit;

      final response = await _dio.get('/dealer-dashboard/sales', queryParameters: params);
      return response.data is List ? response.data : (response.data['items'] ?? response.data['data'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await _dio.get('/dealer-dashboard/stats');
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data);
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  Future<List<dynamic>> getTopProducts() async {
    try {
      // Tính toán trực tiếp từ lịch sử bán hàng thực tế của đại lý
      final sales = await getSalesHistory(limit: 100);
      if (sales.isNotEmpty) {
        final Map<String, Map<String, dynamic>> productAggregates = {};

        for (final sale in sales) {
          if (sale is! Map) continue;
          final items = (sale['items'] as List?) ?? (sale['products'] as List?) ?? [];
          for (final item in items) {
            if (item is! Map) continue;
            final name = item['productName']?.toString() ?? item['name']?.toString() ?? 'Sản phẩm';
            final qty = (num.tryParse(item['quantity']?.toString() ?? '') ??
                         num.tryParse(item['qty']?.toString() ?? '') ?? 1).toInt();
            final price = (num.tryParse(item['totalAmount']?.toString() ?? '') ??
                           num.tryParse(item['lineTotal']?.toString() ?? '') ??
                           num.tryParse(item['price']?.toString() ?? '') ?? 0).toDouble();

            if (!productAggregates.containsKey(name)) {
              productAggregates[name] = {
                'name': name,
                'qty': 0,
                'revenue': 0.0,
              };
            }
            productAggregates[name]!['qty'] = (productAggregates[name]!['qty'] as int) + qty;
            productAggregates[name]!['revenue'] = (productAggregates[name]!['revenue'] as double) + price;
          }
        }

        if (productAggregates.isNotEmpty) {
          final list = productAggregates.values.toList();
          list.sort((a, b) => (b['qty'] as int).compareTo(a['qty'] as int));
          return list.take(5).toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getRecentActivity() async {
    try {
      final response = await _dio.get('/dealer-dashboard/recent-activity');
      return response.data is List ? response.data : (response.data['items'] ?? []);
    } catch (e) {
      return [];
    }
  }

  // --- Pricing ---
  Future<List<dynamic>> getDealerPrices() async {
    try {
      final response = await _dio.get('/dealer-prices');
      return response.data is List ? response.data : (response.data['items'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<void> saveDealerPrice(Map<String, dynamic> data) async {
    await _dio.post('/dealer-prices', data: data);
  }

  Future<List<dynamic>> searchSystemProducts(String query) async {
    try {
      final response = await _dio.get('/products', queryParameters: {'search': query, 'limit': 10});
      return response.data is List ? response.data : (response.data['data'] ?? []);
    } catch (e) {
      return [];
    }
  }

  // --- Customer Groups & Pricing Rules ---
  Future<List<dynamic>> getCustomerGroups() async {
    try {
      final response = await _dio.get('/customer-groups');
      return response.data is List ? response.data : (response.data['items'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<void> createCustomerGroup(Map<String, dynamic> data) async {
    await _dio.post('/customer-groups', data: data);
  }

  Future<void> updateCustomerGroup(String id, Map<String, dynamic> data) async {
    await _dio.put('/customer-groups/$id', data: data);
  }

  Future<void> deleteCustomerGroup(String id) async {
    await _dio.delete('/customer-groups/$id');
  }

  Future<List<dynamic>> getGroupPricingRules(String groupId) async {
    try {
      final response = await _dio.get('/customer-groups/$groupId/pricing-rules');
      return response.data is List ? response.data : (response.data['items'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<void> saveGroupPricingRule(Map<String, dynamic> data) async {
    await _dio.post('/customer-groups/pricing-rules', data: data);
  }

  Future<void> deleteGroupPricingRule(String ruleId) async {
    await _dio.delete('/customer-groups/pricing-rules/$ruleId');
  }
}
