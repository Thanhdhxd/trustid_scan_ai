class ExportOrderItem {
  final String id;
  final String productId;
  final Map<String, dynamic>? product;
  final int expectedQuantity;
  final int scannedQuantity;
  final String? notes;
  final String? unitName;
  final int conversionFactor;

  ExportOrderItem({
    required this.id,
    required this.productId,
    this.product,
    required this.expectedQuantity,
    this.scannedQuantity = 0,
    this.notes,
    this.unitName,
    this.conversionFactor = 1,
  });

  factory ExportOrderItem.fromJson(Map<String, dynamic> json) {
    return ExportOrderItem(
      id: json['id'] ?? '',
      productId: json['productId'] ?? '',
      product: json['product'],
      expectedQuantity: json['expectedQuantity'] ?? 0,
      scannedQuantity: json['scannedQuantity'] ?? 0,
      notes: json['notes'],
      unitName: json['unitName'],
      conversionFactor: json['conversionFactor'] ?? 1,
    );
  }
}

class ExportOrder {
  final String id;
  final String orderCode;
  final String dealerId;
  final String? dealerName;
  final String sourceWarehouseId;
  final String? warehouseName;
  final String? expectedDeliveryDate;
  final String priority;
  final String? notes;
  final String status;
  final List<ExportOrderItem> items;
  final String? createdAt;
  final String? updatedAt;

  ExportOrder({
    required this.id,
    required this.orderCode,
    required this.dealerId,
    this.dealerName,
    required this.sourceWarehouseId,
    this.warehouseName,
    this.expectedDeliveryDate,
    this.priority = 'MEDIUM',
    this.notes,
    this.status = 'DRAFT',
    this.items = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory ExportOrder.fromJson(Map<String, dynamic> json) {
    return ExportOrder(
      id: json['id'] ?? '',
      orderCode: json['orderCode'] ?? '',
      dealerId: json['dealerId'] ?? '',
      dealerName: json['dealerName'] ?? json['dealer_name'] ?? (json['dealer'] is Map ? json['dealer']['name'] : null),
      sourceWarehouseId: json['sourceWarehouseId'] ?? '',
      warehouseName: json['warehouseName'] ?? json['sourceWarehouseName'] ?? json['warehouse_name'] ?? (json['sourceWarehouse'] is Map ? json['sourceWarehouse']['name'] : null),
      expectedDeliveryDate: json['expectedDeliveryDate'],
      priority: json['priority'] ?? 'MEDIUM',
      notes: json['notes'],
      status: json['status'] ?? 'DRAFT',
      items: (json['items'] as List?)
              ?.map((e) => ExportOrderItem.fromJson(e))
              .toList() ??
          [],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }
}

