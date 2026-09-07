import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/api_client.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';

final tenantRepositoryProvider = Provider((ref) => TenantRepository(companyApi));

final tenantUsersProvider = FutureProvider.autoDispose<List<User>>((ref) async {
  final repo = ref.watch(tenantRepositoryProvider);
  return repo.getTenantUsers();
});

class TenantRepository {
  final Dio _dio;

  TenantRepository(this._dio);

  Future<List<User>> getTenantUsers({String? roleName, String? search, int? page, int? limit}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (roleName != null) queryParams['roleName'] = roleName;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (page != null) queryParams['page'] = page;
      if (limit != null) queryParams['limit'] = limit;

      final response = await _dio.get('/users', queryParameters: queryParams);
      final dynamic data = response.data;

      if (data is List) {
        return data.map((json) => User.fromJson(json)).toList();
      } else if (data is Map<String, dynamic>) {
        if (data.containsKey('data') && data['data'] is List) {
           return (data['data'] as List).map((json) => User.fromJson(json)).toList();
        }
        if (data.containsKey('users') && data['users'] is List) {
           return (data['users'] as List).map((json) => User.fromJson(json)).toList();
        }
        if (data.containsKey('items') && data['items'] is List) {
           return (data['items'] as List).map((json) => User.fromJson(json)).toList();
        }
      }
      
      throw Exception('Unexpected response format: ${data.runtimeType}');
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }

  Future<User> getUser(String userId) async {
    try {
      final response = await _dio.get('/users/$userId');
      return User.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to fetch user $userId: $e');
    }
  }

  Future<Map<String, dynamic>> getKcsProfile(String identifier) async {
    try {
      final response = await _dio.get('/farm/kcs/$identifier/profile');
      return response.data;
    } catch (e) {
      throw Exception('Failed to fetch KCS profile: $e');
    }
  }

  Future<List<dynamic>> getKcsAssignedAreas(String identifier) async {
    try {
      final response = await _dio.get('/farm/kcs/$identifier/assigned-areas');
      return response.data as List;
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getKcsInspections(String identifier) async {
    try {
      final response = await _dio.get('/farm/kcs/$identifier/inspections');
      return response.data as List;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRoles() async {
    try {
      final response = await _dio.get('/admin/roles');
      return (response.data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Failed to fetch roles: $e');
    }
  }

  Future<Map<String, dynamic>> createUser({
    required String username,
    required String password,
    required String fullName,
    required String role,
    String? phoneNumber,
    String? email,
  }) async {
    try {
      final response = await _dio.post('/users', data: {
        'username': username,
        'password': password,
        'fullName': fullName,
        'roleName': role,
        'phoneNumber': phoneNumber,
        'email': email,
      });
      return response.data;
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final error = e.response?.data;
        if (error is Map && error.containsKey('message')) {
          throw Exception(error['message']);
        }
        if (error is Map && error.containsKey('error')) {
          throw Exception(error['error']);
        }
      }
      throw Exception('Failed to create user: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  Future<void> updateUser({
    required String userId,
    String? fullName,
    String? roleName,
    String? phoneNumber,
    String? email,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (fullName != null) data['fullName'] = fullName;
      if (roleName != null) data['roleName'] = roleName;
      if (phoneNumber != null) data['phoneNumber'] = phoneNumber;
      if (email != null) data['email'] = email;

      await _dio.put('/users/$userId', data: data);
    } on DioException catch (e) {
      if (e.response?.data != null) {
        final error = e.response?.data;
        if (error is Map && error.containsKey('message')) {
          throw Exception(error['message']);
        }
      }
      throw Exception('Failed to update user: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _dio.delete('/users/$userId');
    } on DioException catch (e) {
      if (e.response?.data != null) {
        final error = e.response?.data;
        if (error is Map && error.containsKey('message')) {
          throw Exception(error['message']);
        }
      }
      throw Exception('Failed to delete user: ${e.message}');
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }
}
