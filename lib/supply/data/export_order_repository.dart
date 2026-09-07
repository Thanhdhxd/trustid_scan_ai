import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/api_client.dart';
import '../domain/export_order.dart';

final exportOrderRepositoryProvider = Provider((ref) {
  return ExportOrderRepository(companyApi);
});

class ExportOrderRepository {
  final Dio _dio;
  final String _baseUrl = '/supply/export-orders';

  ExportOrderRepository(this._dio);

  Future<List<ExportOrder>> getOrders([Map<String, dynamic>? filters]) async {
    final response = await _dio.get(_baseUrl, queryParameters: filters);
    // API web trả về dạng { data: [..] } hoặc phân trang
    final data = response.data is List 
        ? response.data 
        : (response.data['items'] ?? response.data['data'] ?? []);
    
    return (data as List).map((e) => ExportOrder.fromJson(e)).toList();
  }

  Future<ExportOrder> getDetail(String id) async {
    final response = await _dio.get('$_baseUrl/$id');
    return ExportOrder.fromJson(response.data);
  }

  Future<void> confirm(String id) async {
    await _dio.post('$_baseUrl/$id/confirm', data: {});
  }

  Future<void> cancel(String id) async {
    await _dio.post('$_baseUrl/$id/cancel', data: {});
  }

  Future<void> scanItem(String id, String qrCode) async {
    await _dio.post('$_baseUrl/$id/scan', data: {'qrCode': qrCode});
  }

  Future<void> unscanItem(String id, String serial) async {
    await _dio.delete('$_baseUrl/$id/scan/items/$serial');
  }

  Future<void> unscanBox(String id, String parentCode) async {
    await _dio.delete('$_baseUrl/$id/scan/boxes/$parentCode');
  }

  Future<List<dynamic>> getScanLogs(String id) async {
    final response = await _dio.get('$_baseUrl/$id/scan-logs');
    return response.data['items'] ?? response.data['data'] ?? response.data ?? [];
  }

  Future<void> finishPicking(String id) async {
    await _dio.post('$_baseUrl/$id/finish-picking', data: {});
  }

  Future<void> createDelivery(String id, Map<String, dynamic> payload) async {
    await _dio.post('$_baseUrl/$id/create-delivery', data: payload);
  }

  Future<void> create(Map<String, dynamic> data) async {
    await _dio.post(_baseUrl, data: data);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _dio.put('$_baseUrl/$id', data: data);
  }
}
