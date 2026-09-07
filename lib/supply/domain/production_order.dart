class ProductionOrder {
  final String id;
  final String orderCode;
  final String? productName;
  final String? productId;
  final int totalBags;
  final int linkedBags;
  final String status;
  final DateTime? createdAt;

  ProductionOrder({
    required this.id,
    required this.orderCode,
    this.productName,
    this.productId,
    this.totalBags = 0,
    this.linkedBags = 0,
    this.status = 'ACTIVE',
    this.createdAt,
  });

  factory ProductionOrder.fromJson(Map<String, dynamic> json) {
    return ProductionOrder(
      id: json['id'] ?? '',
      orderCode: json['orderCode'] ?? json['order_code'] ?? '',
      productName: json['productName'] ?? json['product']?['name'],
      productId: json['productId'] ?? json['product_id'],
      totalBags: json['totalBags'] ?? json['total_bags'] ?? 0,
      linkedBags: json['linkedBags'] ?? json['linked_bags'] ?? 0,
      status: json['status'] ?? 'ACTIVE',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
    );
  }

  double get progress => totalBags > 0 ? linkedBags / totalBags : 0;
  bool get isComplete => totalBags > 0 && linkedBags >= totalBags;

  /// Trạng thái hiển thị theo tiến độ bao
  String get displayStatus {
    final s = status.toUpperCase();
    if (s == 'CANCELLED' || s == 'DRAFT') return s;
    if (s == 'COMPLETED') return 'COMPLETED';
    if (totalBags > 0 && linkedBags < totalBags) return 'IN_PROGRESS';
    if (isComplete) return 'IN_PROGRESS'; // đủ bao nhưng lệnh chưa đóng phiếu
    return s;
  }

  ProductionOrder copyWith({
    String? id,
    String? orderCode,
    String? productName,
    String? productId,
    int? totalBags,
    int? linkedBags,
    String? status,
    DateTime? createdAt,
  }) {
    return ProductionOrder(
      id: id ?? this.id,
      orderCode: orderCode ?? this.orderCode,
      productName: productName ?? this.productName,
      productId: productId ?? this.productId,
      totalBags: totalBags ?? this.totalBags,
      linkedBags: linkedBags ?? this.linkedBags,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
