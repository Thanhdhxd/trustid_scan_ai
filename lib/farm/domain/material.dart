class FarmMaterial {
  final String id;
  final String name;
  final String type;
  final String unit;
  final double stockQuantity;
  final String? code;
  bool isActive;
  final String? description;

  FarmMaterial({
    required this.id,
    required this.name,
    required this.type,
    required this.unit,
    required this.stockQuantity,
    this.code,
    this.isActive = true,
    this.description,
  });

  factory FarmMaterial.fromJson(Map<String, dynamic> json) {
    return FarmMaterial(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'OTHER',
      unit: json['unit'] ?? '',
      stockQuantity: double.tryParse(json['stockQuantity']?.toString() ?? '0') ?? 0.0,
      code: json['code'],
      isActive: json['isActive'] ?? true,
      description: json['description'],
    );
  }

  String get typeLabel {
    switch (type) {
      case 'FERTILIZER': return 'Phân bón';
      case 'PESTICIDE': return 'Thuốc BVTV';
      case 'SEED': return 'Giống';
      default: return 'Khác';
    }
  }
}
