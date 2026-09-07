class Shipment {
  final String id;
  final String trackingCode;
  final String senderId;
  final String receiverId;
  final String driverId;
  final String vehiclePlate;
  final String status;
  final String? dealerName;
  final String? dealerContactName;
  final String? dealerPhone;
  final String? sourceWarehouseName;
  final String? externalDriverName;
  final String? externalDriverPhone;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime? createdAt;
  final String? dealerAddress;
  final List<ShipmentItem> expectedItems;

  final String? signature;
  final String? evidenceUrl;

  Shipment({
    required this.id,
    required this.trackingCode,
    required this.senderId,
    required this.receiverId,
    required this.driverId,
    required this.vehiclePlate,
    required this.status,
    this.dealerName,
    this.dealerContactName,
    this.dealerPhone,
    this.sourceWarehouseName,
    this.externalDriverName,
    this.externalDriverPhone,
    this.startTime,
    this.endTime,
    this.createdAt,
    this.dealerAddress,
    this.expectedItems = const [],
    this.signature,
    this.evidenceUrl,
  });

  factory Shipment.fromJson(Map<String, dynamic> json) {
    String? signature = json['signature'];
    String? evidenceUrl = json['evidenceUrl'] ?? json['evidence_url'];

    final logsList = json['logs'] ?? json['events'] ?? json['history'] ?? [];
    if (logsList is List) {
      for (final log in logsList) {
        if (log['step'] == 'DRIVER_DELIVER' || log['action'] == 'DRIVER_DELIVER') {
          if (signature == null || signature.isEmpty) {
            signature = log['signatureUrl']?.toString() ?? log['signature_url']?.toString();
          }
          if (evidenceUrl == null || evidenceUrl.isEmpty) {
            final photos = log['evidencePhotos'] ?? log['evidence_photos'] ?? [];
            if (photos is List && photos.isNotEmpty) {
              evidenceUrl = photos.first.toString();
            }
          }
        }
      }
    }

    return Shipment(
      id: json['id'],
      trackingCode: json['trackingCode'] ?? 'UNKNOWN',
      senderId: json['senderId'] ?? '',
      receiverId: json['receiverId'] ?? '',
      driverId: json['driverId'] ?? '',
      vehiclePlate: json['vehiclePlate'] ?? '',
      status: json['status'] ?? 'CREATED',
      dealerName: json['dealer']?['name'],
      dealerContactName: json['dealer']?['contactPerson'],
      dealerPhone: json['dealer']?['phone'],
      dealerAddress: json['dealer']?['address'],
      sourceWarehouseName: json['sourceWarehouse']?['name'],
      externalDriverName: json['externalDriverName'],
      externalDriverPhone: json['externalDriverPhone'],
      startTime: json['startTime'] != null ? DateTime.tryParse(json['startTime']) : null,
      endTime: json['endTime'] != null ? DateTime.tryParse(json['endTime']) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      expectedItems: (json['expectedItems'] as List?)
          ?.map((e) => ShipmentItem.fromJson(e))
          .toList() ?? [],
      signature: signature,
      evidenceUrl: evidenceUrl,
    );
  }
}

class ShipmentItem {
  final String productId;
  final String productName;
  final int quantity;

  ShipmentItem({required this.productId, required this.productName, required this.quantity});

  factory ShipmentItem.fromJson(Map<String, dynamic> json) {
    return ShipmentItem(
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? '',
      quantity: json['quantity'] ?? 0,
    );
  }
}
