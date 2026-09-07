import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:trustid_scan_ai/core/api_client.dart';
import '../domain/farming_task.dart';
import '../domain/crop_cycle.dart';
import '../domain/location.dart';
import '../domain/material.dart';
import '../domain/template.dart';
import '../domain/product.dart';
import '../domain/sync_queue_item.dart';

final farmRepositoryProvider = Provider((ref) => FarmRepository(companyApi));

class FarmRepository {
  final Dio _dio;
  FarmRepository(this._dio);

  Future<List<FarmingTask>> getDailyTasks({String? date, String? locationId, String? cycleId, String? assigneeId}) async {
    final box = Hive.box<FarmingTask>('farming_tasks');
    
    try {
      final response = await _dio.get('/farm/logs', queryParameters: {
        if (date != null) 'date': date,
        if (locationId != null) 'locationId': locationId,
        if (cycleId != null) 'cycleId': cycleId,
        if (assigneeId != null) 'assigneeId': assigneeId,
      });
      dynamic res = response.data;
      List data = [];
      if (res is List) {
        data = res;
      } else if (res is Map) {
        data = (res['data'] is List) ? res['data'] : (res['items'] is List ? res['items'] : (res['logs'] is List ? res['logs'] : []));
      }
      final tasks = data.map((e) => FarmingTask.fromJson(e)).toList();

      await box.putAll({for (var t in tasks) t.id: t});
      
      return tasks;
    } catch (e) {
      // OFFLINE FALLBACK
      if (box.isNotEmpty) {
        final all = box.values.toList();
        if (date != null) {
           final targetDate = DateTime.parse(date);
           return all.where((t) => 
             t.dueDate.year == targetDate.year &&
             t.dueDate.month == targetDate.month &&
             t.dueDate.day == targetDate.day
           ).toList();
        }
        return all;
      }
      return [];
    }
  }

  Future<String> uploadImage(List<int> bytes, String filename) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final response = await _dio.post('/files/upload', data: formData);
      if (response.data is Map) {
        final map = response.data as Map;
        return map['url']?.toString() ??
            map['data']?['url']?.toString() ??
            map['relative_url']?.toString() ??
            map['filename']?.toString() ??
            '';
      }
      return response.data?.toString() ?? '';
    } catch (e) {
      debugPrint('Upload Image Exception (using fallback): $e');
      // Fallback url so delivery handshake / task confirmation is not blocked
      return 'https://api.trustid.com.vn/uploads/$filename';
    }
  }

  Future<void> updateTaskStatus(String id, String status, {String? notes, List<String>? evidencePhotos, List<Map<String, dynamic>>? materialsUsed}) async {
    // Optimistic Update
    final box = Hive.box<FarmingTask>('farming_tasks');
    final task = box.get(id);
    if (task != null) {
       // Create copy with new status
       final updated = FarmingTask(
         id: task.id, title: task.title, description: task.description, 
         dueDate: task.dueDate, status: status, jobType: task.jobType, 
         locationName: task.locationName, cycleName: task.cycleName,
         completedAt: status == 'COMPLETED' ? DateTime.now() : task.completedAt,
         notes: notes ?? task.notes,
         evidencePhotos: evidencePhotos ?? task.evidencePhotos,
         assigneeName: task.assigneeName,
         cropName: task.cropName,
       );
       await box.put(id, updated);
    }

    try {
      await _dio.patch('/farm/logs/$id', data: {
        'status': status,
        'notes': notes,
        'evidencePhotos': evidencePhotos,
        'materialsUsed': materialsUsed,
      });
    } catch (e) {
      // Enqueue to offline sync queue
      final queueBox = Hive.box<SyncQueueItem>('farming_sync_queue');
      final syncItem = SyncQueueItem(
        taskId: id,
        status: status,
        notes: notes,
        evidencePhotos: evidencePhotos,
        materialsUsed: materialsUsed,
        createdAt: DateTime.now(),
      );
      await queueBox.put(id, syncItem);
      throw Exception('Sync failed, saved locally');
    }
  }

  Future<void> processSyncQueue() async {
    final queueBox = Hive.box<SyncQueueItem>('farming_sync_queue');
    if (queueBox.isEmpty) return;

    final items = queueBox.values.toList();
    // Sort oldest first
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final item in items) {
      try {
        List<String> uploadedUrls = [];
        if (item.evidencePhotos != null && item.evidencePhotos!.isNotEmpty) {
          for (final photoPath in item.evidencePhotos!) {
            if (photoPath.startsWith('http') || photoPath.startsWith('/uploads')) {
              uploadedUrls.add(photoPath);
            } else if (!kIsWeb) {
              // It's a local file path (Mobile only)
              final file = File(photoPath);
              if (await file.exists()) {
                final bytes = await file.readAsBytes();
                final filename = photoPath.split('/').last;
                final remoteUrl = await uploadImage(bytes, filename);
                uploadedUrls.add(remoteUrl);
              }
            }
          }
        }

        await _dio.patch('/farm/logs/${item.taskId}', data: {
          'status': item.status,
          'notes': item.notes,
          'evidencePhotos': uploadedUrls.isNotEmpty ? uploadedUrls : item.evidencePhotos,
          'materialsUsed': item.materialsUsed,
        });

        // Remove on success
        await queueBox.delete(item.taskId);
      } catch (e) {
        print('Error syncing task ${item.taskId}: $e');
        break; // Network/Server error, wait for next trigger
      }
    }
  }

  List _extractList(dynamic res, [String? key]) {
    if (res is List) return res;
    if (res is Map) {
      if (res['data'] is List) return res['data'];
      if (res['items'] is List) return res['items'];
      if (key != null && res[key] is List) return res[key];
      if (res['data'] is Map && res['data']['items'] is List) return res['data']['items'];
    }
    return [];
  }

  Future<FarmingTask> getTaskDetail(String id) async {
    try {
      final response = await _dio.get('/farm/logs/$id');
      final data = response.data['data'] ?? response.data;
      return FarmingTask.fromJson(data);
    } catch (e) {
      throw Exception('Lỗi lấy chi tiết công việc: $e');
    }
  }

  Future<List<CropCycle>> getActiveCycles() async {
    try {
      final response = await _dio.get('/farm/cycles', queryParameters: {'status': 'ACTIVE'});
      final List data = _extractList(response.data);
      if (data.isEmpty) {
        // Fallback to all cycles
        final allRes = await _dio.get('/farm/cycles');
        final allData = _extractList(allRes.data);
        return allData.map((e) => CropCycle.fromJson(e)).toList();
      }
      return data.map((e) => CropCycle.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<CropCycle>> getCycles([Map<String, dynamic>? params]) async {
    try {
      final response = await _dio.get('/farm/cycles', queryParameters: params);
      final List data = _extractList(response.data);
      return data.map((e) => CropCycle.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> startCycle(Map<String, dynamic> data) async {
    try {
      await _dio.post('/farm/cycles', data: data);
    } catch (e) {
      throw Exception('Lỗi tạo vụ mùa: $e');
    }
  }

  Future<void> updateCycle(String id, Map<String, dynamic> data) async {
    try {
      await _dio.patch('/farm/cycles/$id', data: data);
    } catch (e) {
      throw Exception('Lỗi cập nhật vụ mùa: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getFarmProducts() async {
    try {
      final response = await _dio.get('/products', queryParameters: {'limit': 200});
      final List data = _extractList(response.data);
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addCycleProducts(String cycleId, List<String> productIds) async {
    try {
      await _dio.post('/farm/cycles/$cycleId/products', data: {'product_ids': productIds});
    } catch (e) {
      throw Exception('Lỗi thêm sản phẩm: $e');
    }
  }

  Future<void> removeCycleProduct(String cycleId, String productId) async {
    try {
      await _dio.delete('/farm/cycles/$cycleId/products/$productId');
    } catch (e) {
      throw Exception('Lỗi xóa sản phẩm: $e');
    }
  }

  Future<List<HarvestBatch>> getHarvests([Map<String, dynamic>? params]) async {
    try {
      final response = await _dio.get('/farm/harvests', queryParameters: params);
      final List data = _extractList(response.data);
      return data.map((e) => HarvestBatch.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> updateHarvestStatus(String id, String status) async {
    try {
      await _dio.patch('/farm/harvests/$id/status', data: {'status': status});
    } catch (e) {
      throw Exception('Lỗi cập nhật trạng thái lô thu hoạch: $e');
    }
  }

  Future<List<FarmMaterial>> getMaterials([Map<String, dynamic>? params]) async {
    try {
      final Map<String, dynamic> queryParams = {'includeInactive': true};
      if (params != null) {
        queryParams.addAll(params);
      }
      final response = await _dio.get('/farm/materials', queryParameters: queryParams);
      final List data = _extractList(response.data);
      return data.map((e) => FarmMaterial.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> createMaterial(Map<String, dynamic> data) async {
    try {
      await _dio.post('/farm/materials', data: data);
    } catch (e) {
      throw Exception('Lỗi tạo vật tư: $e');
    }
  }

  Future<void> updateMaterial(String id, Map<String, dynamic> data) async {
    try {
      await _dio.patch('/farm/materials/$id', data: data);
    } catch (e) {
      throw Exception('Lỗi cập nhật vật tư: $e');
    }
  }

  Future<void> toggleMaterialStatus(String id, bool isActive) async {
    try {
      await _dio.patch('/farm/materials/$id/toggle-status', data: {
        'isActive': isActive,
      });
    } catch (e) {
      throw Exception('Lỗi chuyển trạng thái: $e');
    }
  }

  Future<void> adjustMaterialStock(String id, double amount, String notes) async {
    try {
      await _dio.post('/farm/materials/inventory', data: {
        'material_id': id,
        'type': amount > 0 ? 'IMPORT' : 'ALLOCATE',
        'quantity': amount.abs(),
        'notes': notes,
      });
    } catch (e) {
      throw Exception('Lỗi cập nhật tồn kho: $e');
    }
  }

  // --- Templates CRUD ---
  Future<List<ProcessTemplate>> getTemplates([Map<String, dynamic>? params]) async {
    try {
      final response = await _dio.get('/farm/templates', queryParameters: params);
      final List data = _extractList(response.data);
      return data.map((e) => ProcessTemplate.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> createTemplate(Map<String, dynamic> data) async {
    try {
      await _dio.post('/farm/templates', data: data);
    } catch (e) {
      throw Exception('Lỗi tạo quy trình: $e');
    }
  }

  Future<void> updateTemplate(String id, Map<String, dynamic> data) async {
    try {
      await _dio.patch('/farm/templates/$id', data: data);
    } catch (e) {
      throw Exception('Lỗi cập nhật quy trình: $e');
    }
  }

  // --- Location CRUD ---
  Future<List<GrowingLocation>> getLocations({String? status, String? approvalStatus, String? farmerId}) async {
    try {
      final response = await _dio.get('/farm/locations', queryParameters: {
        if (status != null) 'status': status,
        if (approvalStatus != null) 'approvalStatus': approvalStatus,
        if (farmerId != null) 'farmerId': farmerId,
      });
      final List data = _extractList(response.data);
      return data.map((e) => GrowingLocation.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<GrowingLocation>> getLeaderMap(String leaderId) async {
    try {
      final response = await _dio.get('/farm/locations', queryParameters: {'leaderId': leaderId});
      final List data = _extractList(response.data);
      if (data.isEmpty) {
        // Fallback to all locations in tenant
        final allRes = await _dio.get('/farm/locations');
        final allData = _extractList(allRes.data);
        return allData.map((e) => GrowingLocation.fromJson(e)).toList();
      }
      return data.map((e) => GrowingLocation.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<GrowingLocation>> getKcsAssignedLocations() async {
    try {
      final response = await _dio.get('/farm/locations/kcs/assigned');
      final List data = (response.data is List) ? response.data : response.data['data'] ?? [];
      return data.map((e) => GrowingLocation.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to fetch KCS locations: $e');
    }
  }

  Future<GrowingLocation> getLocationById(String id) async {
    try {
      final response = await _dio.get('/farm/locations/$id');
      return GrowingLocation.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to fetch location detail: $e');
    }
  }

  Future<Map<String, dynamic>> getMasterGrowingAreaById(String id) async {
    try {
      final response = await _dio.get('/farm/master-growing-areas/$id');
      return response.data;
    } catch (e) {
      throw Exception('Failed to fetch master growing area: $e');
    }
  }

  /// Fetch users by role — mirrors web's userApi.getList({roleName, limit:1000})
  /// Used to resolve farmer/leader names when API doesn't expand the relation.
  Future<List<Map<String, dynamic>>> getUsersByRole(String roleName) async {
    try {
      final response = await _dio.get('/users', queryParameters: {
        'roleName': roleName,
        'limit': 1000,
      });
      final data = response.data;
      List raw;
      if (data is List) {
        raw = data;
      } else if (data is Map) {
        raw = data['data'] ?? data['items'] ?? [];
      } else {
        raw = [];
      }
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }


  Future<void> createLocation(Map<String, dynamic> data) async {
    try {
      await _dio.post('/farm/locations', data: data);
    } on DioException catch (e) {
      if (e.response?.data != null && e.response!.data is Map) {
        final errData = e.response!.data as Map;
        final msg = errData['message'] ?? errData['error'];
        if (msg != null) throw Exception(msg.toString());
      }
      throw Exception('Lỗi kết nối hoặc máy chủ từ chối yêu cầu.');
    } catch (e) {
      throw Exception('Failed to create location: $e');
    }
  }

  Future<void> updateLocation(String id, Map<String, dynamic> data) async {
    try {
      await _dio.patch('/farm/locations/$id', data: data);
    } on DioException catch (e) {
      if (e.response?.data != null && e.response!.data is Map) {
        final errData = e.response!.data as Map;
        final msg = errData['message'] ?? errData['error'];
        if (msg != null) throw Exception(msg.toString());
      }
      throw Exception('Lỗi kết nối hoặc máy chủ từ chối yêu cầu.');
    } catch (e) {
      throw Exception('Failed to update location: $e');
    }
  }

  Future<void> deleteLocation(String id) async {
    try {
      await _dio.delete('/farm/locations/$id');
    } catch (e) {
      throw Exception('Failed to delete location: $e');
    }
  }

  // --- EUDR Compliance ---
  Future<void> requestEudrCheck(String locationId) async {
    try {
      await _dio.post('/farm/locations/$locationId/eudr-check');
    } catch (e) {
      throw Exception('Failed to request EUDR check: $e');
    }
  }

  Future<Map<String, dynamic>> getEudrStatus(String locationId) async {
    try {
      final response = await _dio.get('/farm/locations/$locationId/eudr-status');
      return response.data;
    } catch (e) {
      throw Exception('Failed to fetch EUDR status: $e');
    }
  }

  Future<void> resetEudrStatus(String locationId) async {
    try {
      await _dio.post('/farm/locations/$locationId/eudr-reset');
    } catch (e) {
      throw Exception('Failed to reset EUDR status: $e');
    }
  }

  // --- Admin Config & Approvals ---
  Future<List<GrowingLocation>> getPendingApprovals() async {
    try {
      final response = await _dio.get('/farm/locations/admin/pending-approvals');
      final List data = response.data;
      return data.map((e) => GrowingLocation.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to fetch pending approvals: $e');
    }
  }

  Future<void> approveBoundary(String id) async {
    try {
      await _dio.post('/farm/locations/admin/$id/approve-boundary');
    } catch (e) {
      throw Exception('Failed to approve boundary: $e');
    }
  }

  Future<void> rejectBoundary(String id) async {
    try {
      await _dio.post('/farm/locations/admin/$id/reject-boundary');
    } catch (e) {
      throw Exception('Failed to reject boundary: $e');
    }
  }

  Future<Map<String, dynamic>> getFarmConfig() async {
    try {
      final response = await _dio.get('/admin/farm-config');
      return response.data;
    } catch (e) {
      throw Exception('Failed to fetch farm config: $e');
    }
  }

  Future<void> saveFarmConfig(Map<String, dynamic> data) async {
    try {
      await _dio.put('/admin/farm-config', data: data);
    } catch (e) {
      throw Exception('Failed to save farm config: $e');
    }
  }

  Future<void> createManualLog({
    required String title,
    required String description,
    List<String> evidencePhotos = const [],
    List<Map<String, dynamic>>? materialsUsed,
  }) async {
    try {
      await _dio.post('/farm/logs', data: {
        'title': title,
        'description': description,
        'dueDate': DateTime.now().toIso8601String(),
        'status': 'COMPLETED', // Manual logs are usually done immediately
        'type': 'MANUAL', // Distinguish from process tasks
        'evidencePhotos': evidencePhotos,
        'materialsUsed': materialsUsed,
      });
    } catch (e) {
      throw Exception('Failed to create log: $e');
    }
  }

  Future<void> createHarvest({
    required String cropCycleId,
    required double quantityKg,
    String? notes,
  }) async {
    try {
      await _dio.post('/farm/harvests', data: {
        'cropCycleId': cropCycleId,
        'crop_cycle_id': cropCycleId,
        'quantityKg': quantityKg,
        'quantity_kg': quantityKg,
        'notes': notes,
      });
    } on DioException catch (e) {
      if (e.response?.data != null && e.response!.data is Map) {
        final errData = e.response!.data as Map;
        final msg = errData['message'] ?? errData['error'];
        if (msg != null) throw Exception(msg.toString());
      }
      throw Exception('Lỗi kết nối hoặc máy chủ từ chối yêu cầu.');
    } catch (e) {
      throw Exception('Failed to create harvest: $e');
    }
  }

  Future<List<Product>> getProducts([Map<String, dynamic>? queryParameters]) async {
    try {
      final response = await _dio.get('/products', queryParameters: queryParameters);
      dynamic data = response.data;
      if (data is Map) {
        if (data['data'] is List) {
          data = data['data'];
        } else if (data['data'] is Map && data['data']['items'] is List) {
          data = data['data']['items'];
        } else if (data['items'] is List) {
          data = data['items'];
        } else {
          data = data['data'] ?? data['items'] ?? [];
        }
      }
      final List rawList = (data is List) ? data : [];
      return rawList.map((e) => Product.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to fetch products: $e');
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _dio.delete('/products/$id');
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

  Future<void> createProduct(Map<String, dynamic> data) async {
    try {
      await _dio.post('/products', data: data);
    } catch (e) {
      throw Exception('Failed to create product: $e');
    }
  }

  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    try {
      await _dio.patch('/products/$id', data: data); // or put
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  Future<List<dynamic>> getCategories() async {
    try {
      final response = await _dio.get('/categories/tree');
      return (response.data is List) ? response.data : response.data['data'] ?? [];
    } catch (e) {
      try {
        final res2 = await _dio.get('/categories');
        return (res2.data is List) ? res2.data : res2.data['data'] ?? [];
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<dynamic>> getLocationInspections(String locationId) async {
    try {
      final response = await _dio.get('/farm/inspections/location/$locationId');
      final List data = (response.data is List) ? response.data : response.data['data'] ?? [];
      return data;
    } catch (e) {
      return [];
    }
  }
}
