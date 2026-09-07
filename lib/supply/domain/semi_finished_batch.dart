class SemiFinishedBatch {
  final String id;
  final String batchCode;
  final String? batchType;
  final String? status;
  final String? productId;
  final Map<String, dynamic>? product;
  final double? totalQuantity;
  final double? availableQuantity;
  final double? inputWeight;
  final double? outputWeight;
  final double? lossPercentage;
  final int? packCount;
  final double? packageWeight;
  final String? farmBatchCode;
  final Map<String, dynamic>? sourceInfo;
  final Map<String, dynamic>? parentBatch;
  final String? warehouseId;
  final Map<String, dynamic>? warehouse;
  final DateTime? createdAt;

  SemiFinishedBatch({
    required this.id,
    required this.batchCode,
    this.batchType,
    this.status,
    this.productId,
    this.product,
    this.totalQuantity,
    this.availableQuantity,
    this.inputWeight,
    this.outputWeight,
    this.lossPercentage,
    this.packCount,
    this.packageWeight,
    this.farmBatchCode,
    this.sourceInfo,
    this.parentBatch,
    this.warehouseId,
    this.warehouse,
    this.createdAt,
  });

  String get productName => product?['name'] ?? 'Chưa rõ sản phẩm';

  double get availableKg => availableQuantity ?? 0;

  factory SemiFinishedBatch.fromJson(Map<String, dynamic> json) {
    return SemiFinishedBatch(
      id: json['id'] ?? '',
      batchCode: json['batchCode'] ?? json['batch_code'] ?? '',
      batchType: json['batchType'] ?? json['batch_type'],
      status: json['status'],
      productId: json['productId'] ?? json['product_id'],
      product: json['product'] is Map<String, dynamic> ? json['product'] : null,
      totalQuantity: _toDouble(json['totalQuantity'] ?? json['total_quantity']),
      availableQuantity: _toDouble(json['availableQuantity'] ?? json['available_quantity']),
      inputWeight: _toDouble(json['inputWeight'] ?? json['input_weight']),
      outputWeight: _toDouble(json['outputWeight'] ?? json['output_weight']),
      lossPercentage: _toDouble(json['lossPercentage'] ?? json['loss_percentage']),
      packCount: _toInt(json['packCount'] ?? json['pack_count']),
      packageWeight: _toDouble(json['packageWeight'] ?? json['package_weight']),
      farmBatchCode: json['farmBatchCode'] ?? json['farm_batch_code'],
      sourceInfo: json['sourceInfo'] ?? json['source_info'],
      parentBatch: json['parentBatch'] ?? json['parent_batch'],
      warehouseId: json['warehouseId'] ?? json['warehouse_id'],
      warehouse: json['warehouse'] is Map<String, dynamic> ? json['warehouse'] : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }
}
