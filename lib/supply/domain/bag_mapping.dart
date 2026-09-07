class BagMapping {
  final String id;
  final String bagSerial;
  final String? bagQrCode;
  final int packetCount;
  final String? productName;
  final String? lotStatus;
  final DateTime? linkedAt;
  final String? linkerName;

  BagMapping({
    required this.id,
    required this.bagSerial,
    this.bagQrCode,
    this.packetCount = 0,
    this.productName,
    this.lotStatus,
    this.linkedAt,
    this.linkerName,
  });

  factory BagMapping.fromJson(Map<String, dynamic> json) {
    return BagMapping(
      id: json['id'] ?? '',
      bagSerial: json['bagSerial'] ?? json['bag_serial'] ?? '',
      bagQrCode: json['bagQrCode'] ?? json['bag_qr_code'],
      packetCount: json['packetCount'] ?? json['packet_count'] ?? 0,
      productName: json['productName'] ?? json['product_name'],
      lotStatus: json['lotStatus'] ?? json['lot_status'],
      linkedAt: json['linkedAt'] != null ? DateTime.tryParse(json['linkedAt']) : null,
      linkerName: json['linker']?['fullName'] ?? json['linkerName'],
    );
  }
}
