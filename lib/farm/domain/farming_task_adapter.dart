import 'package:hive/hive.dart';
import 'farming_task.dart';

class FarmingTaskAdapter extends TypeAdapter<FarmingTask> {
  @override
  final int typeId = 0;

  @override
  FarmingTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FarmingTask(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      dueDate: fields[3] as DateTime,
      status: fields[4] as String,
      jobType: fields[5] as String?,
      locationName: fields[6] as String?,
      cycleName: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FarmingTask obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.dueDate)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.jobType)
      ..writeByte(6)
      ..write(obj.locationName)
      ..writeByte(7)
      ..write(obj.cycleName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FarmingTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
