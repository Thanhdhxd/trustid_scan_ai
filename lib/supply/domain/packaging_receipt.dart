import 'bag_mapping.dart';
import 'supply_json_utils.dart';

/// Phiếu Đóng Bao (`BAG_PACKAGING` — `PackagingReceipt`).
class PackagingReceipt {
  final String id;
  final String receiptCode;
  final String orderId;
  final String? packerId;
  final String? packerName;
  final String? warehouseId;
  final String? warehouseName;
  final String? batchId;
  final String status; // PACKING | COMPLETED | CANCELLED
  final int totalBags;
  final int totalPackets;
  final DateTime? packingTime;
  final DateTime? mfgDate;
  final DateTime? expiryDate;
  final DateTime? createdAt;
  final List<BagMapping> bags;

  const PackagingReceipt({
    required this.id,
    required this.receiptCode,
    this.orderId = '',
    this.packerId,
    this.packerName,
    this.warehouseId,
    this.warehouseName,
    this.batchId,
    this.status = 'PACKING',
    this.totalBags = 0,
    this.totalPackets = 0,
    this.packingTime,
    this.mfgDate,
    this.expiryDate,
    this.createdAt,
    this.bags = const [],
  });

  factory PackagingReceipt.fromJson(Map<String, dynamic> json) {
    final packer = asSupplyMap(json['packer'] ?? json['createdBy']);
    final warehouse = asSupplyMap(json['warehouse']);
    final rawBags = asSupplyMapList(json['bags'] ?? json['linkedBags']);

    return PackagingReceipt(
      id: (json['id'] ?? json['receiptId'] ?? '').toString(),
      receiptCode: (json['receiptCode'] ?? json['receipt_code'] ?? json['code'] ?? '').toString(),
      orderId: (json['orderId'] ?? json['order_id'] ?? '').toString(),
      packerId: parseSupplyString(json['packerId'] ?? json['packer_id'] ?? packer?['id']),
      packerName: parseSupplyString(packer?['fullName'] ?? packer?['name'] ?? json['packerName']),
      warehouseId: parseSupplyString(json['warehouseId'] ?? json['warehouse_id'] ?? warehouse?['id']),
      warehouseName: parseSupplyString(warehouse?['name'] ?? json['warehouseName']),
      batchId: parseSupplyString(json['batchId'] ?? json['batch_id']),
      status: (json['status'] ?? 'PACKING').toString().toUpperCase(),
      totalBags: parseSupplyInt(json['totalBags'] ?? json['total_bags'], rawBags.length),
      totalPackets: parseSupplyInt(json['totalPackets'] ?? json['total_packets']),
      packingTime: parseSupplyDate(json['packingTime'] ?? json['packing_time']),
      mfgDate: parseSupplyDate(json['mfgDate'] ?? json['mfg_date']),
      expiryDate: parseSupplyDate(json['expiryDate'] ?? json['expiry_date']),
      createdAt: parseSupplyDate(json['createdAt'] ?? json['created_at']),
      bags: rawBags.map(BagMapping.fromJson).toList(),
    );
  }

  bool get isPacking => status == 'PACKING';
  bool get isCompleted => status == 'COMPLETED';
  bool get isCancelled => status == 'CANCELLED';
}

/// Thông tin từng mã gói trong một bao (`GET /supply/bag-mappings/:id/packets`).
class BagPacketItem {
  final int stt;
  final String serial;
  final String codeString;
  final String qrCode;
  final String status; // ACTIVE | REPLACED | REPLACEMENT
  final DateTime? scannedAt;

  const BagPacketItem({
    required this.stt,
    required this.serial,
    required this.codeString,
    required this.qrCode,
    this.status = 'ACTIVE',
    this.scannedAt,
  });

  factory BagPacketItem.fromJson(Map<String, dynamic> json) {
    final serial = (json['serial'] ?? '').toString();
    final codeStr = (json['codeString'] ?? json['code_string'] ?? serial).toString();
    return BagPacketItem(
      stt: parseSupplyInt(json['stt']),
      serial: serial,
      codeString: codeStr,
      qrCode: (json['qrCode'] ?? json['qr_code'] ?? codeStr).toString(),
      status: (json['status'] ?? 'ACTIVE').toString().toUpperCase(),
      scannedAt: parseSupplyDate(json['scannedAt'] ?? json['scanned_at']),
    );
  }
}

/// Dữ liệu chi tiết các gói và lịch sử thay gói trong một bao.
class BagPacketDetail {
  final BagMapping? mapping;
  final List<BagPacketItem> packets;
  final List<Map<String, dynamic>> replacements;

  const BagPacketDetail({
    this.mapping,
    this.packets = const [],
    this.replacements = const [],
  });

  factory BagPacketDetail.fromJson(Map<String, dynamic> json) {
    final mappingMap = asSupplyMap(json['mapping']);
    return BagPacketDetail(
      mapping: mappingMap != null ? BagMapping.fromJson(mappingMap) : null,
      packets: asSupplyMapList(json['packets']).map(BagPacketItem.fromJson).toList(),
      replacements: asSupplyMapList(json['replacements']),
    );
  }
}
