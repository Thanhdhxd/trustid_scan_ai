import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WeatherData {
  final double temperature;
  final int humidity;
  final String description;

  WeatherData({
    required this.temperature,
    required this.humidity,
    this.description = 'Thời tiết thực tế',
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final current = json['current'] ?? {};
    return WeatherData(
      temperature: (current['temperature_2m'] as num?)?.toDouble() ?? 28.0,
      humidity: (current['relative_humidity_2m'] as num?)?.toInt() ?? 75,
      description: 'Cập nhật trực tiếp',
    );
  }
}

final weatherServiceProvider = FutureProvider.autoDispose<WeatherData>((ref) async {
  try {
    final dio = Dio();
    final response = await dio.get(
      'https://api.open-meteo.com/v1/forecast?latitude=21.02&longitude=105.83&current=temperature_2m,relative_humidity_2m',
    );
    return WeatherData.fromJson(response.data);
  } catch (_) {
    return WeatherData(temperature: 28.5, humidity: 75);
  }
});
