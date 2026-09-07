import 'location.dart';
import 'template.dart';

class CropCycle {
  final String id;
  final String name;
  final String status;
  final DateTime? startDate;
  final String? locationId;
  final String? templateId;
  final String? locationName;
  final String? templateProduct;
  final String? product;
  final GrowingLocation? location;
  final ProcessTemplate? template;
  final List<String> productNames;
  final List<String> productIds;

  CropCycle({
    required this.id,
    required this.name,
    required this.status,
    this.startDate,
    this.locationId,
    this.templateId,
    this.locationName,
    this.templateProduct,
    this.product,
    this.location,
    this.template,
    this.productNames = const [],
    this.productIds = const [],
  });

  factory CropCycle.fromJson(Map<String, dynamic> json) {
    return CropCycle(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? json['cycleId']?.toString() ?? json['cycle_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      startDate: (json['startDate'] ?? json['start_date']) != null 
          ? DateTime.tryParse((json['startDate'] ?? json['start_date']).toString()) 
          : null,
      locationId: json['locationId']?.toString() ?? json['location_id']?.toString(),
      templateId: json['templateId']?.toString() ?? json['template_id']?.toString(),
      locationName: json['locationName']?.toString() ?? json['location_name']?.toString() ?? json['location_name_cache']?.toString(),
      templateProduct: json['templateProduct']?.toString() ?? json['template_product']?.toString(),
      product: json['product']?.toString() ?? json['productName']?.toString(),
      location: json['location'] != null ? GrowingLocation.fromJson(json['location']) : null,
      template: json['template'] != null ? ProcessTemplate.fromJson(json['template']) : null,
      productNames: _extractProductNames(json),
      productIds: _extractProductIds(json),
    );
  }

  static List<String> _extractProductIds(Map<String, dynamic> json) {
    List<String> ids = [];
    if (json['cycleProducts'] != null && json['cycleProducts'] is List) {
      for (var cp in json['cycleProducts']) {
        if (cp['productId'] != null) {
          ids.add(cp['productId'].toString());
        } else if (cp['product_id'] != null) {
          ids.add(cp['product_id'].toString());
        }
      }
    }
    return ids;
  }

  static List<String> _extractProductNames(Map<String, dynamic> json) {
    List<String> names = [];
    if (json['cycleProducts'] != null && json['cycleProducts'] is List) {
      for (var cp in json['cycleProducts']) {
        if (cp['product'] != null && cp['product']['name'] != null) {
          names.add(cp['product']['name'].toString());
        }
      }
    }
    return names;
  }
}

class HarvestBatch {
  final String id;
  final String batchCode;
  final String status;
  final double quantityKg;
  final double? remainingQuantityKg;
  final DateTime? harvestDate;
  final CropCycle? cropCycle;
  final String? productName;

  HarvestBatch({
    required this.id,
    required this.batchCode,
    required this.status,
    required this.quantityKg,
    this.remainingQuantityKg,
    this.harvestDate,
    this.cropCycle,
    this.productName,
  });

  factory HarvestBatch.fromJson(Map<String, dynamic> json) {
    return HarvestBatch(
      id: json['id']?.toString() ?? '',
      batchCode: json['batchCode']?.toString() ?? json['batch_code']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      quantityKg: (json['quantityKg'] ?? json['quantity_kg'] as num?)?.toDouble() ?? 0.0,
      remainingQuantityKg: (json['remainingQuantityKg'] ?? json['remaining_quantity_kg'] as num?)?.toDouble(),
      harvestDate: (json['harvestDate'] ?? json['harvest_date']) != null 
          ? DateTime.tryParse((json['harvestDate'] ?? json['harvest_date']).toString()) 
          : null,
      cropCycle: json['cropCycle'] != null ? CropCycle.fromJson(json['cropCycle']) : null,
      productName: json['product'] != null ? json['product']['name']?.toString() : null,
    );
  }
}
