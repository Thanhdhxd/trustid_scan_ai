import 'supply_json_utils.dart';

/// Một lượt quét mã QR gói trong Phiếu Đóng Gói (`ProductionTicket`).
class ProductionTicketScan {
  final String id;
  final String? codeItemId;
  final String serialNumber;
  final String codeString;
  final DateTime? scannedAt;
  final String? scannerId;
  final String? scannerName;
  final String? scannerUsername;

  const ProductionTicketScan({
    required this.id,
    this.codeItemId,
    required this.serialNumber,
    required this.codeString,
    this.scannedAt,
    this.scannerId,
    this.scannerName,
    this.scannerUsername,
  });

  factory ProductionTicketScan.fromJson(Map<String, dynamic> json) {
    final scanner = asSupplyMap(json['scanner']);
    final serial = (json['serialNumber'] ?? json['serial_number'] ?? '').toString();
    return ProductionTicketScan(
      id: (json['id'] ?? '').toString(),
      codeItemId: parseSupplyString(json['codeItemId'] ?? json['code_item_id']),
      serialNumber: serial,
      codeString: (json['codeString'] ?? json['code_string'] ?? serial).toString(),
      scannedAt: parseSupplyDate(json['scannedAt'] ?? json['scanned_at']),
      scannerId: parseSupplyString(scanner?['id'] ?? json['scannedBy'] ?? json['scanned_by']),
      scannerName: parseSupplyString(scanner?['fullName'] ?? json['scannerName']),
      scannerUsername: parseSupplyString(scanner?['username']),
    );
  }
}

/// Phiếu Đóng Gói Tiêu chuẩn (`STANDARD` — `ProductionTicket`).
class ProductionTicket {
  final String id;
  final String ticketCode;
  final String orderId;
  final String ticketType;
  final String status; // OPEN | IN_PROGRESS | COMPLETED | REJECTED
  final String? operatorId;
  final String? operatorName;
  final double plannedWeightKg;
  final double actualWeightKg;
  final int actualUnits;
  final int scannedUnits;
  final double scannedWeightKg;
  final String? outputBatchId;
  final DateTime? mfgDate;
  final DateTime? expiryDate;
  final String? rejectionReason;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final List<ProductionTicketScan> scannedSerials;

  const ProductionTicket({
    required this.id,
    required this.ticketCode,
    this.orderId = '',
    this.ticketType = 'PACKAGING',
    this.status = 'OPEN',
    this.operatorId,
    this.operatorName,
    this.plannedWeightKg = 0.0,
    this.actualWeightKg = 0.0,
    this.actualUnits = 0,
    this.scannedUnits = 0,
    this.scannedWeightKg = 0.0,
    this.outputBatchId,
    this.mfgDate,
    this.expiryDate,
    this.rejectionReason,
    this.startedAt,
    this.completedAt,
    this.createdAt,
    this.scannedSerials = const [],
  });

  factory ProductionTicket.fromJson(Map<String, dynamic> json) {
    final op = asSupplyMap(json['operator']);
    final rawScans = asSupplyMapList(
      json['scannedSerials'] ?? json['scanned_serials'] ?? json['scans'],
    );
    final scans = rawScans.map(ProductionTicketScan.fromJson).toList();
    final parsedScannedUnits = parseSupplyInt(
      json['scannedUnits'] ?? json['scanned_units'],
      scans.length,
    );

    return ProductionTicket(
      id: (json['id'] ?? '').toString(),
      ticketCode: (json['ticketCode'] ?? json['ticket_code'] ?? '').toString(),
      orderId: (json['orderId'] ?? json['order_id'] ?? '').toString(),
      ticketType: (json['ticketType'] ?? json['ticket_type'] ?? 'PACKAGING').toString(),
      status: (json['status'] ?? 'OPEN').toString().toUpperCase(),
      operatorId: parseSupplyString(json['operatorId'] ?? json['operator_id'] ?? op?['id']),
      operatorName: parseSupplyString(op?['fullName'] ?? op?['username'] ?? json['operatorName']),
      plannedWeightKg: parseSupplyDouble(json['plannedWeightKg'] ?? json['planned_weight_kg']),
      actualWeightKg: parseSupplyDouble(json['actualWeightKg'] ?? json['actual_weight_kg']),
      actualUnits: parseSupplyInt(json['actualUnits'] ?? json['actual_units']),
      scannedUnits: parsedScannedUnits,
      scannedWeightKg: parseSupplyDouble(
        json['scannedWeightKg'] ?? json['scanned_weight_kg'],
        parseSupplyDouble(json['actualWeightKg'] ?? json['actual_weight_kg']),
      ),
      outputBatchId: parseSupplyString(json['outputBatchId'] ?? json['output_batch_id']),
      mfgDate: parseSupplyDate(json['mfgDate'] ?? json['mfg_date']),
      expiryDate: parseSupplyDate(json['expiryDate'] ?? json['expiry_date']),
      rejectionReason: parseSupplyString(json['rejectionReason'] ?? json['rejection_reason']),
      startedAt: parseSupplyDate(json['startedAt'] ?? json['started_at']),
      completedAt: parseSupplyDate(json['completedAt'] ?? json['completed_at']),
      createdAt: parseSupplyDate(json['createdAt'] ?? json['created_at']),
      scannedSerials: scans,
    );
  }

  bool get isOpen => status == 'OPEN' || status == 'IN_PROGRESS';
  bool get isCompleted => status == 'COMPLETED';
  bool get isRejected => status == 'REJECTED';
}
