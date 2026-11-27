import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/dio_client.dart';
import '../domain/surplus_pool.dart';

final surplusRepositoryProvider = Provider((ref) => SurplusRepository(ref.read(dioProvider)));

final surplusPoolsProvider = FutureProvider.autoDispose<List<SurplusPool>>((ref) async {
  final repo = ref.read(surplusRepositoryProvider);
  return repo.listPools();
});

class SurplusRepository {
  final Dio _dio;

  SurplusRepository(this._dio);

  /// Lấy danh sách tất cả các kho dư theo sản phẩm
  Future<List<SurplusPool>> listPools() async {
    try {
      final response = await _dio.get('/supply/surplus');
      final data = response.data;
      final list = data is List ? data : (data['data'] is List ? data['data'] as List : []);
      return list.map((item) => SurplusPool.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Lấy chi tiết một kho dư kèm theo các mẻ dư (entries)
  Future<SurplusPool> getPoolDetail(String id) async {
    try {
      final response = await _dio.get('/supply/surplus/$id');
      final data = response.data is Map ? response.data as Map<String, dynamic> : <String, dynamic>{};
      return SurplusPool.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Cập nhật hạn sử dụng (số ngày) của kho dư
  Future<void> updateExpiry(String id, int expiryDays) async {
    await _dio.patch(
      '/supply/surplus/$id/expiry',
      data: {'expiry_days': expiryDays},
    );
  }

  /// Kích hoạt quét và chuyển trạng thái các mẻ dư đã hết hạn
  Future<Map<String, dynamic>> expireOldEntries() async {
    final response = await _dio.post('/supply/surplus/expire');
    if (response.data is Map) {
      return response.data as Map<String, dynamic>;
    }
    return {};
  }

  /// Tạo lệnh đóng bao từ các mẻ dư
  Future<Map<String, dynamic>> createOrderFromSurplus({
    required String poolId,
    required List<String> entryIds,
    String? notes,
  }) async {
    final response = await _dio.post(
      '/supply/surplus/create-order',
      data: {
        'pool_id': poolId,
        'entry_ids': entryIds,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    if (response.data is Map) {
      return response.data as Map<String, dynamic>;
    }
    return {};
  }
}
