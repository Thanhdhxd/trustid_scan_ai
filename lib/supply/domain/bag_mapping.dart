import 'supply_json_utils.dart';

/// Thông tin một bao (nhóm mã gói) đã liên kết trong phiếu đóng bao.
class BagMapping {
  final String id;
  final int groupIndex;
  final String bagSerial;
  final String? bagQrCode;
  final String? packetSerialStart;
  final String? packetSerialEnd;
  final int packetCount;
  final String? productName;
  final String? lotStatus;
  final DateTime? scannedAt;
  final DateTime? linkedAt;
  final String? linkerName;
  final String? linkerUsername;

  BagMapping({
    required this.id,
    this.groupIndex = 0,
    required this.bagSerial,
    this.bagQrCode,
    this.packetSerialStart,
    this.packetSerialEnd,
    this.packetCount = 0,
    this.productName,
    this.lotStatus,
    this.scannedAt,
    this.linkedAt,
    this.linkerName,
    this.linkerUsername,
  });

  factory BagMapping.fromJson(Map<String, dynamic> json) {
    final linker = asSupplyMap(json['linker']);
    return BagMapping(
      id: (json['id'] ?? '').toString(),
      groupIndex: parseSupplyInt(json['groupIndex'] ?? json['group_index']),
      bagSerial: (json['bagSerial'] ?? json['bag_serial'] ?? '').toString(),
      bagQrCode: parseSupplyString(json['bagQrCode'] ?? json['bag_qr_code']),
      packetSerialStart: parseSupplyString(
        json['packetSerialStart'] ?? json['packet_serial_start'],
      ),
      packetSerialEnd: parseSupplyString(
        json['packetSerialEnd'] ?? json['packet_serial_end'],
      ),
      packetCount: parseSupplyInt(json['packetCount'] ?? json['packet_count']),
      productName: parseSupplyString(json['productName'] ?? json['product_name']),
      lotStatus: parseSupplyString(json['lotStatus'] ?? json['lot_status']),
      scannedAt: parseSupplyDate(json['scannedAt'] ?? json['scanned_at']),
      linkedAt: parseSupplyDate(json['linkedAt'] ?? json['linked_at']),
      linkerName: parseSupplyString(linker?['fullName'] ?? json['linkerName']),
      linkerUsername: parseSupplyString(linker?['username']),
    );
  }
}
