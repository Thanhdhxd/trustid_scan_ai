import 'bag_mapping.dart';

class Pallet {
  final String id;
  final String palletCode;
  final String status;
  final int maxBags;
  final int currentBagCount;
  final List<PalletBagMapping> bagMappings;
  final DateTime? createdAt;

  Pallet({
    required this.id,
    required this.palletCode,
    this.status = 'EMPTY',
    this.maxBags = 50,
    this.currentBagCount = 0,
    this.bagMappings = const [],
    this.createdAt,
  });

  factory Pallet.fromJson(Map<String, dynamic> json) {
    return Pallet(
      id: json['id'] ?? '',
      palletCode: json['palletCode'] ?? json['pallet_code'] ?? '',
      status: json['status'] ?? 'EMPTY',
      maxBags: json['maxBags'] ?? json['max_bags'] ?? json['maxBatches'] ?? json['max_batches'] ?? json['capacity'] ?? json['maxCapacity'] ?? json['max_capacity'] ?? json['limit'] ?? json['maxItems'] ?? json['max_items'] ?? 50,
      currentBagCount: json['currentBagCount'] ?? json['current_bag_count'] ?? json['currentBatchCount'] ?? json['current_batch_count'] ?? json['itemCount'] ?? json['item_count'] ?? 0,
      bagMappings: ((json['bagMappings'] ?? json['items']) as List?)
          ?.map<PalletBagMapping>((e) => PalletBagMapping.fromJson(e as Map<String, dynamic>))
          .toList() ?? <PalletBagMapping>[],
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
    );
  }

  double get fillPercent => maxBags > 0 ? currentBagCount / maxBags : 0;
  bool get isFull => currentBagCount >= maxBags;
}

class PalletBagMapping {
  final String id;
  final String bagSerial;
  final String? bagQrCode;
  final String? productName;
  final int? packetCount;
  final String? linkerName;
  final DateTime? linkedAt;

  PalletBagMapping({
    required this.id,
    required this.bagSerial,
    this.bagQrCode,
    this.productName,
    this.packetCount,
    this.linkerName,
    this.linkedAt,
  });

  factory PalletBagMapping.fromJson(Map<String, dynamic> json) {
    return PalletBagMapping(
      id: json['id'] ?? '',
      bagSerial: json['bagSerial'] ?? json['bag_serial'] ?? json['itemSerial'] ?? json['item_serial'] ?? '',
      bagQrCode: json['bagQrCode'] ?? json['bag_qr_code'],
      productName: json['productName'] ?? json['product_name'],
      packetCount: json['packetCount'] ?? json['packet_count'],
      linkerName: json['linker']?['fullName'] ?? json['linkerName'],
      linkedAt: json['linkedAt'] != null ? DateTime.tryParse(json['linkedAt']) : null,
    );
  }
}
