import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trustid_scan_ai/core/api_client.dart';
import '../domain/shipment.dart';

final supplyRepositoryProvider = Provider((ref) => SupplyRepository(companyApi));

class SupplyRepository {
  final Dio _dio;
  SupplyRepository(this._dio);

  // In-memory cache with 5-minute TTL
  List<dynamic>? _cachedWarehouses;
  DateTime? _warehousesCacheTime;

  List<dynamic>? _cachedProducts;
  DateTime? _productsCacheTime;

  List<dynamic>? _cachedExternalBatches;
  DateTime? _externalBatchesCacheTime;

  List<dynamic>? _cachedCodePools;
  DateTime? _codePoolsCacheTime;

  List<dynamic>? _cachedActiveTenants;
  DateTime? _activeTenantsCacheTime;

  List<dynamic>? _cachedDealers;
  DateTime? _dealersCacheTime;
  final Map<String, Map<String, dynamic>> _cachedDealerDetails = {};

  void clearCache() {
    _cachedWarehouses = null;
    _warehousesCacheTime = null;
    _cachedProducts = null;
    _productsCacheTime = null;
    _cachedExternalBatches = null;
    _externalBatchesCacheTime = null;
    _cachedCodePools = null;
    _codePoolsCacheTime = null;
    _cachedActiveTenants = null;
    _activeTenantsCacheTime = null;
    _cachedDealers = null;
    _dealersCacheTime = null;
    _cachedDealerDetails.clear();
  }

  Future<List<Shipment>> getMyShipments() async {
    try {
      final response = await _dio.get('/supply/logistics/shipments', queryParameters: {
        'role': 'DRIVER'
      });
      final List data = response.data;
      return data.map((e) => Shipment.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to fetch shipments: $e');
    }
  }

  // --- Packaging & Batches ---

  Future<Map<String, dynamic>> createBatch(Map<String, dynamic> data) async {
    final response = await _dio.post('/supply/batches', data: data);
    return response.data;
  }

  Future<List<dynamic>> getBatches([Map<String, dynamic>? params]) async {
    final response = await _dio.get('/supply/batches', queryParameters: params);
    if (response.data is List) return response.data;
    if (response.data is Map && response.data['data'] is List) return response.data['data'];
    return response.data['items'] ?? [];
  }

  Future<Map<String, dynamic>> getBatchesPaginated([Map<String, dynamic>? params]) async {
    final response = await _dio.get('/supply/batches', queryParameters: params);
    if (response.data is Map) {
      final list = response.data['data'] is List
          ? (response.data['data'] as List)
          : (response.data['items'] is List ? (response.data['items'] as List) : <dynamic>[]);
      final total = response.data['total'] ?? response.data['totalCount'] ?? list.length;
      return {'items': list, 'total': total};
    }
    if (response.data is List) {
      return {'items': response.data as List, 'total': (response.data as List).length};
    }
    return {'items': [], 'total': 0};
  }

  Future<List<dynamic>> getBatchItems(String batchId) async {
    final response = await _dio.get('/supply/batches/$batchId/items');
    if (response.data is List) return response.data;
    if (response.data is Map && response.data['data'] is List) return response.data['data'];
    return response.data['items'] ?? [];
  }

  Future<Map<String, dynamic>> getBatch(String id) async {
    final response = await _dio.get('/supply/batches/$id');
    if (response.data is Map) {
      final map = response.data as Map;
      return map['data'] is Map ? Map<String, dynamic>.from(map['data']) : Map<String, dynamic>.from(map);
    }
    return {};
  }

  Future<void> distributeBatch(String id) async {
    await _dio.post('/supply/batches/$id/distribute');
  }

  Future<Map<String, dynamic>> addItems(Map<String, dynamic> data) async {
    final response = await _dio.post('/supply/packaging/add-items', data: data);
    return response.data is Map ? Map<String, dynamic>.from(response.data) : {};
  }

  Future<Map<String, dynamic>> getHarvestStats(String harvestCode) async {
    final response = await _dio.get('/supply/packaging/harvest-stats', queryParameters: {'harvestCode': harvestCode});
    return response.data;
  }

  Future<List<dynamic>> getHarvests({int limit = 1000}) async {
    final response = await _dio.get('/farm/harvests', queryParameters: {'limit': limit});
    return (response.data is List) ? response.data : (response.data['data'] ?? []);
  }

  Future<Map<String, dynamic>> validateCode(String code) async {
    try {
      final response = await _dio.get('/scan/check', queryParameters: {'code': code});
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data);
      }
    } catch (_) {}
    return {'valid': true, 'codeString': code, 'serial': code};
  }

  Future<Map<String, dynamic>> checkPackagingCode({
    required String code,
    required String type, // 'BAG' | 'PACKET'
    String? productId,
    String? batchId,
  }) async {
    final response = await _dio.post('/supply/packaging/check-code', data: {
      'code': code,
      'type': type,
      if (productId != null && productId.isNotEmpty) 'product_id': productId,
      if (batchId != null && batchId.isNotEmpty) 'batch_id': batchId,
    });
    return response.data is Map ? Map<String, dynamic>.from(response.data) : {};
  }

  Future<Map<String, dynamic>> replacePackagingItem({
    required String batchId,
    required String type, // 'BAG' | 'PACKET'
    required String oldSerial,
    required String newSerial,
    String? reason,
  }) async {
    final response = await _dio.post('/supply/packaging/replace-item', data: {
      'batch_id': batchId,
      'type': type,
      'old_serial': oldSerial,
      'new_serial': newSerial,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    return response.data is Map ? Map<String, dynamic>.from(response.data) : {};
  }

  Future<Map<String, dynamic>> getPackagedSummary(String batchId) async {
    final response = await _dio.get('/supply/batches/$batchId/packaged-summary');
    return response.data is Map ? Map<String, dynamic>.from(response.data) : {};
  }

  Future<Map<String, dynamic>> createBatchAndAddItems(Map<String, dynamic> data) async {
    final response = await _dio.post('/supply/packaging/create-and-add', data: data);
    return response.data is Map ? Map<String, dynamic>.from(response.data) : {};
  }

  // --- Dealer Management ---
  Future<List<dynamic>> getDealers({int? page, int? limit, String? search, bool forceRefresh = false}) async {
    final isDefaultLookup = (page == null || page == 1) && (search == null || search.isEmpty);
    if (!forceRefresh && isDefaultLookup && _cachedDealers != null && _dealersCacheTime != null) {
      if (DateTime.now().difference(_dealersCacheTime!).inMinutes < 5) {
        return _cachedDealers!;
      }
    }

    final params = <String, dynamic>{};
    if (page != null) params['page'] = page;
    if (limit != null) params['limit'] = limit;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await _dio.get('/dealers', queryParameters: params);
    final list = response.data is List ? response.data : (response.data['items'] ?? response.data['data'] ?? []);
    if (isDefaultLookup && list is List) {
      _cachedDealers = list;
      _dealersCacheTime = DateTime.now();
      for (final d in list) {
        if (d is Map && d['id'] != null) {
          _cachedDealerDetails[d['id'].toString()] = Map<String, dynamic>.from(d);
        }
      }
    }
    return list;
  }

  Future<Map<String, dynamic>> getDealerDetail(String id, {bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedDealerDetails.containsKey(id)) {
      return _cachedDealerDetails[id]!;
    }
    final response = await _dio.get('/dealers/$id');
    if (response.data is Map) {
      final map = Map<String, dynamic>.from(response.data);
      _cachedDealerDetails[id] = map;
      return map;
    }
    throw Exception('Invalid dealer detail format: ${response.data.runtimeType}');
  }

  // --- Warehouse Management ---

  Future<List<dynamic>> getWarehouses({int? page, int? limit, String? search, bool forceRefresh = false}) async {
    final isDefaultLookup = (page == null || page == 1) && (search == null || search.isEmpty);
    if (!forceRefresh && isDefaultLookup && _cachedWarehouses != null && _warehousesCacheTime != null) {
      if (DateTime.now().difference(_warehousesCacheTime!).inMinutes < 5) {
        return _cachedWarehouses!;
      }
    }

    final params = <String, dynamic>{};
    if (page != null) params['page'] = page;
    if (limit != null) params['limit'] = limit;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await _dio.get('/supply/warehouses', queryParameters: params);
    final list = response.data is List ? response.data : (response.data['items'] ?? response.data['data'] ?? []);
    if (isDefaultLookup && list is List) {
      _cachedWarehouses = list;
      _warehousesCacheTime = DateTime.now();
    }
    return list;
  }

  Future<Map<String, dynamic>> createWarehouse(Map<String, dynamic> data) async {
    _cachedWarehouses = null;
    final response = await _dio.post('/supply/warehouses', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateWarehouse(String id, Map<String, dynamic> data) async {
    _cachedWarehouses = null;
    final response = await _dio.patch('/supply/warehouses/$id', data: data);
    return response.data;
  }

  Future<void> deleteWarehouse(String id) async {
    _cachedWarehouses = null;
    await _dio.delete('/supply/warehouses/$id');
  }

  Future<Map<String, dynamic>> getWarehouseDashboardStats() async {
    Future<dynamic> safeGet(String path) async {
      try {
        final options = Options(sendTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5));
        return await _dio.get(path, options: options);
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([
      safeGet('/supply/warehouses'),
      safeGet('/supply/batches'),
      safeGet('/supply/inventory/summary'),
      safeGet('/supply/export-orders'),
    ]);

    final wData = results[0]?.data;
    final bData = results[1]?.data;
    final iData = results[2]?.data;
    final eData = results[3]?.data;

    int totalWarehouses = wData is List ? wData.length : (wData?['total'] ?? (wData?['data'] as List?)?.length ?? (wData?['items'] as List?)?.length ?? 0);
    int totalBatches = bData is List ? bData.length : (bData?['total'] ?? (bData?['data'] as List?)?.length ?? (bData?['items'] as List?)?.length ?? 0);
    int totalExports = eData is List ? eData.length : (eData?['total'] ?? (eData?['data'] as List?)?.length ?? (eData?['items'] as List?)?.length ?? 0);

    int totalQuantity = 0;
    int totalAvailable = 0;
    int totalPending = 0;
    int totalProducts = 0;
    List iItems = [];

    if (iData is List) {
      iItems = iData;
    } else if (iData is Map) {
      totalQuantity = (iData['totalQuantity'] ?? iData['total'] ?? 0).toInt();
      totalAvailable = (iData['totalAvailable'] ?? iData['availableQuantity'] ?? totalQuantity).toInt();
      totalPending = (iData['totalPending'] ?? iData['pendingQuantity'] ?? 0).toInt();
      totalProducts = (iData['totalProducts'] ?? 0).toInt();

      if (iData['items'] is List) {
        iItems = iData['items'];
      } else if (iData['data'] is List) {
        iItems = iData['data'];
      }
    }

    if (totalQuantity <= 0 && iItems.isNotEmpty) {
      num sumQ = 0;
      num sumA = 0;
      num sumP = 0;
      Set<String> productIds = {};
      for (var item in iItems) {
        sumQ += (item['rawQuantity'] ?? item['quantity'] ?? item['totalQuantity'] ?? item['balance'] ?? 0);
        sumA += (item['availableQuantity'] ?? item['available'] ?? item['quantity'] ?? 0);
        sumP += (item['reservedQuantity'] ?? item['pendingQuantity'] ?? item['pending'] ?? 0);
        final pid = item['productId'] ?? item['productCode'] ?? item['productName'] ?? item['name'];
        if (pid != null) productIds.add(pid.toString());
      }
      totalQuantity = sumQ.toInt();
      totalAvailable = sumA.toInt();
      totalPending = sumP.toInt();
      totalProducts = productIds.isNotEmpty ? productIds.length : iItems.length;
    }

    if (totalPending == 0 && eData != null) {
      final eItems = eData is List ? eData : (eData['items'] ?? eData['data'] ?? []);
      if (eItems is List) {
        for (var ord in eItems) {
          final st = (ord['status'] ?? '').toString().toUpperCase();
          if (['PENDING', 'PROCESSING', 'APPROVED', 'WAITING'].contains(st)) {
            totalPending += (num.tryParse(ord['quantity']?.toString() ?? ord['totalQuantity']?.toString() ?? '1') ?? 1).toInt();
          }
        }
      }
    }

    return {
      'totalQuantity': totalQuantity,
      'totalAvailable': totalAvailable,
      'totalPending': totalPending,
      'totalProducts': totalProducts,
      'totalWarehouses': totalWarehouses,
      'totalBatches': totalBatches,
      'totalExports': totalExports,
      'inventoryItems': iItems,
    };
  }


  // --- Vehicles ---

  Future<List<dynamic>> getVehicles({int? page, int? limit}) async {
    final params = <String, dynamic>{};
    if (page != null) params['page'] = page;
    if (limit != null) params['limit'] = limit;
    
    final response = await _dio.get('/supply/vehicles', queryParameters: params);
    return response.data is List ? response.data : (response.data['items'] ?? response.data['data'] ?? []);
  }

  // --- Inventory ---

  Future<List<dynamic>> getStock(String warehouseId, {int? page, int? limit}) async {
    final params = <String, dynamic>{'warehouseId': warehouseId};
    if (page != null) params['page'] = page;
    if (limit != null) params['limit'] = limit;
    final response = await _dio.get('/supply/inventory', queryParameters: params);
    return response.data is List ? response.data : (response.data['items'] ?? response.data['data'] ?? []);
  }

  Future<List<dynamic>> getInventoryMovements(String warehouseId, {int? page, int? limit}) async {
    final params = <String, dynamic>{'warehouseId': warehouseId};
    if (page != null) params['page'] = page;
    if (limit != null) params['limit'] = limit;
    final response = await _dio.get('/supply/inventory/movements', queryParameters: params);
    return response.data is List ? response.data : (response.data['items'] ?? response.data['data'] ?? []);
  }

  Future<void> inboundManual(Map<String, dynamic> data) async {
    await _dio.post('/supply/inventory/inbound', data: data);
  }

  // --- Cross Tenant B2B Transfer ---
  Future<List<dynamic>> getTransfers() async {
    try {
      final response = await _dio.get('/supply/transfers');
      if (response.data is List) return response.data;
      if (response.data is Map && response.data['data'] is List) return response.data['data'];
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createTransfer(Map<String, dynamic> data) async {
    final response = await _dio.post('/supply/transfers', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> confirmTransferExport(String transferId, String warehouseId) async {
    final response = await _dio.post('/supply/transfers/$transferId/export', data: {
      'warehouse_id': warehouseId,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> confirmTransferImport(Map<String, dynamic> data) async {
    final response = await _dio.post('/supply/transfers/import', data: data);
    return response.data;
  }

  Future<List<dynamic>> getTransferLogs(String transferId) async {
    final response = await _dio.get('/supply/transfers/$transferId/logs');
    return response.data;
  }

  Future<void> handshake({
    required String shipmentId,
    required String action,
    required double lat,
    required double long,
    String? signature,
    String? evidenceUrl,
  }) async {
    await _dio.post('/supply/logistics/handshake', data: {
      'shipment_id': shipmentId,
      'action': action,
      'lat': lat,
      'long': long,
      'signature': signature,
      'evidence_url': evidenceUrl
    });
  }

  // --- Semi-Finished Product (Bán thành phẩm) ---

  Future<Map<String, dynamic>> refineSemiFinished(Map<String, dynamic> data) async {
    final response = await _dio.post('/supply/batches/refine-semi-finished', data: data);
    return response.data;
  }

  Future<String> getNextSemiFinishedBatchCode(String? productionAddress) async {
    final response = await _dio.get('/supply/batches/semi-finished/next-batch-code',
      queryParameters: productionAddress != null ? {'production_address': productionAddress} : {},
    );
    return response.data['next_batch_code'] ?? '';
  }

  Future<List<dynamic>> getExternalBatches([Map<String, dynamic>? params, bool forceRefresh = false]) async {
    final isDefaultLookup = params == null || (params.length <= 2 && params['hideEmptyStock'] != null);
    if (!forceRefresh && isDefaultLookup && _cachedExternalBatches != null && _externalBatchesCacheTime != null) {
      if (DateTime.now().difference(_externalBatchesCacheTime!).inMinutes < 5) {
        return _cachedExternalBatches!;
      }
    }
    try {
      final response = await _dio.get('/supply/batches/external', queryParameters: params);
      List<dynamic> list = [];
      if (response.data is List) {
        list = response.data;
      } else if (response.data is Map && response.data['data'] is List) {
        list = response.data['data'];
      }
      if (isDefaultLookup && list.isNotEmpty) {
        _cachedExternalBatches = list;
        _externalBatchesCacheTime = DateTime.now();
      }
      return list;
    } catch (_) {
      return _cachedExternalBatches ?? [];
    }
  }

  Future<Map<String, dynamic>> getExternalBatchesDetailed({
    int page = 1,
    int limit = 10,
    String? search,
    String? productId,
    bool hideEmptyStock = false,
  }) async {
    try {
      final response = await _dio.get(
        '/supply/batches/external',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (search != null && search.isNotEmpty) 'search': search,
          if (productId != null && productId.isNotEmpty) 'productId': productId,
          'hideEmptyStock': hideEmptyStock ? 'true' : 'false',
        },
      );
      if (response.data is Map) {
        final rawMap = response.data as Map;
        // Check if nested inside standard API response { data: { data: [...], total: ... } }
        if (rawMap['data'] is Map && (rawMap['data'] as Map).containsKey('data')) {
          return Map<String, dynamic>.from(rawMap['data'] as Map);
        }
        return Map<String, dynamic>.from(rawMap);
      }
      if (response.data is List) {
        return {'data': response.data, 'total': (response.data as List).length};
      }
      return {'data': [], 'total': 0};
    } catch (e) {
      debugPrint('[SupplyRepository] getExternalBatchesDetailed error: $e');
      return {'data': [], 'total': 0};
    }
  }

  /// Tìm kiếm lô nguyên liệu ngoài farm / B2B / BTP khả dụng theo từ khóa (Remote Search).
  Future<List<Map<String, dynamic>>> getExternalBatchSourceOptions({
    String? productId,
    String? search,
    String? sourceType,
    bool hideEmptyStock = true,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      'hideEmptyStock': hideEmptyStock ? 'true' : 'false',
      if (productId != null && productId.isNotEmpty) 'productId': productId,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (sourceType != null && sourceType.isNotEmpty) 'sourceType': sourceType,
    };
    final response = await _dio.get('/supply/batches/external/source-options', queryParameters: params);
    final list = _unwrapItems(response.data);
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> createExternalBatch(Map<String, dynamic> data) async {
    final response = await _dio.post('/supply/batches/external', data: data);
    return response.data is Map<String, dynamic> ? response.data : {};
  }

  Future<Map<String, dynamic>> updateExternalBatch(String id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/supply/batches/external/$id', data: data);
    return response.data is Map<String, dynamic> ? response.data : {};
  }

  Future<void> deleteExternalBatch(String id) async {
    await _dio.delete('/supply/batches/external/$id');
  }

  Future<List<String>> searchSerialPrefixes({String? productId}) async {
    final response = await _dio.get('/supply/packaging/serial-prefixes',
      queryParameters: productId != null ? {'product_id': productId} : {},
    );
    return (response.data as List).map((e) => e.toString()).toList();
  }

  Future<Map<String, dynamic>> getPrefixNextNumber(String prefix) async {
    final response = await _dio.get('/supply/packaging/prefix-next-number',
      queryParameters: {'prefix': prefix},
    );
    return response.data;
  }

  Future<List<dynamic>> lookupSerials(List<String> serials) async {
    final response = await _dio.post('/supply/packaging/lookup-serials', data: {'serials': serials});
    return response.data is List ? response.data : [];
  }

  Future<void> cancelBatch(String id, [Map<String, dynamic>? data]) async {
    await _dio.post('/supply/batches/$id/cancel', data: data ?? {});
  }

  Future<void> finishBatch(String id, [Map<String, dynamic>? data]) async {
    await _dio.post('/supply/batches/$id/finish', data: data ?? {});
  }

  Future<List<dynamic>> getCodePools({bool forceRefresh = false, int limit = 500}) async {
    if (!forceRefresh && _cachedCodePools != null && _codePoolsCacheTime != null) {
      if (DateTime.now().difference(_codePoolsCacheTime!).inSeconds < 30) {
        return _cachedCodePools!;
      }
    }
    try {
      final response = await _dio.get('/codes/pools', queryParameters: {'limit': limit});
      final list = response.data is List ? response.data : (response.data['items'] ?? response.data['data'] ?? []);
      if (list is List) {
        _cachedCodePools = list;
        _codePoolsCacheTime = DateTime.now();
      }
      return list;
    } catch (_) {
      return _cachedCodePools ?? [];
    }
  }

  Future<Map<String, dynamic>?> getPoolSuggestedRange(String poolId, {int? neededCount}) async {
    try {
      final params = <String, dynamic>{};
      if (neededCount != null && neededCount > 0) params['neededCount'] = neededCount;
      final response = await _dio.get('/codes/pools/$poolId/suggest-range', queryParameters: params);
      if (response.data is Map) {
        final map = Map<String, dynamic>.from(response.data);
        return map['data'] is Map ? Map<String, dynamic>.from(map['data']) : map;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<dynamic>> getProducts({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedProducts != null && _productsCacheTime != null) {
      if (DateTime.now().difference(_productsCacheTime!).inMinutes < 5) {
        return _cachedProducts!;
      }
    }
    final response = await _dio.get(
      '/products',
      queryParameters: const {'mode': 'lookup', 'page': 1, 'limit': 1000},
    );
    final list = response.data is List ? response.data : (response.data['items'] ?? response.data['data'] ?? []);
    if (list is List) {
      _cachedProducts = list;
      _productsCacheTime = DateTime.now();
    }
    return list;
  }

  Future<Map<String, dynamic>> receiveBatch(String qrCode) async {
    final response = await _dio.post('/supply/batches/receive', data: {'qrCode': qrCode});
    return response.data is Map ? Map<String, dynamic>.from(response.data) : {'message': 'success'};
  }

  Future<Map<String, dynamic>> lookupBatchByQr(String qrCode) async {
    final response = await _dio.get('/supply/batches/lookup-qr', queryParameters: {'code': qrCode});
    return response.data is Map ? Map<String, dynamic>.from(response.data) : {};
  }

  Future<void> transferBatch(String batchId, String targetTenantId) async {
    await _dio.post('/supply/batches/$batchId/transfer', data: {'targetTenantId': targetTenantId});
  }

  Future<Map<String, dynamic>> lookupTenantByCode(String code) async {
    final response = await _dio.get('/tenants/lookup', queryParameters: {'code': code});
    return response.data;
  }

  Future<List<dynamic>> getB2BPartners() async {
    try {
      final response = await _dio.get('/supply/b2b-partners');
      return response.data is List ? response.data : [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createB2BPartner(Map<String, dynamic> data) async {
    final response = await _dio.post('/supply/b2b-partners', data: data);
    return response.data;
  }

  Future<void> removeB2BPartner(String id) async {
    await _dio.delete('/supply/b2b-partners/$id');
  }

  Future<List<dynamic>> searchActiveTenants(String search, {bool forceRefresh = false}) async {
    if (!forceRefresh && search.isEmpty && _cachedActiveTenants != null && _activeTenantsCacheTime != null) {
      if (DateTime.now().difference(_activeTenantsCacheTime!).inMinutes < 5) {
        return _cachedActiveTenants!;
      }
    }
    try {
      final response = await _dio.get('/tenants/active', queryParameters: {'search': search, 'limit': 15});
      final list = response.data is List ? response.data : (response.data['items'] ?? response.data['data'] ?? []);
      if (search.isEmpty && list is List) {
        _cachedActiveTenants = list;
        _activeTenantsCacheTime = DateTime.now();
      }
      return list;
    } catch (_) {
      return _cachedActiveTenants ?? [];
    }
  }

  Future<void> cancelTransfer(String id) async {
    await _dio.post('/supply/transfers/$id/cancel');
  }

  // --- Production Orders (LSX) ---

  Map<String, dynamic> _unwrapMap(dynamic raw) {
    if (raw is! Map) return {};
    final root = Map<String, dynamic>.from(raw);
    if (root['data'] is Map) {
      return Map<String, dynamic>.from(root['data'] as Map);
    }
    return root;
  }

  List<dynamic> _unwrapItems(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map) {
      final map = raw['data'] is Map ? raw['data'] as Map : raw;
      final items = map['items'] ?? map['data'] ?? map['receipts'];
      if (items is List) return items;
    }
    return const [];
  }

  Future<List<dynamic>> getProductionOrders({
    int page = 1,
    int limit = 15,
    String? search,
    String? status,
    String? orderType,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (orderType != null && orderType.isNotEmpty) params['orderType'] = orderType;

    final response = await _dio.get('/supply/production-orders', queryParameters: params);
    return _unwrapItems(response.data);
  }

  Future<Map<String, dynamic>> getProductionOrderDetail(String id) async {
    final response = await _dio.get('/supply/production-orders/$id');
    return _unwrapMap(response.data);
  }

  Future<List<dynamic>> getOrderLotMappings(String orderId) async {
    final response = await _dio.get('/supply/production-orders/$orderId/lot-mappings');
    if (response.data is List) {
      return response.data;
    } else if (response.data is Map && response.data['lots'] != null) {
      return response.data['lots'] is List ? response.data['lots'] : [];
    }
    return [];
  }

  Future<Map<String, dynamic>> previewBagOrder({
    required String productId,
    double? plannedWeightKg,
    int? quantity,
    double? unitWeightKg,
    int? packagingSpec,
    int? sparePacketQuantity,
    int? spareBagQuantity,
    String? sourceBatchId,
    String? farmBatchCode,
    String? sourceType,
  }) async {
    final params = <String, dynamic>{
      'product_id': productId,
      if (plannedWeightKg != null) 'planned_weight_kg': plannedWeightKg,
      if (quantity != null) 'quantity': quantity,
      if (unitWeightKg != null) 'unit_weight_kg': unitWeightKg,
      if (packagingSpec != null) 'packaging_spec': packagingSpec,
      if (sparePacketQuantity != null) 'spare_packet_quantity': sparePacketQuantity,
      if (spareBagQuantity != null) 'spare_bag_quantity': spareBagQuantity,
      if (sourceBatchId != null && sourceBatchId.isNotEmpty) 'source_batch_id': sourceBatchId,
      if (farmBatchCode != null && farmBatchCode.isNotEmpty) 'farm_batch_code': farmBatchCode,
      if (sourceType != null && sourceType.isNotEmpty) 'source_type': sourceType,
    };
    final response = await _dio.get(
      '/supply/production-orders/bag-packaging/preview',
      queryParameters: params,
    );
    return _unwrapMap(response.data);
  }

  Future<Map<String, dynamic>> retryGenerateCodes(String orderId) async {
    final response = await _dio.post('/supply/production-orders/$orderId/retry-generate');
    return _unwrapMap(response.data);
  }

  Future<Map<String, dynamic>> completeProductionOrder(
    String orderId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      '/supply/production-orders/$orderId/complete',
      data: payload,
    );
    return _unwrapMap(response.data);
  }

  Future<Map<String, dynamic>> cancelProductionOrder(
    String orderId,
    String reason,
  ) async {
    final response = await _dio.post(
      '/supply/production-orders/$orderId/cancel',
      data: {'reason': reason},
    );
    return _unwrapMap(response.data);
  }

  Future<Map<String, dynamic>> createProductionOrder(Map<String, dynamic> data) async {
    final response = await _dio.post('/supply/production-orders', data: data);
    return response.data is Map<String, dynamic> ? response.data : {'data': response.data};
  }

  Future<Map<String, dynamic>> createBagOrder(Map<String, dynamic> data) async {
    final response = await _dio.post('/supply/production-orders/bag-packaging', data: data);
    return response.data is Map<String, dynamic> ? response.data : {'data': response.data};
  }

  // --- Production Tickets (STANDARD - Đóng gói tiêu chuẩn) ---

  Future<Map<String, dynamic>> getOrCreateProductionTicket(String orderId) async {
    final response = await _dio.get('/supply/production-tickets/by-order/$orderId');
    return _unwrapMap(response.data);
  }

  Future<Map<String, dynamic>> createProductionTicket({
    required String orderId,
    double? plannedWeightKg,
    String? operatorId,
  }) async {
    final payload = <String, dynamic>{
      'order_id': orderId,
      'ticket_type': 'PACKAGING',
      if (plannedWeightKg != null) 'planned_weight_kg': plannedWeightKg,
      if (operatorId != null && operatorId.isNotEmpty) 'operator_id': operatorId,
    };
    final response = await _dio.post('/supply/production-tickets', data: payload);
    return _unwrapMap(response.data);
  }

  Future<Map<String, dynamic>> getTicketDetail(String ticketId) async {
    final response = await _dio.get('/supply/production-tickets/$ticketId');
    return _unwrapMap(response.data);
  }

  Future<Map<String, dynamic>> scanTicketSerial(String ticketId, String code) async {
    final response = await _dio.post(
      '/supply/production-tickets/$ticketId/scan',
      data: {'code': code},
    );
    return _unwrapMap(response.data);
  }

  Future<Map<String, dynamic>> unscanTicketSerial(String ticketId, String serial) async {
    final encoded = Uri.encodeComponent(serial);
    final response = await _dio.delete('/supply/production-tickets/$ticketId/scans/$encoded');
    return _unwrapMap(response.data);
  }

  Future<Map<String, dynamic>> completeTicket(
    String ticketId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      '/supply/production-tickets/$ticketId/complete',
      data: payload,
    );
    return _unwrapMap(response.data);
  }

  Future<Map<String, dynamic>> rejectTicket(String ticketId, String reason) async {
    final response = await _dio.post(
      '/supply/production-tickets/$ticketId/reject',
      data: {'reason': reason},
    );
    return _unwrapMap(response.data);
  }

  // --- Packaging Receipt (BAG_PACKAGING - Đóng bao) ---

  Future<Map<String, dynamic>> listReceipts(String orderId) async {
    final response = await _dio.get(
      '/supply/packaging-receipts',
      queryParameters: {'orderId': orderId},
    );
    return _unwrapMap(response.data);
  }

  Future<Map<String, dynamic>> createReceipt({
    required String orderId,
    String? warehouseId,
    String? mfgDate,
    String? expiryDate,
    String? dateOverrideReason,
  }) async {
    final payload = <String, dynamic>{
      'order_id': orderId,
      if (warehouseId != null && warehouseId.isNotEmpty) 'warehouse_id': warehouseId,
      if (mfgDate != null && mfgDate.isNotEmpty) 'mfg_date': mfgDate,
      if (expiryDate != null && expiryDate.isNotEmpty) 'expiry_date': expiryDate,
      if (dateOverrideReason != null && dateOverrideReason.isNotEmpty)
        'date_override_reason': dateOverrideReason,
    };
    final response = await _dio.post('/supply/packaging-receipts', data: payload);
    return _unwrapMap(response.data);
  }

  /// API trả về `{ receipt, order }` hoặc bọc trong `{ data: { receipt, order } }`.
  Future<Map<String, dynamic>> getOrCreateReceipt(String orderId) async {
    final response = await _dio.get('/supply/packaging-receipts/by-order/$orderId');
    final raw = response.data;
    if (raw is! Map) {
      throw Exception('Phản hồi phiếu đóng bao không hợp lệ');
    }
    final Map<String, dynamic> root = Map<String, dynamic>.from(raw);
    final nested = root['data'];
    final Map<String, dynamic> payload = nested is Map
        ? Map<String, dynamic>.from(nested)
        : root;

    // Chuẩn hoá: luôn trả về map có key `receipt` + `id` của phiếu
    final receipt = payload['receipt'];
    if (receipt is Map) {
      final receiptMap = Map<String, dynamic>.from(receipt);
      return {
        ...payload,
        'receipt': receiptMap,
        'id': receiptMap['id'] ?? receiptMap['receiptId'],
        'receiptId': receiptMap['id'] ?? receiptMap['receiptId'],
      };
    }

    // Fallback: một số bản API trả thẳng object phiếu
    final id = payload['id'] ?? payload['receiptId'];
    if (id != null) {
      return {
        ...payload,
        'receipt': payload,
        'id': id,
        'receiptId': id,
      };
    }

    throw Exception('Không lấy được mã phiếu đóng bao từ máy chủ');
  }

  Future<Map<String, dynamic>> getReceiptDetail(String receiptId) async {
    final response = await _dio.get('/supply/packaging-receipts/$receiptId');
    return _unwrapMap(response.data);
  }

  Future<Map<String, dynamic>> validateBagForReceipt(
    String receiptId,
    String bagCode,
  ) async {
    final response = await _dio.post(
      '/supply/packaging-receipts/$receiptId/validate-bag',
      data: {'bag_code': bagCode},
    );
    return _unwrapMap(response.data);
  }

  Future<Map<String, dynamic>> scanBagLinkV6(
    String receiptId,
    String packetCode, {
    String? bagCode,
  }) async {
    final data = <String, dynamic>{'packet_code': packetCode};
    if (bagCode != null) data['bag_code'] = bagCode;
    final response = await _dio.post('/supply/packaging-receipts/$receiptId/scan', data: data);
    return _unwrapMap(response.data);
  }

  Future<Map<String, dynamic>> getBagMappingPackets(String mappingId) async {
    final response = await _dio.get('/supply/bag-mappings/$mappingId/packets');
    return _unwrapMap(response.data);
  }

  Future<Map<String, dynamic>> replacePacketV2(
    String receiptId, {
    required String damagedSerial,
    required String replacementSerial,
    required String reason,
  }) async {
    final response = await _dio.post(
      '/supply/packaging-receipts/$receiptId/replace-packet',
      data: {
        'damaged_serial': damagedSerial,
        'replacement_serial': replacementSerial,
        'reason': reason,
      },
    );
    return _unwrapMap(response.data);
  }

  Future<Map<String, dynamic>> removeBagFromReceipt(
    String receiptId,
    String mappingId,
  ) async {
    final response = await _dio.delete(
      '/supply/packaging-receipts/$receiptId/bags/$mappingId',
    );
    return _unwrapMap(response.data);
  }

  Future<void> updateReceiptWarehouse(String receiptId, String warehouseId) async {
    await _dio.patch('/supply/packaging-receipts/$receiptId/warehouse', data: {
      'warehouse_id': warehouseId,
    });
  }

  Future<Map<String, dynamic>> completeReceipt(
    String receiptId, {
    String? mfgDate,
    String? expiryDate,
    String? dateOverrideReason,
  }) async {
    final payload = <String, dynamic>{
      if (mfgDate != null && mfgDate.isNotEmpty) 'mfg_date': mfgDate,
      if (expiryDate != null && expiryDate.isNotEmpty) 'expiry_date': expiryDate,
      if (dateOverrideReason != null && dateOverrideReason.isNotEmpty)
        'date_override_reason': dateOverrideReason,
    };
    final response = await _dio.post(
      '/supply/packaging-receipts/$receiptId/complete',
      data: payload,
    );
    return _unwrapMap(response.data);
  }

  Future<Map<String, dynamic>> cancelReceipt(
    String receiptId, {
    String? reason,
  }) async {
    final payload = <String, dynamic>{
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    };
    final response = await _dio.post(
      '/supply/packaging-receipts/$receiptId/cancel',
      data: payload,
    );
    return _unwrapMap(response.data);
  }

  // --- Pallets ---

  Future<Map<String, dynamic>> batchCreatePallets({
    required int quantity,
    int? maxBags,
    String? prefix,
  }) async {
    final payload = <String, dynamic>{
      'quantity': quantity,
    };
    if (maxBags != null && maxBags > 0) {
      payload['maxBags'] = maxBags;
    }
    if (prefix != null && prefix.trim().isNotEmpty) {
      payload['prefix'] = prefix.trim().toUpperCase();
    }
    final response = await _dio.post('/supply/pallets/batch-create', data: payload);
    return response.data is Map<String, dynamic> ? response.data : {'created': quantity};
  }

  Future<List<dynamic>> getPallets({int page = 1, int limit = 15, String? search, String? status}) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;
    final response = await _dio.get('/supply/pallets', queryParameters: params);
    return response.data is List ? response.data : (response.data['items'] ?? []);
  }

  Future<Map<String, dynamic>> getPalletDetail(String palletId) async {
    final response = await _dio.get('/supply/pallets/$palletId');
    return response.data;
  }

  Future<Map<String, dynamic>> getPalletByCode(String code) async {
    final cleanCode = code.trim();
    final response = await _dio.get(
      '/supply/pallets',
      queryParameters: {'search': cleanCode, 'limit': 20},
    );
    final items = _unwrapItems(response.data);
    final cleanLower = cleanCode.toLowerCase();

    Map<String, dynamic>? exactMatch;
    for (final p in items) {
      if (p is! Map) continue;
      final pCode = (p['palletCode'] ?? p['pallet_code'] ?? p['code'] ?? p['id'] ?? '').toString();
      if (pCode.trim().toLowerCase() == cleanLower) {
        exactMatch = Map<String, dynamic>.from(p);
        break;
      }
    }

    if (exactMatch == null) {
      throw Exception('Không tìm thấy pallet mã "$code".');
    }

    final detailResponse = await _dio.get('/supply/pallets/${exactMatch['id']}');
    return _unwrapMap(detailResponse.data);
  }

  Future<Map<String, dynamic>> linkBagToPallet(String palletId, String bagSerial, {bool force = false}) async {
    final response = await _dio.post('/supply/pallets/$palletId/link-bag', data: {
      'bagSerial': bagSerial,
      if (force) 'force': true,
    });
    return response.data;
  }

  Future<void> unlinkBagFromPallet(String palletId, String bagSerial) async {
    await _dio.post('/supply/pallets/$palletId/unlink-bag', data: {
      'bagSerial': bagSerial,
    });
  }

  // --- Regular Pallets ---

  Future<void> updatePallet(String palletId, Map<String, dynamic> data) async {
    await _dio.patch('/supply/pallets/$palletId', data: data);
  }

  Future<void> deletePallet(String palletId) async {
    await _dio.delete('/supply/pallets/$palletId');
  }



  Future<void> releasePallet(String palletId) async {
    await _dio.post('/supply/pallets/$palletId/release');
  }

  // --- Semi-Finished Pallets (Pallet BTP) ---
  Future<List<dynamic>> getSFPallets({int page = 1, int limit = 15, String? search, String? status}) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;
    final response = await _dio.get('/supply/sf-pallets', queryParameters: params);
    return response.data is List ? response.data : (response.data['items'] ?? []);
  }

  Future<Map<String, dynamic>> getSFPalletDetail(String palletId) async {
    final response = await _dio.get('/supply/sf-pallets/$palletId');
    return response.data;
  }

  Future<Map<String, dynamic>> getSFPalletByCode(String code) async {
    final response = await _dio.get('/supply/sf-pallets', queryParameters: {'search': code, 'limit': 1});
    final items = response.data is List ? response.data : (response.data['items'] ?? []);
    if (items.isEmpty) throw Exception('Không tìm thấy pallet BTP với mã này');
    
    final exactMatch = items.firstWhere(
      (p) => p['palletCode'] == code || p['pallet_code'] == code,
      orElse: () => throw Exception('Không tìm thấy pallet BTP với mã này'),
    );
    
    // Fetch full details
    final detailResponse = await _dio.get('/supply/sf-pallets/${exactMatch['id']}');
    return detailResponse.data;
  }

  Future<Map<String, dynamic>> linkBagToSFPallet(String palletId, String bagSerial, {bool force = false}) async {
    final response = await _dio.post('/supply/sf-pallets/$palletId/link-item', data: {
      'serial': bagSerial,      
      if (force) 'force': true,
    });
    return response.data;
  }

  Future<void> unlinkBagFromSFPallet(String palletId, String bagSerial) async {
    await _dio.post('/supply/sf-pallets/$palletId/unlink-item', data: {
      'itemSerial': bagSerial,
    });
  }

  Future<void> releaseSFPallet(String palletId) async {
    await _dio.post('/supply/sf-pallets/$palletId/release');
  }

  Future<String> uploadImage(XFile file, {String folder = 'batch-docs'}) async {
    final bytes = await file.readAsBytes();
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: file.name),
    });
    final response = await _dio.post('/files/upload', queryParameters: {'folder': folder}, data: formData);
    if (response.data is Map) {
      final map = response.data as Map;
      return (map['url'] ?? map['data']?['url'] ?? map['relative_url'] ?? '').toString();
    }
    return response.data?.toString() ?? '';
  }
}

