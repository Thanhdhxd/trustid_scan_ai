class MasterGrowingArea {
  final String id;
  final String code;
  final String name;
  final double maxAreaM2;
  final String? province;
  final String? ward;
  final String? address;
  final String? ownerName;
  final String? managerName;
  final String? plantType;
  final String status;
  final List<dynamic>? leaders;
  final List<dynamic>? kcsStaffs;
  final List<dynamic>? locations;

  MasterGrowingArea({
    required this.id,
    required this.code,
    required this.name,
    required this.maxAreaM2,
    this.province,
    this.ward,
    this.address,
    this.ownerName,
    this.managerName,
    this.plantType,
    required this.status,
    this.leaders,
    this.kcsStaffs,
    this.locations,
  });

  factory MasterGrowingArea.fromJson(Map<String, dynamic> json) {
    return MasterGrowingArea(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      maxAreaM2: (json['maxAreaM2'] ?? 0).toDouble(),
      province: json['province'],
      ward: json['ward'],
      address: json['address'],
      ownerName: json['ownerName'],
      managerName: json['managerName'],
      plantType: json['plantType'],
      status: json['status'] ?? 'ACTIVE',
      leaders: json['leaders'] ?? [],
      kcsStaffs: json['kcsStaffs'] ?? [],
      locations: json['locations'] ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'maxAreaM2': maxAreaM2,
      'province': province,
      'ward': ward,
      'address': address,
      'ownerName': ownerName,
      'managerName': managerName,
      'plantType': plantType,
      'status': status,
      'leaders': leaders,
      'kcsStaffs': kcsStaffs,
    };
  }
}
