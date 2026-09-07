import 'package:hive/hive.dart';

class FarmingTask {
  final String id;
  final String title;
  final String description;
  final DateTime dueDate;
  final String status; // PENDING, COMPLETED, SKIPPED
  final String? jobType;
  final String? locationName;
  final String? cycleName;
  final DateTime? completedAt;

  final String? notes;
  final List<String> evidencePhotos;
  final String? assigneeName;
  final String? cropName;

  FarmingTask({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.status,
    this.jobType,
    this.locationName,
    this.cycleName,
    this.completedAt,
    this.notes,
    this.evidencePhotos = const [],
    this.assigneeName,
    this.cropName,
  });

  factory FarmingTask.fromJson(Map<String, dynamic> json) {
    String rawDesc = json['description'] ?? '';
    String parsedNotes = json['notes'] ?? '';
    if (rawDesc.contains('[Note]:')) {
      final parts = rawDesc.split('[Note]:');
      rawDesc = parts[0].trim();
      if (parsedNotes.isEmpty && parts.length > 1) {
        parsedNotes = parts[1].trim();
      }
    }

    String? extractedCropName;
    if (json['cropCycle'] != null) {
      final cc = json['cropCycle'];
      if (cc['cycleProducts'] is List && (cc['cycleProducts'] as List).isNotEmpty) {
        final cpList = cc['cycleProducts'] as List;
        final primary = cpList.firstWhere((cp) => cp['isPrimary'] == true, orElse: () => cpList.first);
        if (primary['product'] != null && primary['product']['name'] != null) {
          extractedCropName = primary['product']['name'];
        }
      }
    }

    String? extractedAssignee;
    if (json['performer'] != null && json['performer'] is Map) {
      extractedAssignee = json['performer']['fullName'] ?? json['performer']['username'] ?? json['performer']['name'];
    }

    return FarmingTask(
      id: json['id'],
      title: json['title'],
      description: rawDesc,
      dueDate: DateTime.parse(json['dueDate']).toLocal(),
      status: json['status'],
      jobType: json['jobType'],
      locationName: json['cropCycle']?['location']?['name'],
      cycleName: json['cropCycle']?['name'],
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']).toLocal() : (json['updatedAt'] != null ? DateTime.parse(json['updatedAt']).toLocal() : null),
      notes: parsedNotes,
      evidencePhotos: json['evidencePhotos'] != null ? List<String>.from(json['evidencePhotos']) : [],
      assigneeName: extractedAssignee,
      cropName: extractedCropName,
    );
  }
}
