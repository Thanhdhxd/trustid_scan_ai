import 'package:dio/dio.dart';
import '../core/api_client.dart';

/// Gọi các API PUBLIC thật của hệ thống TrustID.
/// Chỉ giữ đúng 2 việc: lấy dữ liệu hiển thị + ghi log quét (không đổi
/// hành vi hệ thống gốc).
class TraceabilityRepository {
  /// GET /api/v2/traceability/public/{code}
  /// Trả về JSON dạng block: header_block, origin_block, timeline_block...
  Future<Map<String, dynamic>> getPublicTraceability(String code) async {
    final encodedCode = Uri.encodeComponent(code.trim());

    // 1. Gọi trực tiếp API công ty (chuẩn như app gốc TrustID)
    try {
      final res = await companyApi.get('/api/v2/traceability/public/$encodedCode');
      if (res.data != null && res.data is Map) {
        final resMap = res.data as Map<String, dynamic>;
        if (resMap['data'] != null && resMap['data'] is Map) {
          return Map<String, dynamic>.from(resMap['data'] as Map);
        }
        return Map<String, dynamic>.from(resMap);
      }
      throw Exception('Định dạng dữ liệu không hợp lệ');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Sản phẩm mã: $code không tồn tại trên hệ thống');
      }

      // 2. Dự phòng: Nếu có sự cố mạng hoặc CORS, thử gọi qua FastAPI proxy nếu đang chạy
      try {
        final proxyRes = await aiApi.get('/api/traceability/public/$encodedCode');
        if (proxyRes.data != null && proxyRes.data is Map) {
          final resMap = proxyRes.data as Map<String, dynamic>;
          if (resMap['data'] != null && resMap['data'] is Map) {
            return Map<String, dynamic>.from(resMap['data'] as Map);
          }
          return Map<String, dynamic>.from(resMap);
        }
      } catch (_) {
        // Proxy cũng không khả dụng
      }

      // 3. Dự phòng tiếp theo: thử endpoint v1
      try {
        final resV1 = await companyApi.get('/api/traceability/public/$encodedCode');
        final resMap = resV1.data as Map<String, dynamic>;
        if (resMap['data'] != null && resMap['data'] is Map) {
          return Map<String, dynamic>.from(resMap['data'] as Map);
        }
      } catch (_) {}

      throw Exception(e.message ?? 'Không thể kết nối đến máy chủ dữ liệu sản phẩm');
    }
  }

  /// POST /trace/scan-log
  /// Ghi log quét vào hệ thống công ty như luồng gốc (không phục vụ AI,
  /// chỉ để không phá vỡ hành vi hệ thống thật).
  Future<void> logScan({
    required String code,
    required double lat,
    required double long,
  }) async {
    try {
      await companyApi.post(
        '/trace/scan-log',
        data: {
          'codeString': code,
          'lat': lat,
          'long': long,
        },
      );
    } catch (e) {
      // Bỏ qua lỗi ghi log (vd CORS) để không làm phiền người dùng
    }
  }
}
