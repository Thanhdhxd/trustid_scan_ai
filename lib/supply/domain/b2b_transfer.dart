class B2BTransfer {
  final String id;
  final String? transferCode;
  final String? status;
  final String? fromTenantId;
  final String? toTenantId;
  final String? fromTenantName;
  final String? toTenantName;
  final String? notes;
  final List<TransferItem> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  B2BTransfer({
    required this.id,
    this.transferCode,
    this.status,
    this.fromTenantId,
    this.toTenantId,
    this.fromTenantName,
    this.toTenantName,
    this.notes,
    this.items = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory B2BTransfer.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] ?? json['transfer_items'] ?? [];
    return B2BTransfer(
      id: json['id'] ?? '',
      transferCode: json['transferCode'] ?? json['transfer_code'],
      status: json['status'],
      fromTenantId: json['fromTenantId'] ?? json['from_tenant_id'],
      toTenantId: json['toTenantId'] ?? json['to_tenant_id'],
      fromTenantName: json['fromTenant']?['name'] ?? json['from_tenant_name'],
      toTenantName: json['toTenant']?['name'] ?? json['to_tenant_name'],
      notes: json['notes'],
      items: rawItems is List
          ? rawItems.map((e) => TransferItem.fromJson(e)).toList()
          : [],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }
}

class TransferItem {
  final String? id;
  final String batchId;
  final double expectedQuantity;
  final double? receivedQuantity;
  final Map<String, dynamic>? batch;
  final List<String>? serials;

  TransferItem({
    this.id,
    required this.batchId,
    required this.expectedQuantity,
    this.receivedQuantity,
    this.batch,
    this.serials,
  });

  String get batchCode => batch?['batchCode'] ?? batch?['batch_code'] ?? batchId;

  factory TransferItem.fromJson(Map<String, dynamic> json) {
    return TransferItem(
      id: json['id'],
      batchId: json['batchId'] ?? json['batch_id'] ?? '',
      expectedQuantity: _toDouble(json['expectedQuantity'] ?? json['expected_quantity']) ?? 0,
      receivedQuantity: _toDouble(json['receivedQuantity'] ?? json['received_quantity']),
      batch: json['batch'] is Map<String, dynamic> ? json['batch'] : null,
      serials: json['serials'] is List
          ? (json['serials'] as List).map((e) => e.toString()).toList()
          : null,
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
