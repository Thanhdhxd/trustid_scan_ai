class SyncQueueItem {
  final String taskId;
  final String status;
  final String? notes;
  final List<String>? evidencePhotos;
  final List<Map<String, dynamic>>? materialsUsed;
  final DateTime createdAt;

  SyncQueueItem({
    required this.taskId,
    required this.status,
    this.notes,
    this.evidencePhotos,
    this.materialsUsed,
    required this.createdAt,
  });
}
