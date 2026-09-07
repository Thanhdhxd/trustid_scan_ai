import '../core/api_client.dart';

/// Kết quả chấm điểm rủi ro trả về từ service AI.
class RiskResult {
  final double anomalyScore;
  final String level; // NORMAL | WATCH | HIGH_RISK
  final double distanceKm;
  final double minutesSincePrev;
  final int scanCount;
  final List<String> reasons;

  RiskResult({
    required this.anomalyScore,
    required this.level,
    required this.distanceKm,
    required this.minutesSincePrev,
    required this.scanCount,
    this.reasons = const [],
  });

  factory RiskResult.fromJson(Map<String, dynamic> json) => RiskResult(
        anomalyScore: (json['anomaly_score'] ?? 0.0).toDouble(),
        level: json['level'] ?? 'NORMAL',
        distanceKm: (json['distance_km'] ?? 0.0).toDouble(),
        minutesSincePrev: (json['minutes_since_prev'] ?? 0.0).toDouble(),
        scanCount: json['scan_count'] ?? 1,
        reasons: (json['reasons'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      );
}

/// Gọi service AI tự dựng (trustid-scan-ai-service) để chấm điểm rủi ro
/// cho mỗi lượt quét. Service tự quản lý "lượt quét gần nhất" - app chỉ
/// cần gửi đúng 3 giá trị thô (code, vị trí, thời gian).
class RiskRepository {
  /// POST /risk-score
  Future<RiskResult> getRiskScore({
    required String code,
    required double lat,
    required double long,
    DateTime? timestamp,
  }) async {
    try {
      final res = await aiApi.post(
        '/risk-score',
        data: {
          'code': code,
          'lat': lat,
          'long': long,
          'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
        },
      );
      return RiskResult.fromJson(Map<String, dynamic>.from(res.data as Map));
    } catch (e) {
      // Fallback khi AI backend mất kết nối hoặc lỗi
      return RiskResult(
        anomalyScore: 0.0,
        level: 'NORMAL',
        distanceKm: 0.0,
        minutesSincePrev: 0.0,
        scanCount: 1,
      );
    }
  }
}
