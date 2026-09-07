class RecallOrder {
  final String id;
  final String code;
  final String status;
  final String productName;
  final Map<String, dynamic>? product;
  final String reason;
  final String severity;
  final int totalAffected;
  final int totalReturned;
  final int totalDisposed;
  final int totalRestocked;
  final DateTime? createdAt;

  RecallOrder({
    required this.id,
    required this.code,
    required this.status,
    required this.productName,
    required this.product,
    required this.reason,
    required this.severity,
    required this.totalAffected,
    required this.totalReturned,
    required this.totalDisposed,
    required this.totalRestocked,
    this.createdAt,
  });

  factory RecallOrder.fromJson(Map<String, dynamic> json) {
    final product = json['product'] is Map<String, dynamic>
        ? json['product'] as Map<String, dynamic>
        : (json['product'] is Map ? Map<String, dynamic>.from(json['product'] as Map) : null);
    final productName = _productName(product, json);

    return RecallOrder(
      id: (json['id'] ?? json['recallId'] ?? json['code']).toString(),
      code: (json['code'] ?? json['recallCode'] ?? json['id']).toString(),
      status: (json['status'] ?? '').toString(),
      productName: productName,
      product: product,
      reason: _reasonText(json),
      severity: (json['severity'] ?? json['class'] ?? '').toString(),
      totalAffected: _intValue(json['totalAffected'] ?? json['totalAffectedCount'] ?? json['affectedCount']),
      totalReturned: _intValue(json['totalReturned'] ?? json['returnedCount']),
      totalDisposed: _intValue(json['totalDisposed'] ?? json['disposedCount']),
      totalRestocked: _intValue(json['totalRestocked'] ?? json['restockedCount']),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
    );
  }
}

class RecallItem {
  final String id;
  final String serial;
  final String status;
  final String? warehouseId;

  RecallItem({required this.id, required this.serial, required this.status, this.warehouseId});

  factory RecallItem.fromJson(Map<String, dynamic> json) {
    return RecallItem(
      id: (json['id'] ?? json['itemId'] ?? json['serial']).toString(),
      serial: (json['serial'] ?? json['code'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      warehouseId: (json['warehouseId'] ?? json['warehouse_id'])?.toString(),
    );
  }
}

int _intValue(dynamic value) {
  return int.tryParse((value ?? 0).toString()) ?? 0;
}

String _productName(Map<String, dynamic>? product, Map<String, dynamic> json) {
  final direct = json['productName'];
  if (direct is String && direct.trim().isNotEmpty) {
    return direct.trim();
  }

  if (product != null) {
    final candidates = [product['name'], product['productName'], product['title']];
    for (final candidate in candidates) {
      if (candidate != null && candidate.toString().trim().isNotEmpty) {
        return candidate.toString().trim();
      }
    }
  }

  return '';
}

String _reasonText(Map<String, dynamic> json) {
  final candidates = [json['reason'], json['recallReason'], json['alertReason'], json['description']];
  for (final candidate in candidates) {
    if (candidate == null) continue;
    final text = candidate.toString().trim();
    if (text.isEmpty) continue;
    if (_looksLikeProductLog(text)) continue;
    return text;
  }
  return '';
}

bool _looksLikeProductLog(String text) {
  final lower = text.toLowerCase();
  return lower.contains('createdat:') ||
      lower.contains('updatedat:') ||
      lower.contains('gpcbrickcode') ||
      lower.contains('ndasyncstatus') ||
      lower.contains('description:') ||
      lower.contains('<p>') ||
      lower.contains('<div>');
}
