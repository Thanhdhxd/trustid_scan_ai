import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Kiểm tra JWT token xem đã hết hạn chưa (dựa vào trường exp trong payload)
bool isJwtExpired(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return true;
    final normalized = base64Url.normalize(parts[1]);
    final payloadString = utf8.decode(base64Url.decode(normalized));
    final payload = jsonDecode(payloadString);
    if (payload is Map && payload.containsKey('exp')) {
      final exp = payload['exp'];
      if (exp is int) {
        final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        return DateTime.now().isAfter(expiryDate.subtract(const Duration(seconds: 5)));
      }
    }
    return false;
  } catch (_) {
    return true;
  }
}

/// API thật của công ty TrustID - Đồng bộ với TrustID App gốc
final Dio companyApi = Dio(
  BaseOptions(
    baseUrl: 'https://api.trustid.com.vn',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ),
)..interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null && token.isNotEmpty) {
        if (isJwtExpired(token)) {
          // Token cũ đã hết hạn -> tự động xóa để không gửi request gây lỗi 401
          await prefs.remove('auth_token');
        } else {
          options.headers['Authorization'] = 'Bearer $token';
        }
      }
      // Nếu là request yêu cầu xác thực mà không có token, chặn ngay tại client không gửi lên mạng để tránh lỗi 401
      final isProtectedPath = options.path.contains('/auth/profile') ||
          options.path.startsWith('/tenant') ||
          options.path.startsWith('/supply') ||
          options.path.startsWith('/farm') ||
          options.path.startsWith('/kcs') ||
          options.path.startsWith('/manager') ||
          options.path.startsWith('/users');

      if (isProtectedPath && !options.headers.containsKey('Authorization')) {
        return handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
            message: 'Chưa đăng nhập (không có token)',
          ),
        );
      }
      return handler.next(options);
    },
    onError: (DioException error, handler) async {
      if (error.response?.statusCode == 401) {
        // Token không hợp lệ hoặc đã hết hạn trên server -> xóa ngay
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('auth_token');
        } catch (_) {}
      }
      return handler.next(error);
    },
  ));

/// Hàm hỗ trợ hiển thị ảnh
String getProxyImageUrl(String originalUrl) {
  if (originalUrl.isEmpty) return originalUrl;
  if (originalUrl.startsWith('http')) return originalUrl;
  return 'https://api.trustid.com.vn/${originalUrl.startsWith('/') ? originalUrl.substring(1) : originalUrl}';
}

String get _aiBaseUrl {
  if (kIsWeb) {
    return 'http://127.0.0.1:8000';
  }
  return 'http://10.0.2.2:8000';
}

/// Service AI tự dựng (repo trustid-scan-ai-service).
final Dio aiApi = Dio(
  BaseOptions(
    baseUrl: _aiBaseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ),
);
