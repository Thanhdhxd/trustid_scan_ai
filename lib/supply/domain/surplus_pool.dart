class SurplusProduct {
  final String id;
  final String name;
  final String? sku;
  final String? code;

  const SurplusProduct({
    required this.id,
    required this.name,
    this.sku,
    this.code,
  });

  factory SurplusProduct.fromJson(Map<String, dynamic> json) {
    return SurplusProduct(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'N/A',
      sku: json['sku']?.toString(),
      code: json['code']?.toString(),
    );
  }
}

class SurplusEntry {
  final String id;
  final String? sourceBatchCode;
  final String? sourceOrderId;
  final String? sourceOrderCode;
  final double inputWeightKg;
  final double outputWeightKg;
  final double calculatedWeightKg;
  final double actualWeightKg;
  final double lossWeightKg;
  final String status; // AVAILABLE, USED, EXPIRED
  final DateTime? createdAt;
  final DateTime? expiresAt;

  const SurplusEntry({
    required this.id,
    this.sourceBatchCode,
    this.sourceOrderId,
    this.sourceOrderCode,
    required this.inputWeightKg,
    required this.outputWeightKg,
    required this.calculatedWeightKg,
    required this.actualWeightKg,
    required this.lossWeightKg,
    required this.status,
    this.createdAt,
    this.expiresAt,
  });

  factory SurplusEntry.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    final orderObj = json['sourceOrder'] is Map ? json['sourceOrder'] as Map<String, dynamic> : null;
    final batchObj = orderObj?['sourceBatch'] is Map ? orderObj!['sourceBatch'] as Map<String, dynamic> : null;

    final batchCode = json['sourceBatchCode']?.toString() ??
        batchObj?['batchCode']?.toString() ??
        orderObj?['orderCode']?.toString();

    final orderCode = orderObj?['orderCode']?.toString() ?? json['sourceOrderId']?.toString();

    return SurplusEntry(
      id: json['id']?.toString() ?? '',
      sourceBatchCode: batchCode,
      sourceOrderId: json['sourceOrderId']?.toString(),
      sourceOrderCode: orderCode,
      inputWeightKg: parseNum(json['inputWeightKg'] ?? json['input_weight_kg']),
      outputWeightKg: parseNum(json['outputWeightKg'] ?? json['output_weight_kg']),
      calculatedWeightKg: parseNum(json['calculatedWeightKg'] ?? json['calculated_weight_kg']),
      actualWeightKg: parseNum(json['actualWeightKg'] ?? json['actual_weight_kg']),
      lossWeightKg: parseNum(json['lossWeightKg'] ?? json['loss_weight_kg']),
      status: json['status']?.toString().toUpperCase() ?? 'AVAILABLE',
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      expiresAt: parseDate(json['expiresAt'] ?? json['expires_at']),
    );
  }

  bool get isExpiringSoon {
    if (expiresAt == null) return false;
    final diff = expiresAt!.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 3;
  }

  bool get isExpired {
    if (status == 'EXPIRED') return true;
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}

class SurplusPool {
  final String id;
  final String productId;
  final SurplusProduct? product;
  final double availableWeightKg;
  final double totalWeightKg;
  final double totalLossKg;
  final int expiryDays;
  final int availableEntryCount;
  final List<SurplusEntry> entries;

  const SurplusPool({
    required this.id,
    required this.productId,
    this.product,
    required this.availableWeightKg,
    required this.totalWeightKg,
    required this.totalLossKg,
    required this.expiryDays,
    required this.availableEntryCount,
    this.entries = const [],
  });

  factory SurplusPool.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    int parseInt(dynamic v, [int fallback = 30]) {
      if (v == null) return fallback;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    final productJson = json['product'] is Map ? json['product'] as Map<String, dynamic> : null;
    final entriesRaw = json['entries'] is List ? json['entries'] as List : [];

    return SurplusPool(
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString() ?? json['product_id']?.toString() ?? '',
      product: productJson != null ? SurplusProduct.fromJson(productJson) : null,
      availableWeightKg: parseNum(json['availableWeightKg'] ?? json['available_weight_kg']),
      totalWeightKg: parseNum(json['totalWeightKg'] ?? json['total_weight_kg']),
      totalLossKg: parseNum(json['totalLossKg'] ?? json['total_loss_kg']),
      expiryDays: parseInt(json['expiryDays'] ?? json['expiry_days'], 30),
      availableEntryCount: parseInt(json['availableEntryCount'] ?? json['available_entry_count'], 0),
      entries: entriesRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => SurplusEntry.fromJson(e))
          .toList(),
    );
  }

  SurplusPool copyWith({
    String? id,
    String? productId,
    SurplusProduct? product,
    double? availableWeightKg,
    double? totalWeightKg,
    double? totalLossKg,
    int? expiryDays,
    int? availableEntryCount,
    List<SurplusEntry>? entries,
  }) {
    return SurplusPool(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      product: product ?? this.product,
      availableWeightKg: availableWeightKg ?? this.availableWeightKg,
      totalWeightKg: totalWeightKg ?? this.totalWeightKg,
      totalLossKg: totalLossKg ?? this.totalLossKg,
      expiryDays: expiryDays ?? this.expiryDays,
      availableEntryCount: availableEntryCount ?? this.availableEntryCount,
      entries: entries ?? this.entries,
    );
  }
}
