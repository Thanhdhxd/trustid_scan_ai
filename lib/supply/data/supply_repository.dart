import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/api_client.dart';
import '../domain/shipment.dart';

final supplyRepositoryProvider = Provider((ref) => SupplyRepository(companyApi));

class SupplyRepository {
  final Dio _dio;
  SupplyRepository(this._dio);

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

  Future<List<dynamic>> getProducts() async {
    final response = await _dio.get('/products');
    return response.data is List ? response.data : (response.data['items'] ?? response.data['data'] ?? []);
  }

  Future<Map<String, dynamic>> createProductionOrder(Map<String, dynamic> data) async {
    final response = await _dio.post('/supply/production-orders', data: data);
    return response.data is Map<String, dynamic> ? response.data : {'data': response.data};
  }

  Future<Map<String, dynamic>> createBagOrder(Map<String, dynamic> data) async {
    final response = await _dio.post('/supply/production-orders/bag-packaging', data: data);
    return response.data is Map<String, dynamic> ? response.data : {'data': response.data};
  }

  Future<Map<String, dynamic>> createBatch(Map<String, dynamic> data) async {
    final response = await _dio.post('/supply/batches', data: data);
    return response.data;
  }

  Future<List<dynamic>> getBatches() async {
    final response = await _dio.get('/supply/batches');
    return response.data is List ? response.data : (response.data['items'] ?? []);
  }

  Future<void> addItems(Map<String, dynamic> data) async {
    await _dio.post('/supply/packaging/add-items', data: data);
  }

  Future<Map<String, dynamic>> getHarvestStats(String harvestCode) async {
    final response = await _dio.get('/supply/packaging/harvest-stats', queryParameters: {'harvestCode': harvestCode});
    return response.data;
  }

  // --- Dealer Management ---
  Future<List<dynamic>> getDealers({int? page, int? limit, String? search}) async {
    final params = <String, dynamic>{};
    if (page != null) params['page'] = page;
    if (limit != null) params['limit'] = limit;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await _dio.get('/dealers', queryParameters: params);
    return response.data is List ? response.data : (response.data['items'] ?? response.data['data'] ?? []);
  }

  Future<Map<String, dynamic>> getDealerDetail(String id) async {
    final response = await _dio.get('/dealers/$id');
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data);
    }
    throw Exception('Invalid dealer detail format: ${response.data.runtimeType}');
  }

  // --- Warehouse Management ---

  Future<List<dynamic>> getWarehouses({int? page, int? limit, String? search}) async {
    final params = <String, dynamic>{};
    if (page != null) params['page'] = page;
    if (limit != null) params['limit'] = limit;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await _dio.get('/supply/warehouses', queryParameters: params);
    return response.data is List ? response.data : (response.data['items'] ?? response.data['data'] ?? []);
  }

  Future<Map<String, dynamic>> createWarehouse(Map<String, dynamic> data) async {
    final response = await _dio.post('/supply/warehouses', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateWarehouse(String id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/supply/warehouses/$id', data: data);
    return response.data;
  }

  Future<void> deleteWarehouse(String id) async {
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
    final response = await _dio.get('/supply/transfers');
    return response.data;
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

  Future<List<dynamic>> getExternalBatches() async {
    final response = await _dio.get('/supply/batches/external');
    return response.data is List ? response.data : [];
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

  Future<void> cancelBatch(String id) async {
    await _dio.post('/supply/batches/$id/cancel');
  }

  Future<Map<String, dynamic>> lookupTenantByCode(String code) async {
    final response = await _dio.get('/tenants/lookup', queryParameters: {'code': code});
    return response.data;
  }

  Future<List<dynamic>> getB2BPartners() async {
    final response = await _dio.get('/supply/b2b-partners');
    return response.data is List ? response.data : [];
  }

  Future<Map<String, dynamic>> createB2BPartner(Map<String, dynamic> data) async {
    final response = await _dio.post('/supply/b2b-partners', data: data);
    return response.data;
  }

  Future<void> removeB2BPartner(String id) async {
    await _dio.delete('/supply/b2b-partners/$id');
  }

  Future<List<dynamic>> searchActiveTenants(String search) async {
    final response = await _dio.get('/tenants/active', queryParameters: {'search': search, 'limit': 15});
    return response.data is List ? response.data : (response.data['items'] ?? response.data['data'] ?? []);
  }

  Future<void> cancelTransfer(String id) async {
    await _dio.post('/supply/transfers/$id/cancel');
  }

  // --- Production Orders (LSX) ---

  Future<List<dynamic>> getProductionOrders({int page = 1, int limit = 15, String? search, String? status}) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;

    final response = await _dio.get('/supply/production-orders', queryParameters: params);
    return response.data is List ? response.data : (response.data['items'] ?? []);
  }

  Future<Map<String, dynamic>> getProductionOrderDetail(String id) async {
    final response = await _dio.get('/supply/production-orders/$id');
    return response.data;
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

  Future<Map<String, dynamic>> linkBagScan(String orderId, String bagCode, String packetCode) async {
    final response = await _dio.post('/supply/production-orders/$orderId/link-bag', data: {
      'bag_code': bagCode,
      'packet_code': packetCode,
    });
    return response.data;
  }

  Future<void> completeProductionOrder(String orderId, {bool? refundUnused}) async {
    await _dio.post(
      '/supply/production-orders/$orderId/complete',
      data: refundUnused != null ? {'refundUnused': refundUnused} : null,
    );
  }

  Future<void> cancelProductionOrder(String orderId) async {
    await _dio.post('/supply/production-orders/$orderId/cancel');
  }

  // --- Packaging Receipt (v6) ---
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

  Future<void> scanBagLinkV6(String receiptId, String packetCode, {String? bagCode}) async {
    final data = <String, dynamic>{'packet_code': packetCode};
    if (bagCode != null) data['bag_code'] = bagCode;
    final response = await _dio.post('/supply/packaging-receipts/$receiptId/scan', data: data);
    return response.data;
  }

  Future<void> updateReceiptWarehouse(String receiptId, String warehouseId) async {
    await _dio.patch('/supply/packaging-receipts/$receiptId/warehouse', data: {
      'warehouse_id': warehouseId,
    });
  }

  Future<void> saveDraftReceipt(String receiptId) async {
    await _dio.post('/supply/packaging-receipts/$receiptId/save-draft');
  }

  Future<void> completeReceipt(String receiptId) async {
    await _dio.post('/supply/packaging-receipts/$receiptId/complete');
  }

  Future<void> reopenReceipt(String receiptId) async {
    await _dio.post('/supply/packaging-receipts/$receiptId/reopen');
  }

  /// Chỉ mở lại khi **phiếu** đang COMPLETED.
  /// Nếu chỉ lệnh SX COMPLETED mà phiếu vẫn PACKING → reopen sẽ 400 (phiếu chưa đóng).
  Future<bool> reopenIfIncompleteBagOrder(String orderId) async {
    try {
      final order = await getProductionOrderDetail(orderId);
      final mappings = await getOrderLotMappings(orderId);
      final linked = mappings.where((m) {
        final s = (m['lotStatus'] ?? m['lot_status'] ?? '').toString().toUpperCase();
        return s == 'LINKED';
      }).length;
      final total = mappings.length;
      final incomplete = total == 0 || linked < total;
      if (!incomplete) return false;

      String? receiptId;
      String receiptStatus = '';

      try {
        final receiptData = await getOrCreateReceipt(orderId);
        receiptId = (receiptData['id'] ??
                receiptData['receiptId'] ??
                receiptData['receipt']?['id'] ??
                receiptData['receipt']?['receiptId'])
            ?.toString();
        receiptStatus =
            (receiptData['receipt']?['status'] ?? receiptData['status'] ?? '').toString().toUpperCase();
      } catch (_) {
        final receipts = order['packagingReceipts'] ?? order['packaging_receipts'];
        if (receipts is List && receipts.isNotEmpty) {
          receiptId = (receipts.first['id'] ?? receipts.first['receiptId'])?.toString();
          receiptStatus = (receipts.first['status'] ?? '').toString().toUpperCase();
        }
      }

      if (receiptId == null || receiptId.isEmpty) return false;

      // Chỉ reopen phiếu đã COMPLETED — phiếu đang PACKING gọi reopen sẽ 400
      if (receiptStatus != 'COMPLETED') {
        print('Skip reopen: receipt status=$receiptStatus (order=${order['status']})');
        return false;
      }

      await reopenReceipt(receiptId);
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] ?? e.message)
          : e.message;
      print('Reopen receipt failed: $msg');
      return false;
    } catch (e) {
      print('Reopen receipt failed: $e');
      return false;
    }
  }

  // --- Pallets ---

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
    // Không dùng /by-code/ vì backend không hỗ trợ, ta sẽ tải list và lọc
    var response = await _dio.get('/supply/pallets', queryParameters: {'limit': 1000});
    var items = response.data is List ? response.data : (response.data['items'] ?? []);
    
    final cleanCode = code.trim().toLowerCase();
    
    // Thu thập danh sách mã để debug nếu lỗi
    List<String> availableCodes = [];
    
    final exactMatch = (items as List).firstWhere(
      (p) {
        final pCode = (p['code'] ?? p['palletCode'] ?? p['pallet_code'] ?? p['id'] ?? '').toString();
        availableCodes.add(pCode);
        return pCode.trim().toLowerCase() == cleanCode;
      },
      orElse: () => null,
    );
    
    if (exactMatch == null) {
      throw Exception('Không tìm thấy pallet mã "$code". Danh sách hiện có: ${availableCodes.take(5).join(", ")}...');
    }
    
    // Fetch full details
    final detailResponse = await _dio.get('/supply/pallets/${exactMatch['id']}');
    return detailResponse.data;
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
}
