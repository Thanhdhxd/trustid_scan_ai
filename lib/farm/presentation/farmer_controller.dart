import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/utils/state_provider.dart';
import '../domain/farming_task.dart';
import '../domain/crop_cycle.dart';
import '../domain/location.dart';
import '../domain/material.dart';
import '../data/farm_repository.dart';

final materialsProvider = FutureProvider.autoDispose<List<FarmMaterial>>((ref) async {
  return ref.watch(farmRepositoryProvider).getMaterials();
});

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final selectedDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  return DateTimeRange(
    start: DateTime(now.year, now.month, now.day),
    end: DateTime(now.year, now.month, now.day),
  );
});

// Filter providers
final selectedLocationIdProvider = StateProvider<String?>((ref) => null);
final selectedLocationNameProvider = StateProvider<String?>((ref) => null);
final selectedCycleIdProvider = StateProvider<String?>((ref) => null);
final selectedCycleNameProvider = StateProvider<String?>((ref) => null);

// Data providers for filter dropdowns
final diaryLocationsProvider = FutureProvider.autoDispose<List<GrowingLocation>>((ref) async {
  final repo = ref.watch(farmRepositoryProvider);
  return repo.getLocations();
});

final diaryCyclesProvider = FutureProvider.autoDispose<List<CropCycle>>((ref) async {
  final repo = ref.watch(farmRepositoryProvider);
  return repo.getCycles();
});

// Fetch all tasks then filter client-side by locationName/cycleName
final dailyTasksProvider = FutureProvider.autoDispose<List<FarmingTask>>((ref) async {
  final repo = ref.watch(farmRepositoryProvider);
  final locationName = ref.watch(selectedLocationNameProvider);
  final cycleName = ref.watch(selectedCycleNameProvider);

  final tasks = await repo.getDailyTasks();

  var filtered = tasks;
  if (locationName != null) {
    filtered = filtered.where((t) => t.locationName == locationName).toList();
  }
  if (cycleName != null) {
    filtered = filtered.where((t) => t.cycleName == cycleName).toList();
  }

  return filtered;
});
