import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trustid_scan_ai/core/api_client.dart';

class User {
  final String id;
  final String username;
  final String fullName;
  final String role; // FARMER, DRIVER, WAREHOUSE_MANAGER, MANAGER, ADMIN, TENANT_ADMIN
  final String? email;
  final String? status;
  final String? avatar;
  final String? tenantId;
  final String? tenantName;
  final String? phoneNumber;
  final String? leaderId;
  
  User({
    required this.id, 
    required this.username, 
    required this.fullName,
    required this.role,
    this.email,
    this.status,
    this.avatar,
    this.tenantId,
    this.tenantName,
    this.phoneNumber,
    this.leaderId,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      fullName: json['fullName'] ?? json['full_name'] ?? '',
      role: (json['role'] is Map) ? (json['role']['name'] ?? 'USER') : (json['role'] ?? 'USER'),
      email: json['email'],
      status: json['status'],
      avatar: json['avatar'],
      tenantId: json['tenantId'] ?? (json['tenant'] is Map ? json['tenant']['id'] : null),
      tenantName: json['tenantName'] ?? (json['tenant'] is Map ? json['tenant']['name'] : null),
      phoneNumber: json['phoneNumber'] ?? json['phone_number'],
      leaderId: json['leaderId'] ?? json['leader_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'fullName': fullName,
      'role': role,
      'email': email,
      'status': status,
      'avatar': avatar,
      'tenantId': tenantId,
      'tenantName': tenantName,
      'phoneNumber': phoneNumber,
      'leaderId': leaderId,
    };
  }
}

class AuthController extends AsyncNotifier<User?> {
  @override
  FutureOr<User?> build() async {
    return _restoreSession();
  }

  Future<User?> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null && token.isNotEmpty) {
        if (isJwtExpired(token)) {
          await prefs.remove('auth_token');
          return null;
        }
        // Fetch profile từ api
        final response = await companyApi.get('/auth/profile');
        final data = response.data['data'] ?? response.data;
        return User.fromJson(data);
      }
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
      } catch (_) {}
    }
    return null;
  }

  Future<void> refreshProfile() async {
    state = const AsyncLoading();
    final user = await _restoreSession();
    state = AsyncData(user);
  }

  Future<void> login(String username, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final response = await companyApi.post('/auth/login', data: {
        'identifier': username,
        'username': username,
        'password': password,
      });
      final data = response.data;
      String? token;
      if (data is Map && data.containsKey('data')) {
        token = data['data']['access_token'] ?? data['data']['token'];
      } else if (data is Map) {
        token = data['access_token'] ?? data['token'];
      }
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
      }
      final profileResponse = await companyApi.get('/auth/profile');
      final profileData = profileResponse.data['data'] ?? profileResponse.data;
      return User.fromJson(profileData);
    });
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
    } catch (_) {}
    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(AuthController.new);
