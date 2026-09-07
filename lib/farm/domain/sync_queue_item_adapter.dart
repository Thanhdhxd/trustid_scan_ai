import 'package:hive/hive.dart';
import 'sync_queue_item.dart';

class SyncQueueItemAdapter extends TypeAdapter<SyncQueueItem> {
  @override
  final int typeId = 11;

  @override
  SyncQueueItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    
    final rawPhotos = fields[3] as List?;
    final rawMaterials = fields[4] as List?;

    return SyncQueueItem(
      taskId: fields[0] as String,
      status: fields[1] as String,
      notes: fields[2] as String?,
      evidencePhotos: rawPhotos != null ? List<String>.from(rawPhotos) : null,
      materialsUsed: rawMaterials != null
          ? rawMaterials.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : null,
      createdAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SyncQueueItem obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.taskId)
      ..writeByte(1)
      ..write(obj.status)
      ..writeByte(2)
      ..write(obj.notes)
      ..writeByte(3)
      ..write(obj.evidencePhotos)
      ..writeByte(4)
      ..write(obj.materialsUsed)
      ..writeByte(5)
      ..write(obj.createdAt);
  }
}
