class ProcessTaskConfig {
  final String stage;
  final int dayOffset;
  final String title;
  final String? description;
  final bool isMandatory;
  final String jobType;
  final List<String> materialIds;
  final List<String> suggestedMaterials;

  ProcessTaskConfig({
    required this.stage,
    required this.dayOffset,
    required this.title,
    this.description,
    required this.isMandatory,
    required this.jobType,
    required this.materialIds,
    this.suggestedMaterials = const [],
  });

  factory ProcessTaskConfig.fromJson(Map<String, dynamic> json) {
    return ProcessTaskConfig(
      stage: json['stage'] ?? 'Giai đoạn chung',
      dayOffset: (json['day_offset'] as num?)?.toInt() ?? 0,
      title: json['title'] ?? '',
      description: json['description'],
      isMandatory: json['is_mandatory'] ?? false,
      jobType: json['job_type'] ?? '',
      materialIds: (json['material_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      suggestedMaterials: (json['suggested_materials'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stage': stage,
      'day_offset': dayOffset,
      'title': title,
      'description': description,
      'is_mandatory': isMandatory,
      'job_type': jobType,
      'material_ids': materialIds,
      'suggested_materials': suggestedMaterials,
    };
  }
}

class ProcessTemplate {
  final String id;
  final String name;
  final String product;
  final bool isActive;
  final List<ProcessTaskConfig> tasksConfig;

  ProcessTemplate({
    required this.id,
    required this.name,
    this.product = 'Nông sản',
    required this.isActive,
    required this.tasksConfig,
  });

  factory ProcessTemplate.fromJson(Map<String, dynamic> json) {
    return ProcessTemplate(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      product: json['product'] ?? 'Nông sản',
      isActive: json['isActive'] ?? true,
      tasksConfig: (json['tasksConfig'] as List<dynamic>?)
              ?.map((e) => ProcessTaskConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'product': product,
      'isActive': isActive,
      'tasksConfig': tasksConfig.map((e) => e.toJson()).toList(),
    };
  }
}
