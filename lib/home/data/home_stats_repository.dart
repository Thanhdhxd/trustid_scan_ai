import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'consumer_models.dart';

final dioProvider = Provider((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.trustid.com.vn',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));
  return dio;
});

final homeStatsRepositoryProvider = Provider((ref) => HomeStatsRepository(ref.read(dioProvider)));
final traceabilityRepositoryProvider = Provider((ref) => ref.read(homeStatsRepositoryProvider));

final weatherSummaryProvider = FutureProvider.family<WeatherSummary?, ({double lat, double lon, int refreshNonce})>((ref, params) async {
  return ref.read(homeStatsRepositoryProvider).getWeatherSummary(
    lat: params.lat,
    lon: params.lon,
    forceRefresh: params.refreshNonce > 0,
  );
});

final weatherDetailProvider = FutureProvider.family<WeatherDetail?, ({double lat, double lon, int refreshNonce})>((ref, params) async {
  return ref.read(homeStatsRepositoryProvider).getWeatherDetail(
    lat: params.lat,
    lon: params.lon,
    forceRefresh: params.refreshNonce > 0,
  );
});

class HomeStatsRepository {
  final Dio _dio;
  HomeStatsRepository(this._dio);

  Future<WeatherSummary?> getWeatherSummary({
    required double lat,
    required double lon,
    String crop = 'rice',
    bool forceRefresh = false,
  }) async {
    try {
      final response = await _dio.get(
        '/api/weather/summary',
        queryParameters: {
          'lat': lat,
          'lon': lon,
          'crop': crop,
          if (forceRefresh) 'force': 'true',
          if (forceRefresh) '_ts': DateTime.now().millisecondsSinceEpoch,
        },
      );
      if (response.data is Map) {
        return WeatherSummary.fromJson((response.data as Map).cast<String, dynamic>());
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<WeatherDetail?> getWeatherDetail({
    required double lat,
    required double lon,
    String crop = 'rice',
    bool forceRefresh = false,
  }) async {
    try {
      final response = await _dio.get(
        '/api/weather',
        queryParameters: {
          'lat': lat,
          'lon': lon,
          'crop': crop,
          if (forceRefresh) 'force': 'true',
          if (forceRefresh) '_ts': DateTime.now().millisecondsSinceEpoch,
        },
      );
      if (response.data is Map) {
        return WeatherDetail.fromJson((response.data as Map).cast<String, dynamic>());
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<WeatherReverseGeocode?> reverseGeocode({
    required double lat,
    required double lon,
  }) async {
    try {
      final response = await _dio.get(
        '/api/weather/reverse-geocode',
        queryParameters: {'lat': lat, 'lon': lon},
      );
      if (response.data is Map) {
        return WeatherReverseGeocode.fromJson((response.data as Map).cast<String, dynamic>());
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> trackWeatherEvent({
    required String event,
    required String page,
    Map<String, dynamic>? meta,
  }) async {
    try {
      await _dio.post(
        '/api/analytics/event',
        data: {
          'event': event,
          'page': page,
          if (meta != null) 'meta': meta,
        },
      );
    } catch (_) {}
  }

  Future<HomeStatsData> getHomeStats() async {
    try {
      final response = await _dio.get('/api/home-stats');
      return HomeStatsData.fromJson(response.data);
    } catch (e) {
      // Return defaults on error for demo purposes
      return HomeStatsData.defaults();
    }
  }

  Future<List<ConsumerPartner>> getTopPartners() async {
    try {
      final response = await _dio.get('/consumer/partners/top');
      return (response.data as List)
          .map((e) => ConsumerPartner.fromJson(e))
          .toList();
    } catch (_) {
      return []; // Return empty on error for now
    }
  }

  Future<List<FeaturedProduct>> getFeaturedProducts() async {
    try {
      final response = await _dio.get('/consumer/products/featured');
      return (response.data as List)
          .map((e) => FeaturedProduct.fromJson(e))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

class HomeStatsData {
  final StatItem totalVerifications;
  final StatItem successRate;
  final StatItem totalProducts;
  final BlockchainStats blockchain;
  final List<CertItem> certifications;
  final List<ChartItem> chart;

  HomeStatsData({
    required this.totalVerifications,
    required this.successRate,
    required this.totalProducts,
    required this.blockchain,
    required this.certifications,
    required this.chart,
  });

  factory HomeStatsData.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] ?? {};
    final blockchainJson = json['blockchain'] ?? {};
    final certs = json['certifications'] as List<dynamic>? ?? [];
    final chartList = json['chart'] as List<dynamic>? ?? [];

    return HomeStatsData(
      totalVerifications: StatItem.fromJson(stats['totalVerifications'] ?? {}),
      successRate: StatItem.fromJson(stats['successRate'] ?? {}),
      totalProducts: StatItem.fromJson(stats['totalProducts'] ?? {}),
      blockchain: BlockchainStats.fromJson(blockchainJson),
      certifications: certs.map((c) => CertItem.fromJson(c)).toList(),
      chart: chartList.map((c) => ChartItem.fromJson(c)).toList(),
    );
  }

  factory HomeStatsData.defaults() {
    return HomeStatsData(
      totalVerifications: StatItem(value: 2400000, formatted: '2.4M+', label: 'Lượt xác thực'),
      successRate: StatItem(value: 98.5, formatted: '98.5%', label: 'Tỷ lệ thật'),
      totalProducts: StatItem(value: 840, formatted: '840+', label: 'Sản phẩm'),
      blockchain: BlockchainStats(
        transactions: StatItem(value: 1200000, formatted: '1.2M', label: 'Giao dịch blockchain đã ghi nhận'),
        counterfeit: StatItem(value: 134, formatted: '134', label: 'Hàng giả bị phát hiện tháng này'),
      ),
      certifications: [
        CertItem(name: 'VietGAP', productCount: 312, color: 'green', icon: 'eco'),
        CertItem(name: 'EUDR', productCount: 98, color: 'blue', icon: 'public'),
        CertItem(name: 'GlobalG.A.P', productCount: 67, color: 'orange', icon: 'local_offer'),
      ],
      chart: [
        ChartItem(label: 'T2', value: 80),
        ChartItem(label: 'T3', value: 100),
        ChartItem(label: 'T4', value: 70),
        ChartItem(label: 'T5', value: 120),
        ChartItem(label: 'T6', value: 140),
        ChartItem(label: 'T7', value: 190),
        ChartItem(label: 'CN', value: 180),
      ],
    );
  }
}

class StatItem {
  final double value;
  final String formatted;
  final String label;

  StatItem({required this.value, required this.formatted, required this.label});

  factory StatItem.fromJson(Map<String, dynamic> json) {
    return StatItem(
      value: (json['value'] ?? 0).toDouble(),
      formatted: json['formatted']?.toString() ?? '0',
      label: json['label']?.toString() ?? '',
    );
  }
}

class BlockchainStats {
  final StatItem transactions;
  final StatItem counterfeit;

  BlockchainStats({required this.transactions, required this.counterfeit});

  factory BlockchainStats.fromJson(Map<String, dynamic> json) {
    return BlockchainStats(
      transactions: StatItem.fromJson(json['transactions'] ?? {}),
      counterfeit: StatItem.fromJson(json['counterfeit'] ?? {}),
    );
  }
}

class CertItem {
  final String name;
  final int productCount;
  final String color;
  final String icon;

  CertItem({required this.name, required this.productCount, required this.color, required this.icon});

  factory CertItem.fromJson(Map<String, dynamic> json) {
    return CertItem(
      name: json['name']?.toString() ?? '',
      productCount: json['productCount'] ?? 0,
      color: json['color']?.toString() ?? 'green',
      icon: json['icon']?.toString() ?? 'eco',
    );
  }
}

class ChartItem {
  final String label;
  final double value;

  ChartItem({required this.label, required this.value});

  factory ChartItem.fromJson(Map<String, dynamic> json) {
    return ChartItem(
      label: json['label']?.toString() ?? '',
      value: (json['value'] ?? 0).toDouble(),
    );
  }
}
