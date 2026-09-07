import 'dart:convert';

class GrowingLocation {
  final String id;
  final String name;
  final double lat;
  final double long;
  final double areaM2;
  final String? address;
  final String? province;
  final String? ward;
  final String? code;
  final String? plantType;
  final String? manager;
  final List<List<double>>? boundary;
  final List<List<double>>? pendingBoundary;
  final String? approvalStatus;
  final String? eudrStatus;
  final double? violationRate;
  final String? lastCheckDate;
  final String? masterGrowingAreaId;
  final dynamic masterGrowingArea;
  final dynamic farmer;
  final String? leaderId;
  final dynamic leader;
  final bool isOverlapped;
  final bool isInspected;
  final String? lastInspectionStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GrowingLocation({
    required this.id,
    required this.name,
    required this.lat,
    required this.long,
    this.areaM2 = 0,
    this.address,
    this.province,
    this.ward,
    this.code,
    this.plantType,
    this.manager,
    this.boundary,
    this.pendingBoundary,
    this.approvalStatus,
    this.eudrStatus,
    this.violationRate,
    this.lastCheckDate,
    this.masterGrowingAreaId,
    this.masterGrowingArea,
    this.farmer,
    this.leaderId,
    this.leader,
    this.isOverlapped = false,
    this.isInspected = false,
    this.lastInspectionStatus,
    this.createdAt,
    this.updatedAt,
  });

  factory GrowingLocation.fromJson(Map<String, dynamic> json) {
    // Parse boundary/pendingBoundary from GeoJSON structure
    List<List<double>>? parseBoundary(dynamic poly) {
      if (poly == null) return null;
      try {
        if (poly is String && poly.trim().startsWith('{')) {
          poly = jsonDecode(poly);
        }
        // Standard GeoJSON: { type: 'Polygon', coordinates: [[[lng,lat],...]] }
        if (poly is Map && poly['coordinates'] != null) {
          final outerRing = poly['coordinates'];
          if (outerRing is List && outerRing.isNotEmpty) {
            final coords = outerRing[0] as List;
            return coords
                .map((e) => (e as List).map((v) => (v as num).toDouble()).toList())
                .toList();
          }
        }
        // Fallback: raw array of [lng, lat] pairs
        if (poly is List && poly.isNotEmpty && poly[0] is List) {
          return (poly as List)
              .map((e) => (e as List).map((v) => (v as num).toDouble()).toList())
              .toList();
        }
      } catch (_) {}
      return null;
    }

    DateTime? parseDate(dynamic date) {
      if (date == null) return null;
      if (date is DateTime) return date;
      return DateTime.tryParse(date.toString());
    }

    dynamic coord = json['coordinate'];
    if (coord is String && coord.trim().startsWith('{')) {
      try {
        coord = jsonDecode(coord);
      } catch (_) {}
    }

    final rawLastCheck = json['lastCheckDate']?.toString() ?? json['last_check_date']?.toString() ?? json['lastInspectionDate']?.toString();
    final bool hasLastCheck = rawLastCheck != null && rawLastCheck.isNotEmpty && rawLastCheck != 'null';
    final inspList = json['inspections'] is List ? (json['inspections'] as List) : [];
    final rawInspStatus = json['inspectionStatus']?.toString() ?? 
        json['inspection_status']?.toString() ?? 
        json['lastInspectionStatus']?.toString() ?? 
        (inspList.isNotEmpty && inspList.last is Map ? inspList.last['status']?.toString() : null);

    final bool inspected = json['isInspected'] == true ||
        json['is_inspected'] == true ||
        hasLastCheck ||
        inspList.isNotEmpty ||
        (rawInspStatus != null && rawInspStatus.toUpperCase() != 'PENDING') ||
        json['status'] == 'INSPECTED' ||
        json['status'] == 'PASSED' ||
        json['status'] == 'FAILED';

    return GrowingLocation(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      lat: (coord != null && coord['coordinates'] != null) 
          ? (coord['coordinates'][1] as num).toDouble() 
          : (json['lat'] ?? 0).toDouble(),
      long: (coord != null && coord['coordinates'] != null) 
          ? (coord['coordinates'][0] as num).toDouble() 
          : (json['long'] ?? 0).toDouble(),
      areaM2: (json['areaM2'] ?? 0).toDouble(),
      address: json['address'],
      province: json['province'],
      ward: json['ward'],
      code: json['code'],
      plantType: json['plantType'],
      manager: json['managerName'],
      boundary: parseBoundary(json['boundary']),
      pendingBoundary: parseBoundary(json['pendingBoundary']),
      approvalStatus: json['approvalStatus'],
      eudrStatus: json['eudrStatus'],
      violationRate: (json['violationRate'] as num?)?.toDouble(),
      lastCheckDate: rawLastCheck,
      masterGrowingAreaId: json['masterGrowingAreaId'],
      masterGrowingArea: json['masterGrowingArea'],
      farmer: json['farmer'] ?? json['farmerId'],
      leaderId: json['leaderId'],
      leader: json['leader'],
      isOverlapped: json['isOverlapped'] ?? json['is_overlapped'] ?? false,
      isInspected: inspected,
      lastInspectionStatus: rawInspStatus,
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at'] ?? rawLastCheck),
    );
  }
}
