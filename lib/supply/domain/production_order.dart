import 'packaging_receipt.dart';
import 'production_ticket.dart';
import 'supply_json_utils.dart';

/// Khối tổng hợp trạng thái và tiến độ thực thi từ API `GET /supply/production-orders/:id`.
class OrderSummary {
  final int packedBags;
  final int packedPackets;
  final int activeScannedPackets;
  final int committedPackets;
  final double remainingWeightKg;
  final int unlinkedBagsCount;
  final bool hasCompletedReceiptOrTicket;
  final bool canCreateReceipt;
  final bool canCancel;
  final bool canComplete;

  const OrderSummary({
    this.packedBags = 0,
    this.packedPackets = 0,
    this.activeScannedPackets = 0,
    this.committedPackets = 0,
    this.remainingWeightKg = 0.0,
    this.unlinkedBagsCount = 0,
    this.hasCompletedReceiptOrTicket = false,
    this.canCreateReceipt = false,
    this.canCancel = false,
    this.canComplete = false,
  });

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    return OrderSummary(
      packedBags: parseSupplyInt(json['packedBags'] ?? json['packed_bags']),
      packedPackets: parseSupplyInt(json['packedPackets'] ?? json['packed_packets']),
      activeScannedPackets: parseSupplyInt(
        json['activeScannedPackets'] ?? json['active_scanned_packets'],
      ),
      committedPackets: parseSupplyInt(
        json['committedPackets'] ?? json['committed_packets'],
      ),
      remainingWeightKg: parseSupplyDouble(
        json['remainingWeightKg'] ?? json['remaining_weight_kg'],
      ),
      unlinkedBagsCount: parseSupplyInt(
        json['unlinkedBagsCount'] ?? json['unlinked_bags_count'],
      ),
      hasCompletedReceiptOrTicket: parseSupplyBool(
        json['hasCompletedReceiptOrTicket'] ?? json['has_completed_receipt_or_ticket'],
      ),
      canCreateReceipt: parseSupplyBool(
        json['canCreateReceipt'] ?? json['can_create_receipt'],
      ),
      canCancel: parseSupplyBool(json['canCancel'] ?? json['can_cancel']),
      canComplete: parseSupplyBool(json['canComplete'] ?? json['can_complete']),
    );
  }
}

/// Lệnh Sản Xuất (`STANDARD` hoặc `BAG_PACKAGING`).
class ProductionOrder {
  final String id;
  final String orderCode;
  final String orderType; // STANDARD | BAG_PACKAGING
  final String? sourceType; // FARM | EXTERNAL | CROSS_TENANT | SEMI_FINISHED
  final String? productName;
  final String? productSku;
  final String? productId;
  final String? warehouseId;
  final String? warehouseName;
  final String? outputBatchId;
  final String? outputBatchCode;
  final String? packetPoolId;
  final String? bagPoolId;
  final double plannedWeightKg;
  final double actualWeightKg;
  final double unitWeightKg;
  final int plannedUnits;
  final int actualUnits;
  final int packagingSpec;
  final int sparePacketQuantity;
  final int spareBagQuantity;
  final int totalBags;
  final int linkedBags;
  final String status;
  final String? closeType;
  final String? stopReasonCode;
  final String? stopNote;
  final String? remainderAction;
  final double lossWeightKg;
  final String? lossReason;
  final String? cancelReason;
  final String? creatorName;
  final String? notes;
  final DateTime? plannedDate;
  final DateTime? mfgDate;
  final DateTime? expiryDate;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? createdAt;
  final List<ProductionTicket> tickets;
  final List<PackagingReceipt> packagingReceipts;
  final OrderSummary? summary;

  ProductionOrder({
    required this.id,
    required this.orderCode,
    this.orderType = 'BAG_PACKAGING',
    this.sourceType,
    this.productName,
    this.productSku,
    this.productId,
    this.warehouseId,
    this.warehouseName,
    this.outputBatchId,
    this.outputBatchCode,
    this.packetPoolId,
    this.bagPoolId,
    this.plannedWeightKg = 0.0,
    this.actualWeightKg = 0.0,
    this.unitWeightKg = 0.0,
    this.plannedUnits = 0,
    this.actualUnits = 0,
    this.packagingSpec = 0,
    this.sparePacketQuantity = 0,
    this.spareBagQuantity = 0,
    this.totalBags = 0,
    this.linkedBags = 0,
    this.status = 'CODES_READY',
    this.closeType,
    this.stopReasonCode,
    this.stopNote,
    this.remainderAction,
    this.lossWeightKg = 0.0,
    this.lossReason,
    this.cancelReason,
    this.creatorName,
    this.notes,
    this.plannedDate,
    this.mfgDate,
    this.expiryDate,
    this.completedAt,
    this.cancelledAt,
    this.createdAt,
    this.tickets = const [],
    this.packagingReceipts = const [],
    this.summary,
  });

  factory ProductionOrder.fromJson(Map<String, dynamic> json) {
    final product = asSupplyMap(json['product']);
    final warehouse = asSupplyMap(json['warehouse']);
    final outputBatch = asSupplyMap(json['outputBatch'] ?? json['output_batch']);
    final creator = asSupplyMap(json['creator']);
    final summaryMap = asSupplyMap(json['summary']);
    final parsedSummary = summaryMap != null ? OrderSummary.fromJson(summaryMap) : null;

    final spec = parseSupplyInt(json['packagingSpec'] ?? json['packaging_spec']);
    final pUnits = parseSupplyInt(json['plannedUnits'] ?? json['planned_units']);
    final aUnits = parseSupplyInt(json['actualUnits'] ?? json['actual_units']);
    final pWeight = parseSupplyDouble(json['plannedWeightKg'] ?? json['planned_weight_kg']);
    final aWeight = parseSupplyDouble(json['actualWeightKg'] ?? json['actual_weight_kg']);
    final computedBags = (spec > 0 && pUnits > 0) ? (pUnits / spec).ceil() : 0;

    final rawTotalBags = parseSupplyIntNullable(
      json['totalBags'] ?? json['total_bags'] ?? json['bagQty'] ?? json['bag_qty'],
    );
    final rawLinkedBags = parseSupplyIntNullable(
      json['linkedBags'] ?? json['linked_bags'],
    );
    final totalBagsVal = rawTotalBags ?? computedBags;

    // Endpoint danh sách GET /supply/production-orders không trả summary hay linkedBags,
    // nên suy ra số bao đã đóng từ actualUnits / packagingSpec (hoặc tỷ lệ khối lượng).
    int? computedPackedBags;
    if (spec > 0 && aUnits > 0) {
      final bags = (aUnits / spec).ceil();
      computedPackedBags = totalBagsVal > 0 ? bags.clamp(0, totalBagsVal) : bags;
    } else if (totalBagsVal > 0 && pWeight > 0 && aWeight > 0) {
      computedPackedBags = ((aWeight / pWeight) * totalBagsVal)
          .round()
          .clamp(0, totalBagsVal);
    }

    return ProductionOrder(
      id: (json['id'] ?? '').toString(),
      orderCode: (json['orderCode'] ?? json['order_code'] ?? '').toString(),
      orderType: (json['orderType'] ?? json['order_type'] ?? 'BAG_PACKAGING')
          .toString()
          .toUpperCase(),
      sourceType: parseSupplyString(json['sourceType'] ?? json['source_type']),
      productName: parseSupplyString(json['productName'] ?? product?['name']),
      productSku: parseSupplyString(product?['sku'] ?? product?['gtin']),
      productId: parseSupplyString(json['productId'] ?? json['product_id'] ?? product?['id']),
      warehouseId: parseSupplyString(
        json['warehouseId'] ?? json['warehouse_id'] ?? warehouse?['id'],
      ),
      warehouseName: parseSupplyString(warehouse?['name'] ?? json['warehouseName']),
      outputBatchId: parseSupplyString(
        json['outputBatchId'] ?? json['output_batch_id'] ?? outputBatch?['id'],
      ),
      outputBatchCode: parseSupplyString(
        outputBatch?['batchCode'] ?? outputBatch?['batch_code'],
      ),
      packetPoolId: parseSupplyString(json['packetPoolId'] ?? json['packet_pool_id']),
      bagPoolId: parseSupplyString(json['bagPoolId'] ?? json['bag_pool_id']),
      plannedWeightKg: pWeight,
      actualWeightKg: aWeight,
      unitWeightKg: parseSupplyDouble(json['unitWeightKg'] ?? json['unit_weight_kg']),
      plannedUnits: pUnits,
      actualUnits: aUnits,
      packagingSpec: spec,
      sparePacketQuantity: parseSupplyInt(
        json['sparePacketQuantity'] ?? json['spare_packet_quantity'],
      ),
      spareBagQuantity: parseSupplyInt(
        json['spareBagQuantity'] ?? json['spare_bag_quantity'],
      ),
      totalBags: totalBagsVal,
      linkedBags: rawLinkedBags ?? parsedSummary?.packedBags ?? computedPackedBags ?? 0,
      status: (json['status'] ?? 'CODES_READY').toString().toUpperCase(),
      closeType: parseSupplyString(json['closeType'] ?? json['close_type']),
      stopReasonCode: parseSupplyString(
        json['stopReasonCode'] ?? json['stop_reason_code'],
      ),
      stopNote: parseSupplyString(json['stopNote'] ?? json['stop_note']),
      remainderAction: parseSupplyString(
        json['remainderAction'] ?? json['remainder_action'],
      ),
      lossWeightKg: parseSupplyDouble(
        json['lossWeightKg'] ?? json['loss_weight_kg'],
      ),
      lossReason: parseSupplyString(json['lossReason'] ?? json['loss_reason']),
      cancelReason: parseSupplyString(
        json['cancelReason'] ?? json['cancel_reason'],
      ),
      creatorName: parseSupplyString(
        creator?['fullName'] ?? creator?['full_name'] ?? creator?['username'],
      ),
      notes: parseSupplyString(json['notes']),
      plannedDate: parseSupplyDate(json['plannedDate'] ?? json['planned_date']),
      mfgDate: parseSupplyDate(
        json['mfgDate'] ?? json['mfg_date'] ?? outputBatch?['mfgDate'],
      ),
      expiryDate: parseSupplyDate(
        json['expiryDate'] ?? json['expiry_date'] ?? outputBatch?['expiryDate'],
      ),
      completedAt: parseSupplyDate(json['completedAt'] ?? json['completed_at']),
      cancelledAt: parseSupplyDate(json['cancelledAt'] ?? json['cancelled_at']),
      createdAt: parseSupplyDate(json['createdAt'] ?? json['created_at']),
      tickets: asSupplyMapList(json['tickets'])
          .map(ProductionTicket.fromJson)
          .toList(),
      packagingReceipts: asSupplyMapList(
        json['packagingReceipts'] ?? json['packaging_receipts'],
      ).map(PackagingReceipt.fromJson).toList(),
      summary: parsedSummary,
    );
  }

  bool get isBagPackaging => orderType == 'BAG_PACKAGING';
  bool get isStandard => orderType == 'STANDARD';
  bool get isGenerating => status == 'GENERATING';
  bool get isGenerationFailed => status == 'GENERATION_FAILED';
  bool get isCompleted => status == 'COMPLETED';
  bool get isCancelled => status == 'CANCELLED';

  double get progress {
    if (isBagPackaging && totalBags > 0) return linkedBags / totalBags;
    if (plannedUnits > 0) return actualUnits / plannedUnits;
    if (plannedWeightKg > 0) return actualWeightKg / plannedWeightKg;
    return 0;
  }

  bool get isComplete {
    if (isBagPackaging && totalBags > 0) return linkedBags >= totalBags;
    if (plannedUnits > 0) return actualUnits >= plannedUnits;
    return false;
  }

  /// Trạng thái hiển thị theo tiến độ thực thi
  String get displayStatus {
    final s = status.toUpperCase();
    if (s == 'CANCELLED' ||
        s == 'DRAFT' ||
        s == 'GENERATING' ||
        s == 'GENERATION_FAILED' ||
        s == 'COMPLETED') {
      return s;
    }
    if (totalBags > 0 && linkedBags < totalBags) return 'IN_PROGRESS';
    if (isComplete) return 'IN_PROGRESS';
    return s;
  }

  ProductionOrder copyWith({
    String? id,
    String? orderCode,
    String? orderType,
    String? sourceType,
    String? productName,
    String? productSku,
    String? productId,
    String? warehouseId,
    String? warehouseName,
    String? outputBatchId,
    String? outputBatchCode,
    String? packetPoolId,
    String? bagPoolId,
    double? plannedWeightKg,
    double? actualWeightKg,
    double? unitWeightKg,
    int? plannedUnits,
    int? actualUnits,
    int? packagingSpec,
    int? sparePacketQuantity,
    int? spareBagQuantity,
    int? totalBags,
    int? linkedBags,
    String? status,
    String? closeType,
    String? stopReasonCode,
    String? notes,
    DateTime? plannedDate,
    DateTime? mfgDate,
    DateTime? expiryDate,
    DateTime? createdAt,
    List<ProductionTicket>? tickets,
    List<PackagingReceipt>? packagingReceipts,
    OrderSummary? summary,
  }) {
    return ProductionOrder(
      id: id ?? this.id,
      orderCode: orderCode ?? this.orderCode,
      orderType: orderType ?? this.orderType,
      sourceType: sourceType ?? this.sourceType,
      productName: productName ?? this.productName,
      productSku: productSku ?? this.productSku,
      productId: productId ?? this.productId,
      warehouseId: warehouseId ?? this.warehouseId,
      warehouseName: warehouseName ?? this.warehouseName,
      outputBatchId: outputBatchId ?? this.outputBatchId,
      outputBatchCode: outputBatchCode ?? this.outputBatchCode,
      packetPoolId: packetPoolId ?? this.packetPoolId,
      bagPoolId: bagPoolId ?? this.bagPoolId,
      plannedWeightKg: plannedWeightKg ?? this.plannedWeightKg,
      actualWeightKg: actualWeightKg ?? this.actualWeightKg,
      unitWeightKg: unitWeightKg ?? this.unitWeightKg,
      plannedUnits: plannedUnits ?? this.plannedUnits,
      actualUnits: actualUnits ?? this.actualUnits,
      packagingSpec: packagingSpec ?? this.packagingSpec,
      sparePacketQuantity: sparePacketQuantity ?? this.sparePacketQuantity,
      spareBagQuantity: spareBagQuantity ?? this.spareBagQuantity,
      totalBags: totalBags ?? this.totalBags,
      linkedBags: linkedBags ?? this.linkedBags,
      status: status ?? this.status,
      closeType: closeType ?? this.closeType,
      stopReasonCode: stopReasonCode ?? this.stopReasonCode,
      notes: notes ?? this.notes,
      plannedDate: plannedDate ?? this.plannedDate,
      mfgDate: mfgDate ?? this.mfgDate,
      expiryDate: expiryDate ?? this.expiryDate,
      createdAt: createdAt ?? this.createdAt,
      tickets: tickets ?? this.tickets,
      packagingReceipts: packagingReceipts ?? this.packagingReceipts,
      summary: summary ?? this.summary,
    );
  }
}
