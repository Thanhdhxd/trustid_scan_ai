class Product {
  final String id;
  final String name;
  final String? gtinCode;
  final num? price;
  final String? status;
  final String? netWeight;
  final String? weightUnit;
  final String? defaultPackagingSpec; // Update this to String to simplify parsing
  final String? categoryName;
  final String? categoryId;
  final List<String> images;
  final String? tenantName;
  final String? gpcCode;
  final num? expiryDuration;
  final String? expiryUnit;
  final String? shortDescription;
  final String? description;
  final Map<String, dynamic>? attributes;
  final List<dynamic>? packagingUnits;

  Product({
    required this.id,
    required this.name,
    this.gtinCode,
    this.price,
    this.status,
    this.netWeight,
    this.weightUnit,
    this.defaultPackagingSpec,
    this.categoryName,
    this.categoryId,
    this.images = const [],
    this.tenantName,
    this.gpcCode,
    this.expiryDuration,
    this.expiryUnit,
    this.shortDescription,
    this.description,
    this.attributes,
    this.packagingUnits,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      gtinCode: json['gtinCode'],
      price: json['price'] != null ? num.tryParse(json['price'].toString()) : null,
      status: json['status'],
      netWeight: json['netWeight']?.toString(),
      weightUnit: json['weightUnit'],
      defaultPackagingSpec: json['defaultPackagingSpec']?.toString(),
      categoryName: json['category'] != null ? json['category']['name'] : null,
      categoryId: json['categoryId'] ?? (json['category'] != null ? json['category']['id'] : null),
      images: (json['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      tenantName: json['tenant'] != null ? json['tenant']['name'] : null,
      gpcCode: json['gpcCode'],
      expiryDuration: json['expiryDuration'] != null ? num.tryParse(json['expiryDuration'].toString()) : null,
      expiryUnit: json['expiryUnit'],
      shortDescription: json['shortDescription'],
      description: json['description'],
      attributes: json['attributes'] is Map ? Map<String, dynamic>.from(json['attributes']) : null,
      packagingUnits: json['packagingUnits'] is List ? List<dynamic>.from(json['packagingUnits']) : null,
    );
  }
}
