import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/core/utils/connectivity_helper.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';
import 'package:trustid_scan_ai/core/services/weather_service.dart';
import 'package:trustid_scan_ai/core/constants/api_constants.dart';
import '../../domain/farming_task.dart';
import '../../domain/crop_cycle.dart';
import '../../domain/location.dart';
import '../../domain/material.dart';
import '../../domain/sync_queue_item.dart';
import '../../services/farm_sync_service.dart';
import '../farmer_controller.dart';
import '../../data/farm_repository.dart';

// --- Constants & Theme synced with Manager/Farmer Home ---
const Color kPrimaryColor = Color(0xFF00875A);       // Verify Green
const Color kBackgroundDark = Color(0xFF0F2B46);      // Trust Navy
const Color kSurfaceDark = Color(0xFF163452);          // Surface card
const Color kTextLight = Color(0xFFE8EDF3);
const Color kTextGray = Color(0xFF94A3B8);

// --- Simulated IoT Stream ---
class IoTData {
  final double soilMoisture;
  final double ec;
  final double ph;

  IoTData(this.soilMoisture, this.ec, this.ph);
}

final iotStreamProvider = StreamProvider.autoDispose<IoTData>((ref) {
  return Stream.periodic(const Duration(seconds: 3), (count) {
    final random = Random();
    double moisture = 65 + random.nextDouble() * 5;
    double ec = 1.2 + random.nextDouble() * 0.3;
    double ph = 6.0 + random.nextDouble() * 0.5;
    return IoTData(moisture, ec, ph);
  });
});

class FarmingDiaryScreen extends ConsumerStatefulWidget {
  const FarmingDiaryScreen({super.key});

  @override
  ConsumerState<FarmingDiaryScreen> createState() => _FarmingDiaryScreenState();
}

class _FarmingDiaryScreenState extends ConsumerState<FarmingDiaryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(farmSyncServiceProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(dailyTasksProvider);
    final weatherAsync = ref.watch(weatherServiceProvider);
    final dateRange = ref.watch(selectedDateRangeProvider);
    final iotAsync = ref.watch(iotStreamProvider);

    return Scaffold(
      backgroundColor: kBackgroundDark,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            backgroundColor: kBackgroundDark,
            expandedHeight: 240,
            toolbarHeight: 0,
            pinned: true,
            floating: false,
            automaticallyImplyLeading: false,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: kBackgroundDark,
                child: _buildFilterBar(ref),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 48),
                  child: _buildHeader(context, ref, weatherAsync, iotAsync),
                ),
              ),
            ),
          ),
        ],
        body: tasksAsync.when(
          data: (tasks) => _buildTaskTimeline(context, tasks, dateRange),
          loading: () => const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
          error: (e, s) {
            String errorMsg = e.toString();
            if (errorMsg.contains('connection error') || errorMsg.contains('XMLHttpRequest') || errorMsg.contains('SocketException')) {
              errorMsg = 'Mất kết nối mạng. Vui lòng kiểm tra lại đường truyền Internet.';
            } else if (errorMsg.startsWith('Exception: ')) {
              errorMsg = errorMsg.replaceFirst('Exception: ', '');
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      errorMsg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimaryColor,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: kSurfaceDark,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            builder: (ctx) => const _ManualDiaryEntrySheet(),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, AsyncValue<WeatherData> weatherAsync, AsyncValue<IoTData> iotAsync) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: kBackgroundDark.withOpacity(0.95),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: kTextGray),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        context.pop();
                      } else {
                        ref.read(authControllerProvider.notifier).logout();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.eco, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TRUSTID', style: TextStyle(color: kPrimaryColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      Row(
                        children: [
                          const Text('Nhật ký điện tử', style: TextStyle(color: kTextLight, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          _buildNetworkIndicator(),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: kTextGray, size: 24),
                      onPressed: () {
                        context.push('/consumer/notifications');
                      },
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildInfoCard(
                  icon: Icons.wb_sunny, iconColor: Colors.orange,
                  label: 'Thời tiết',
                  value: weatherAsync.when(
                    data: (w) => '${w.temperature}°C',
                    loading: () => '--',
                    error: (_,__) => 'N/A'
                  ),
                  subValue: weatherAsync.when(
                     data: (w) => 'Ẩm ${w.humidity}%',
                     loading: () => 'Dataset...',
                     error: (_,__) => ''
                  ),
                ),
                const SizedBox(width: 12),
                _buildInfoCard(
                  icon: Icons.water_drop, iconColor: Colors.blueAccent,
                  label: 'Độ ẩm đất',
                  value: iotAsync.when(
                    data: (d) => '${d.soilMoisture.toStringAsFixed(1)}%',
                    loading: () => '--',
                    error: (_,__) => 'N/A'
                  ),
                  subValue: 'Cảm biến #A1',
                ),
                const SizedBox(width: 12),
                _buildInfoCard(
                  icon: Icons.science, iconColor: Colors.teal,
                  label: 'Độ pH',
                  value: iotAsync.when(
                    data: (d) => d.ph.toStringAsFixed(1),
                    loading: () => '--',
                    error: (_,__) => 'N/A'
                  ),
                  subValue: 'Cảm biến #P2',
                ),
                const SizedBox(width: 12),
                _buildInfoCard(
                  icon: Icons.electric_bolt, iconColor: Colors.amber,
                  label: 'Độ dẫn EC',
                  value: iotAsync.when(
                    data: (d) => '${d.ec.toStringAsFixed(2)} mS',
                    loading: () => '--',
                    error: (_,__) => 'N/A'
                  ),
                  subValue: 'Cảm biến #E3',
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required Color iconColor, required String label, required String value, required String subValue}) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
             children: [
               Icon(icon, color: iconColor, size: 18),
               const SizedBox(width: 6),
               Flexible(
                 child: Text(
                   label.toUpperCase(), 
                   style: const TextStyle(color: kTextGray, fontSize: 10, fontWeight: FontWeight.bold),
                   overflow: TextOverflow.ellipsis,
                 ),
               ), 
             ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: kTextLight, fontSize: 18, fontWeight: FontWeight.bold)),
          Flexible(
            child: Text(
              subValue, 
              style: const TextStyle(color: kTextGray, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkIndicator() {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        final results = snapshot.data ?? [ConnectivityResult.wifi];
        final hasNet = results.any((r) => r != ConnectivityResult.none);
        
        return ValueListenableBuilder<Box<SyncQueueItem>>(
          valueListenable: Hive.box<SyncQueueItem>('farming_sync_queue').listenable(),
          builder: (context, box, _) {
            final queueCount = box.length;
            if (!hasNet) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, color: Colors.orange, size: 12),
                    if (queueCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '$queueCount',
                        style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ]
                  ],
                ),
              );
            }
            
            if (queueCount > 0) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: kPrimaryColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 8, height: 8,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: kPrimaryColor),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$queueCount',
                      style: const TextStyle(color: kPrimaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: kPrimaryColor.withOpacity(0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_done_outlined, color: kPrimaryColor, size: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterBar(WidgetRef ref) {
    final dateRange = ref.watch(selectedDateRangeProvider);
    final selectedLocationName = ref.watch(selectedLocationNameProvider);
    final selectedCycleName = ref.watch(selectedCycleNameProvider);
    final locationsAsync = ref.watch(diaryLocationsProvider);
    final cyclesAsync = ref.watch(diaryCyclesProvider);
    final selectedLocationId = ref.watch(selectedLocationIdProvider);
    final selectedCycleId = ref.watch(selectedCycleIdProvider);

    final hasActiveFilter = selectedLocationName != null || selectedCycleName != null;

    return Container(
      padding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Filter icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hasActiveFilter ? kPrimaryColor.withOpacity(0.15) : kSurfaceDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasActiveFilter ? kPrimaryColor.withOpacity(0.4) : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Icon(
                Icons.filter_list,
                color: hasActiveFilter ? kPrimaryColor : kTextGray,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),

            // Date filter chip
            _buildFilterChip(
              label: dateRange.start == dateRange.end 
                ? 'Ngày: ${DateFormat('dd/MM').format(dateRange.start)}'
                : '${DateFormat('dd/MM').format(dateRange.start)} - ${DateFormat('dd/MM').format(dateRange.end)}',
              icon: Icons.calendar_today,
              isActive: true,
              onTap: () async {
                final range = await showDateRangePicker(
                  context: context,
                  initialDateRange: dateRange,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  helpText: 'CHỌN KHOẢNG THỜI GIAN',
                  cancelText: 'HỦY',
                  confirmText: 'ÁP DỤNG',
                  saveText: 'ÁP DỤNG',
                  fieldStartHintText: 'dd/mm/yyyy',
                  fieldEndHintText: 'dd/mm/yyyy',
                  fieldStartLabelText: 'Từ ngày',
                  fieldEndLabelText: 'Đến ngày',
                  builder: (context, child) {
                    return Theme(
                      data: ThemeData.dark().copyWith(
                        scaffoldBackgroundColor: kBackgroundDark,
                        dialogBackgroundColor: kSurfaceDark,
                        primaryColor: kPrimaryColor,
                        colorScheme: const ColorScheme.dark(
                          primary: kPrimaryColor,
                          onPrimary: Colors.white,
                          surface: kSurfaceDark,
                          onSurface: Colors.white,
                        ),
                        appBarTheme: const AppBarTheme(
                          backgroundColor: kBackgroundDark,
                          foregroundColor: Colors.white,
                        ),
                        textButtonTheme: TextButtonThemeData(
                          style: TextButton.styleFrom(
                            foregroundColor: kPrimaryColor,
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (range != null) {
                  ref.read(selectedDateRangeProvider.notifier).state = range;
                }
              },
            ),
            const SizedBox(width: 8),

            // Location filter chip
            _buildFilterChip(
              label: selectedLocationName ?? 'Vùng trồng',
              icon: Icons.map,
              isActive: selectedLocationName != null,
              onTap: () => _showFilterBottomSheet(
                title: 'Chọn vùng trồng',
                currentValue: selectedLocationId,
                items: locationsAsync,
                onSelect: (id, name) {
                  ref.read(selectedLocationIdProvider.notifier).state = id;
                  ref.read(selectedLocationNameProvider.notifier).state = name;
                },
                itemBuilder: (loc) => {'id': loc.id, 'name': loc.name},
              ),
            ),
            const SizedBox(width: 8),

            // Season filter chip
            _buildFilterChip(
              label: selectedCycleName ?? 'Mùa vụ',
              icon: Icons.grass,
              isActive: selectedCycleName != null,
              onTap: () => _showFilterBottomSheet(
                title: 'Chọn mùa vụ',
                currentValue: selectedCycleId,
                items: cyclesAsync,
                onSelect: (id, name) {
                  ref.read(selectedCycleIdProvider.notifier).state = id;
                  ref.read(selectedCycleNameProvider.notifier).state = name;
                },
                itemBuilder: (cycle) => {'id': cycle.id, 'name': cycle.name},
              ),
            ),

            // Clear all button
            if (hasActiveFilter) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  final now = DateTime.now();
                  ref.read(selectedDateRangeProvider.notifier).state = DateTimeRange(start: DateTime(now.year, now.month, now.day), end: DateTime(now.year, now.month, now.day));
                  ref.read(selectedLocationIdProvider.notifier).state = null;
                  ref.read(selectedLocationNameProvider.notifier).state = null;
                  ref.read(selectedCycleIdProvider.notifier).state = null;
                  ref.read(selectedCycleNameProvider.notifier).state = null;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.clear, color: Colors.redAccent, size: 14),
                      SizedBox(width: 4),
                      Text('Xóa lọc', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? kPrimaryColor.withOpacity(0.15) : kSurfaceDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? kPrimaryColor.withOpacity(0.5) : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? kPrimaryColor : kTextGray, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? kPrimaryColor : kTextGray,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              color: isActive ? kPrimaryColor : kTextGray,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterBottomSheet<T>({
    required String title,
    required String? currentValue,
    required AsyncValue<List<T>> items,
    required void Function(String? id, String? name) onSelect,
    required Map<String, String> Function(T) itemBuilder,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        expand: false,
        builder: (_, scrollController) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kTextGray.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: kTextLight,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: items.when(
                  data: (list) => ListView.builder(
                    controller: scrollController,
                    itemCount: list.length + 1, // +1 for "All" option
                    itemBuilder: (_, index) {
                      if (index == 0) {
                        // "All" option
                        return ListTile(
                          leading: Icon(
                            Icons.all_inclusive,
                            color: currentValue == null ? kPrimaryColor : kTextGray,
                          ),
                          title: Text(
                            'Tất cả',
                            style: TextStyle(
                              color: currentValue == null ? kPrimaryColor : kTextLight,
                              fontWeight: currentValue == null ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing: currentValue == null
                              ? const Icon(Icons.check, color: kPrimaryColor, size: 20)
                              : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            onSelect(null, null);
                          },
                        );
                      }

                      final item = list[index - 1];
                      final data = itemBuilder(item);
                      final id = data['id']!;
                      final name = data['name']!;
                      final isSelected = currentValue == id;

                      return ListTile(
                        title: Text(
                          name,
                          style: TextStyle(
                            color: isSelected ? kPrimaryColor : kTextLight,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: kPrimaryColor, size: 20)
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          onSelect(id, name);
                        },
                      );
                    },
                  ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: kPrimaryColor),
                  ),
                  error: (e, _) => Center(
                    child: Text('Lỗi: $e', style: const TextStyle(color: Colors.redAccent)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskTimeline(BuildContext context, List<FarmingTask> allTasks, DateTimeRange dateRange) {
    final start = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day);
    final end = DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day, 23, 59, 59);

    // 1. Overdue & pending tasks (due before the start of the selected date range)
    final overdueTasks = allTasks.where((t) {
      final isBeforeStart = t.dueDate.isBefore(start);
      final isPending = t.status != 'COMPLETED' && t.status != 'SKIPPED';
      return isBeforeStart && isPending;
    }).toList();

    // 2. Pending tasks inside the date range
    final periodPendingTasks = allTasks.where((t) {
      final inRange = (t.dueDate.isAfter(start) || t.dueDate.isAtSameMomentAs(start)) && t.dueDate.isBefore(end);
      return inRange && t.status != 'COMPLETED' && t.status != 'SKIPPED';
    }).toList();

    // 3. Completed tasks that were due OR completed inside the date range
    final completedTodayTasks = allTasks.where((t) {
      if (t.status != 'COMPLETED') return false;
      final cmpDate = t.completedAt ?? t.dueDate;
      final dueInRange = (t.dueDate.isAfter(start) || t.dueDate.isAtSameMomentAs(start)) && t.dueDate.isBefore(end);
      final cmpInRange = (cmpDate.isAfter(start) || cmpDate.isAtSameMomentAs(start)) && cmpDate.isBefore(end);
      return dueInRange || cmpInRange;
    }).toList();
    
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // --- OVERDUE SECTION ---
        if (overdueTasks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Công việc quá hạn (${overdueTasks.length})', 
                  style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ],
            ),
          ),
          
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: overdueTasks.length,
              separatorBuilder: (ctx, index) => const SizedBox(width: 12),
              itemBuilder: (ctx, index) => _buildOverdueCard(context, overdueTasks[index]),
            ),
          ),
          const SizedBox(height: 24),
          Container(height: 1, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
        ],

        // --- PENDING IN PERIOD SECTION ---
        _buildSectionHeader(
          start == end ? 'Việc cần làm hôm nay' : 'Việc cần làm trong kỳ',
          start == end 
              ? DateFormat('EEEE, dd/MM', 'vi').format(start)
              : '${DateFormat('dd/MM').format(start)} - ${DateFormat('dd/MM').format(end)}',
          icon: Icons.assignment,
          iconColor: kPrimaryColor,
          count: periodPendingTasks.length,
        ),
        if (periodPendingTasks.isEmpty) 
          _buildEmptyMessage('Không còn việc cần làm trong kỳ này 🎉'),
        ...periodPendingTasks.map((task) => _buildTaskCard(context, task)).toList(),
        
        const SizedBox(height: 24),
        Container(height: 1, color: Colors.white.withOpacity(0.05)),
        const SizedBox(height: 16),

        // --- COMPLETED SECTION ---
        _buildSectionHeader(
          'Công việc đã hoàn thành',
          '${completedTodayTasks.length} việc',
          icon: Icons.check_circle,
          iconColor: kPrimaryColor,
          count: completedTodayTasks.length,
        ),
        if (completedTodayTasks.isEmpty)
          _buildEmptyMessage('Chưa có công việc nào hoàn thành trong kỳ này.')
        else
          _CompletedTasksSection(
            tasks: completedTodayTasks,
            taskBuilder: (ctx, task) => _buildCompletedTaskCard(ctx, task),
          ),

        if (start == end && start.day == DateTime.now().day && start.month == DateTime.now().month) ...[
          const SizedBox(height: 24),
          Container(height: 1, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),

          _buildSectionHeader(
            'Hôm qua', 
            DateFormat('EEEE, dd/MM', 'vi').format(start.subtract(const Duration(days: 1))),
            icon: Icons.history,
            iconColor: kTextGray,
            isPast: true,
          ),
          _buildEmptyMessage('Không có việc tồn đọng.'),
        ],
        
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildEmptyMessage(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: kTextGray, size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: kTextGray, fontSize: 13, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildOverdueCard(BuildContext context, FarmingTask task) {
    final today = DateTime.now();
    final diff = today.difference(task.dueDate).inDays;
    final daysOverdue = diff > 0 ? diff : 1; 

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF2C1616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Expanded(
                 child: Row(
                   children: [
                     const Icon(Icons.calendar_today, size: 12, color: Colors.redAccent),
                     const SizedBox(width: 4),
                     Text(
                       'Hết hạn: ${DateFormat('dd/MM/yyyy').format(task.dueDate)}',
                       style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w500),
                     )
                   ],
                 ),
               ),
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(
                   color: Colors.redAccent,
                   borderRadius: BorderRadius.circular(4),
                 ),
                 child: Text(
                   'Quá hạn $daysOverdue ngày', 
                   style: const TextStyle(color: kTextLight, fontSize: 10, fontWeight: FontWeight.bold)
                 ),
               )
            ],
          ),
          const SizedBox(height: 12),
          Text(
            task.title,
            style: const TextStyle(color: kTextLight, fontSize: 16, fontWeight: FontWeight.bold),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            task.description.isNotEmpty ? task.description : 'Không có mô tả.',
            style: const TextStyle(color: kTextGray, fontSize: 12),
            maxLines: 2, overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          SizedBox(
             width: double.infinity,
             child: ElevatedButton.icon(
                onPressed: () => _showTaskDetail(context, ref, task),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Xử lý ngay'),
                style: ElevatedButton.styleFrom(
                   backgroundColor: const Color(0xFFEF5350),
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(vertical: 10),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                   textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
             ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String date, {
    bool isPast = false,
    IconData? icon,
    Color? iconColor,
    int? count,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (iconColor ?? kPrimaryColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor ?? kPrimaryColor, size: 18),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                title.toUpperCase(), 
                style: TextStyle(
                  color: isPast ? kTextGray : kPrimaryColor, 
                  fontSize: 12, 
                  fontWeight: FontWeight.bold, 
                  letterSpacing: 1.2,
                ),
              ),
              if (count != null && count > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isPast ? kTextGray : kPrimaryColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: isPast ? kTextGray : kPrimaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          Text(date, style: const TextStyle(color: kTextGray, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, FarmingTask task) {
    bool isCompleted = task.status == 'COMPLETED';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                       Container(
                         width: 40, height: 40,
                         decoration: BoxDecoration(
                           color: isCompleted ? kPrimaryColor.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                           borderRadius: BorderRadius.circular(12),
                         ),
                         child: Icon(
                           isCompleted ? Icons.check : Icons.water_drop, 
                           color: isCompleted ? kPrimaryColor : Colors.blue,
                         ),
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(task.title, style: const TextStyle(color: kTextLight, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                             Text('${task.locationName ?? "Khu A"} • ${task.status}', style: const TextStyle(color: kTextGray, fontSize: 11)),
                           ],
                         ),
                       ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: const Text('08:00', style: TextStyle(color: kTextGray, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                _buildTag('500 Lít', Colors.blue),
                const SizedBox(width: 8),
                _buildTag('Ưu tiên cao', isCompleted ? kTextGray : kPrimaryColor),
              ],
            ),
            
            if (!isCompleted) ...[
               const SizedBox(height: 16),
               Row(
                 children: [
                   Expanded(
                     child: OutlinedButton.icon(
                       onPressed: () {}, 
                       icon: const Icon(Icons.close, size: 18),
                       label: const Text('Bỏ qua'),
                       style: OutlinedButton.styleFrom(
                         foregroundColor: kTextGray,
                         side: BorderSide(color: Colors.white.withOpacity(0.1)),
                         padding: const EdgeInsets.symmetric(vertical: 12),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                       ),
                     ),
                   ),
                   const SizedBox(width: 12),
                   Expanded(
                     child: ElevatedButton.icon(
                       onPressed: () => _showTaskDetail(context, ref, task),
                       icon: const Icon(Icons.check_circle, size: 18),
                       label: const Text('Xác nhận'),
                       style: ElevatedButton.styleFrom(
                         backgroundColor: kPrimaryColor,
                         foregroundColor: Colors.white,
                         padding: const EdgeInsets.symmetric(vertical: 12),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                         textStyle: const TextStyle(fontWeight: FontWeight.bold),
                       ),
                     ),
                   ),
                 ],
               )
            ]
          ],
        ),
      ),
    );
  }

  /// Card for completed tasks — compact, green tint, no action buttons
  Widget _buildCompletedTaskCard(BuildContext context, FarmingTask task) {
    final completedDate = task.completedAt ?? DateTime.now();
    final dueEnd = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day, 23, 59, 59);
    final wasOverdue = completedDate.isAfter(dueEnd);

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent, // Transparent so the container can have custom rounded corners
          builder: (ctx) => _CompletedTaskDetailSheet(task: task),
        );
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimaryColor.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.check_circle, color: kPrimaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: const TextStyle(
                                color: kTextLight,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            task.locationName ?? 'Khu A',
                            style: const TextStyle(color: kTextGray, fontSize: 11),
                          ),
                          Container(
                            width: 4, height: 4,
                            decoration: const BoxDecoration(color: kTextGray, shape: BoxShape.circle),
                          ),
                          Text(
                            'Hạn: ${DateFormat('dd/MM').format(task.dueDate)}',
                            style: const TextStyle(color: kTextGray, fontSize: 11),
                          ),
                          if (task.completedAt != null) ...[
                            Container(
                              width: 4, height: 4,
                              decoration: const BoxDecoration(color: kTextGray, shape: BoxShape.circle),
                            ),
                            Text(
                              'Hoàn thành: ${DateFormat('dd/MM HH:mm').format(task.completedAt!)}',
                              style: const TextStyle(color: kTextGray, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                color: kPrimaryColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: const Text(
                'Đã hoàn thành',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _showTaskDetail(BuildContext context, WidgetRef ref, FarmingTask task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _TaskCompletionSheet(task: task),
    );
  }

  Widget _buildTaskTimelineSliver(BuildContext context, List<FarmingTask> allTasks, DateTime selectedDate) {
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    final overdueTasks = allTasks.where((t) {
      final isBeforeToday = t.dueDate.isBefore(DateTime(today.year, today.month, today.day));
      final isPending = t.status != 'COMPLETED' && t.status != 'SKIPPED';
      return isBeforeToday && isPending;
    }).toList();

    final todayPendingTasks = allTasks.where((t) {
      final taskDateStr = DateFormat('yyyy-MM-dd').format(t.dueDate);
      return taskDateStr == todayStr && t.status != 'COMPLETED' && t.status != 'SKIPPED';
    }).toList();

    final completedTodayTasks = allTasks.where((t) {
      if (t.status != 'COMPLETED') return false;
      final taskDateStr = DateFormat('yyyy-MM-dd').format(t.dueDate);
      final isDueToday = taskDateStr == todayStr;
      final wasOverdue = t.dueDate.isBefore(DateTime(today.year, today.month, today.day));
      return isDueToday || wasOverdue;
    }).toList();

    final List<Widget> items = [];

    // Overdue
    if (overdueTasks.isNotEmpty) {
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          ),
          const SizedBox(width: 10),
          Text('Công việc quá hạn (${overdueTasks.length})', style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
      ));
      items.add(SizedBox(
        height: 210,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: overdueTasks.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => _buildOverdueCard(context, overdueTasks[i]),
        ),
      ));
      items.add(const SizedBox(height: 24));
      items.add(Container(height: 1, color: Colors.white.withOpacity(0.05)));
      items.add(const SizedBox(height: 16));
    }

    // Today pending
    items.add(_buildSectionHeader('Việc cần làm hôm nay', DateFormat('EEEE, dd/MM', 'vi').format(today), icon: Icons.assignment, iconColor: kPrimaryColor, count: todayPendingTasks.length));
    if (todayPendingTasks.isEmpty) items.add(_buildEmptyMessage('Không còn việc cần làm hôm nay 🎉'));
    items.addAll(todayPendingTasks.map((t) => _buildTaskCard(context, t)));
    items.add(const SizedBox(height: 24));
    items.add(Container(height: 1, color: Colors.white.withOpacity(0.05)));
    items.add(const SizedBox(height: 16));

    // Completed today
    items.add(_buildSectionHeader('Công việc đã hoàn thành', '${completedTodayTasks.length} việc', icon: Icons.check_circle, iconColor: kPrimaryColor, count: completedTodayTasks.length));
    if (completedTodayTasks.isEmpty) {
      items.add(_buildEmptyMessage('Chưa có công việc nào hoàn thành hôm nay.'));
    } else {
      items.add(_CompletedTasksSection(
        tasks: completedTodayTasks,
        taskBuilder: (ctx, task) => _buildCompletedTaskCard(ctx, task),
      ));
    }
    items.add(const SizedBox(height: 24));
    items.add(Container(height: 1, color: Colors.white.withOpacity(0.05)));
    items.add(const SizedBox(height: 16));

    // Yesterday
    items.add(_buildSectionHeader('Hôm qua', DateFormat('EEEE, dd/MM', 'vi').format(today.subtract(const Duration(days: 1))), icon: Icons.history, iconColor: kTextGray, isPast: true));
    items.add(_buildEmptyMessage('Không có việc tồn đọng.'));
    items.add(const SizedBox(height: 80));

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => items[i],
          childCount: items.length,
        ),
      ),
    );
  }
}

class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _FilterBarDelegate({required this.child});

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _FilterBarDelegate oldDelegate) => true;
}

class _TaskCompletionSheet extends ConsumerStatefulWidget {
  final FarmingTask task;

  const _TaskCompletionSheet({required this.task});

  @override
  ConsumerState<_TaskCompletionSheet> createState() => _TaskCompletionSheetState();
}

class _TaskCompletionSheetState extends ConsumerState<_TaskCompletionSheet> {
  final _noteController = TextEditingController();
  final List<XFile> _evidencePhotos = [];
  bool _isUploading = false;
  
  final Map<String, FarmMaterial> _selectedMaterials = {};
  final Map<String, TextEditingController> _qtyControllers = {};

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('Chụp ảnh', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 50, maxWidth: 1024, maxHeight: 1024);
                if (picked != null && mounted) setState(() => _evidencePhotos.add(picked));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Chọn từ thư viện', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 1024, maxHeight: 1024);
                if (picked != null && mounted) setState(() => _evidencePhotos.add(picked));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    // Validate quantities
    for (var entry in _selectedMaterials.entries) {
      final qtyText = _qtyControllers[entry.key]?.text ?? '0';
      final qty = double.tryParse(qtyText) ?? 0;
      if (qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Số lượng ${entry.value.name} phải lớn hơn 0')));
        return;
      }
      if (qty > entry.value.stockQuantity) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Số lượng ${entry.value.name} vượt quá tồn kho (${entry.value.stockQuantity})')));
        return;
      }
    }

    setState(() => _isUploading = true);
    try {
      final repo = ref.read(farmRepositoryProvider);
      
      final connectivityResults = await Connectivity().checkConnectivity();
      final hasNet = connectivityResults.any((r) => r != ConnectivityResult.none);

      List<String> finalPhotoUrls = [];
      final materialsUsed = _selectedMaterials.entries.map((e) {
        final qty = double.parse(_qtyControllers[e.key]!.text);
        return {'material_id': e.key, 'quantity': qty};
      }).toList();

      if (hasNet) {
        for (var file in _evidencePhotos) {
          Uint8List bytes = await file.readAsBytes();
          final url = await repo.uploadImage(bytes, file.name);
          finalPhotoUrls.add(url);
        }
      } else {
        // Offline: Save local paths to be uploaded during sync
        finalPhotoUrls = _evidencePhotos.map((f) => f.path).toList();
      }

      try {
        await repo.updateTaskStatus(
          widget.task.id, 
          'COMPLETED', 
          notes: _noteController.text,
          evidencePhotos: finalPhotoUrls,
          materialsUsed: materialsUsed.isEmpty ? null : materialsUsed,
        );

        ref.invalidate(dailyTasksProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cập nhật công việc thành công!'),
              backgroundColor: Colors.green
            )
          );
          Navigator.pop(context);
        }
      } catch (e) {
        // Locally completed and queued
        ref.invalidate(dailyTasksProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đang ngoại tuyến. Đã lưu tạm công việc và sẽ tự đồng bộ khi có mạng.'),
              backgroundColor: Colors.orange
            )
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text(widget.task.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextLight)),
               IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: kTextGray))
            ],
          ),
          const SizedBox(height: 8),
          Text(widget.task.description, style: const TextStyle(color: kTextGray)),
           const SizedBox(height: 20),
           ref.watch(materialsProvider).when(
             data: (materials) {
               return Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   DropdownButtonFormField<String>(
                     key: UniqueKey(),
                     dropdownColor: kSurfaceDark,
                     style: const TextStyle(color: kTextLight),
                     decoration: InputDecoration(
                       filled: true,
                       fillColor: kBackgroundDark,
                       labelText: 'Thêm vật tư sử dụng',
                       labelStyle: const TextStyle(color: kTextGray),
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                     ),
                     items: materials.where((m) => !_selectedMaterials.containsKey(m.id)).map((m) {
                       return DropdownMenuItem<String>(
                         value: m.id, 
                         child: Text('${m.name} (${m.stockQuantity} ${m.unit})', overflow: TextOverflow.ellipsis)
                       );
                     }).toList(),
                     onChanged: (val) {
                       if (val != null) {
                         final selectedMat = materials.firstWhere((m) => m.id == val);
                         setState(() {
                           _selectedMaterials[selectedMat.id] = selectedMat;
                           _qtyControllers[selectedMat.id] = TextEditingController(text: '1');
                         });
                       }
                     },
                     hint: const Text('Chọn vật tư...', style: TextStyle(color: kTextGray)),
                   ),
                   const SizedBox(height: 12),
                   ..._selectedMaterials.values.map((m) {
                     return Container(
                       margin: const EdgeInsets.only(bottom: 8),
                       padding: const EdgeInsets.all(12),
                       decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                       child: Row(
                         children: [
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(m.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                 const SizedBox(height: 4),
                                 Text('Tồn kho: ${m.stockQuantity} ${m.unit}', style: TextStyle(color: m.stockQuantity == 0 ? Colors.redAccent : kTextGray, fontSize: 12)),
                               ],
                             ),
                           ),
                           SizedBox(
                             width: 80,
                             child: TextField(
                               controller: _qtyControllers[m.id],
                               keyboardType: const TextInputType.numberWithOptions(decimal: true),
                               style: const TextStyle(color: Colors.white),
                               decoration: InputDecoration(
                                 isDense: true,
                                 contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                 filled: true,
                                 fillColor: kBackgroundDark,
                                 suffixText: m.unit,
                                 suffixStyle: const TextStyle(color: kTextGray, fontSize: 12),
                                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                               ),
                               onChanged: (val) => setState((){}), // Trigger rebuild to show warning if needed
                             ),
                           ),
                           IconButton(
                             icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                             onPressed: () {
                               setState(() {
                                 _selectedMaterials.remove(m.id);
                                 _qtyControllers.remove(m.id);
                               });
                             },
                           )
                         ],
                       ),
                     );
                   }).toList(),
                 ],
               );
             },
             loading: () => const Center(child: CircularProgressIndicator()),
             error: (e, s) {
               String errorMsg = e.toString();
               if (errorMsg.contains('connection error') || errorMsg.contains('XMLHttpRequest') || errorMsg.contains('SocketException')) {
                 errorMsg = 'Mất kết nối mạng. Không thể tải danh sách vật tư mới nhất.';
               } else if (errorMsg.startsWith('Exception: ')) {
                 errorMsg = errorMsg.replaceFirst('Exception: ', '');
               }
               return Padding(
                 padding: const EdgeInsets.only(top: 8.0),
                 child: Text(
                   errorMsg,
                   style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)
                 ),
               );
             },
           ),
           const SizedBox(height: 16),
          
          TextField(
            controller: _noteController,
            style: const TextStyle(color: kTextLight),
            decoration: InputDecoration(
              filled: true,
              fillColor: kBackgroundDark,
              labelText: 'Ghi chú công việc',
              labelStyle: const TextStyle(color: kTextGray),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 20),

          const Text('Hình ảnh minh chứng:', style: TextStyle(fontWeight: FontWeight.bold, color: kTextLight)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ..._evidencePhotos.map((f) => Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb 
                        ? Image.network(f.path, width: 80, height: 80, fit: BoxFit.cover)
                        : Image.file(File(f.path), width: 80, height: 80, fit: BoxFit.cover),
                  ),
                )),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: kBackgroundDark,
                      border: Border.all(color: Colors.white.withOpacity(0.1)), 
                      borderRadius: BorderRadius.circular(12)
                    ),
                    child: const Icon(Icons.add_a_photo, color: kTextGray),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor, 
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isUploading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                : const Text('HOÀN THÀNH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
     ),
    );
  }
}

class _ManualDiaryEntrySheet extends ConsumerStatefulWidget {
  const _ManualDiaryEntrySheet();

  @override
  ConsumerState<_ManualDiaryEntrySheet> createState() => _ManualDiaryEntrySheetState();
}

class _ManualDiaryEntrySheetState extends ConsumerState<_ManualDiaryEntrySheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final List<XFile> _evidencePhotos = [];
  bool _isUploading = false;
  
  final Map<String, FarmMaterial> _selectedMaterials = {};
  final Map<String, TextEditingController> _qtyControllers = {};

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('Chụp ảnh', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 50, maxWidth: 1024, maxHeight: 1024);
                if (picked != null && mounted) setState(() => _evidencePhotos.add(picked));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Chọn từ thư viện', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 1024, maxHeight: 1024);
                if (picked != null && mounted) setState(() => _evidencePhotos.add(picked));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên công việc')));
      return;
    }

    // Validate quantities
    for (var entry in _selectedMaterials.entries) {
      final qtyText = _qtyControllers[entry.key]?.text ?? '0';
      final qty = double.tryParse(qtyText) ?? 0;
      if (qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Số lượng ${entry.value.name} phải lớn hơn 0')));
        return;
      }
      if (qty > entry.value.stockQuantity) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Số lượng ${entry.value.name} vượt quá tồn kho (${entry.value.stockQuantity})')));
        return;
      }
    }

    setState(() => _isUploading = true);
    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      final hasNet = connectivityResults.any((r) => r != ConnectivityResult.none);
      if (!hasNet) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không có mạng. Vui lòng kết nối Internet để tạo nhật ký tự do mới.'),
            backgroundColor: Colors.orange
          )
        );
        setState(() => _isUploading = false);
        return;
      }

      final repo = ref.read(farmRepositoryProvider);
      List<String> uploadedUrls = [];

      for (var file in _evidencePhotos) {
        Uint8List bytes = await file.readAsBytes();
        final url = await repo.uploadImage(bytes, file.name);
        uploadedUrls.add(url);
      }

      final materialsUsed = _selectedMaterials.entries.map((e) {
        final qty = double.parse(_qtyControllers[e.key]!.text);
        return {'material_id': e.key, 'quantity': qty};
      }).toList();

      await repo.createManualLog(
        title: title, 
        description: _descController.text,
        evidencePhotos: uploadedUrls,
        materialsUsed: materialsUsed.isEmpty ? null : materialsUsed,
      );

      ref.invalidate(dailyTasksProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thêm nhật ký thành công!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               const Text('Thêm nhật ký', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextLight)),
               IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: kTextGray))
            ],
          ),
          const SizedBox(height: 20),
          
          TextField(
            controller: _titleController,
            style: const TextStyle(color: kTextLight),
            decoration: InputDecoration(
              filled: true,
              fillColor: kBackgroundDark,
              labelText: 'Tên hoạt động (VD: Phun thuốc, Bón phân...)',
              labelStyle: const TextStyle(color: kTextGray),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _descController,
            style: const TextStyle(color: kTextLight),
            decoration: InputDecoration(
              filled: true,
              fillColor: kBackgroundDark,
              labelText: 'Mô tả chi tiết',
              labelStyle: const TextStyle(color: kTextGray),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            maxLines: 3,
          ),
           const SizedBox(height: 20),
           ref.watch(materialsProvider).when(
             data: (materials) {
               return Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   DropdownButtonFormField<String>(
                     key: UniqueKey(),
                     dropdownColor: kSurfaceDark,
                     style: const TextStyle(color: kTextLight),
                     decoration: InputDecoration(
                       filled: true,
                       fillColor: kBackgroundDark,
                       labelText: 'Thêm vật tư sử dụng',
                       labelStyle: const TextStyle(color: kTextGray),
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                     ),
                     items: materials.where((m) => !_selectedMaterials.containsKey(m.id)).map((m) {
                       return DropdownMenuItem<String>(
                         value: m.id, 
                         child: Text('${m.name} (${m.stockQuantity} ${m.unit})', overflow: TextOverflow.ellipsis)
                       );
                     }).toList(),
                     onChanged: (val) {
                       if (val != null) {
                         final selectedMat = materials.firstWhere((m) => m.id == val);
                         setState(() {
                           _selectedMaterials[selectedMat.id] = selectedMat;
                           _qtyControllers[selectedMat.id] = TextEditingController(text: '1');
                         });
                       }
                     },
                     hint: const Text('Chọn vật tư...', style: TextStyle(color: kTextGray)),
                   ),
                   const SizedBox(height: 12),
                   ..._selectedMaterials.values.map((m) {
                     return Container(
                       margin: const EdgeInsets.only(bottom: 8),
                       padding: const EdgeInsets.all(12),
                       decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                       child: Row(
                         children: [
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(m.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                 const SizedBox(height: 4),
                                 Text('Tồn kho: ${m.stockQuantity} ${m.unit}', style: TextStyle(color: m.stockQuantity == 0 ? Colors.redAccent : kTextGray, fontSize: 12)),
                               ],
                             ),
                           ),
                           SizedBox(
                             width: 80,
                             child: TextField(
                               controller: _qtyControllers[m.id],
                               keyboardType: const TextInputType.numberWithOptions(decimal: true),
                               style: const TextStyle(color: Colors.white),
                               decoration: InputDecoration(
                                 isDense: true,
                                 contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                 filled: true,
                                 fillColor: kBackgroundDark,
                                 suffixText: m.unit,
                                 suffixStyle: const TextStyle(color: kTextGray, fontSize: 12),
                                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                               ),
                               onChanged: (val) => setState((){}), // Trigger rebuild to show warning if needed
                             ),
                           ),
                           IconButton(
                             icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                             onPressed: () {
                               setState(() {
                                 _selectedMaterials.remove(m.id);
                                 _qtyControllers.remove(m.id);
                               });
                             },
                           )
                         ],
                       ),
                     );
                   }).toList(),
                 ],
               );
             },
             loading: () => const Center(child: CircularProgressIndicator()),
             error: (e,s) => Text('Lỗi tải vật tư: $e', style: const TextStyle(color: Colors.red)),
           ),
           const SizedBox(height: 16),

          const Text('Hình ảnh minh chứng:', style: TextStyle(fontWeight: FontWeight.bold, color: kTextLight)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ..._evidencePhotos.map((f) => Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb 
                        ? Image.network(f.path, width: 80, height: 80, fit: BoxFit.cover)
                        : Image.file(File(f.path), width: 80, height: 80, fit: BoxFit.cover),
                  ),
                )),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: kBackgroundDark,
                      border: Border.all(color: Colors.white.withOpacity(0.1)), 
                      borderRadius: BorderRadius.circular(12)
                    ),
                    child: const Icon(Icons.add_a_photo, color: kTextGray),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor, 
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isUploading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                : const Text('THÊM MỚI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
     ),
    );
  }
}

class _CompletedTasksSection extends StatefulWidget {
  final List<FarmingTask> tasks;
  final Widget Function(BuildContext, FarmingTask) taskBuilder;

  const _CompletedTasksSection({required this.tasks, required this.taskBuilder});

  @override
  State<_CompletedTasksSection> createState() => _CompletedTasksSectionState();
}

class _CompletedTasksSectionState extends State<_CompletedTasksSection> {
  int _selectedTab = 0; // 0: Đúng hạn, 1: Muộn

  @override
  Widget build(BuildContext context) {
    final onTimeTasks = widget.tasks.where((t) {
      final completedDate = t.completedAt ?? DateTime.now();
      final dueEnd = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day, 23, 59, 59);
      return !completedDate.isAfter(dueEnd);
    }).toList();

    final lateTasks = widget.tasks.where((t) {
      final completedDate = t.completedAt ?? DateTime.now();
      final dueEnd = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day, 23, 59, 59);
      return completedDate.isAfter(dueEnd);
    }).toList();

    final displayedTasks = _selectedTab == 0 ? onTimeTasks : lateTasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildTab(0, 'Đúng hạn', onTimeTasks.length),
            const SizedBox(width: 8),
            _buildTab(1, 'Hoàn thành muộn', lateTasks.length),
          ],
        ),
        const SizedBox(height: 16),
        if (displayedTasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF94A3B8), size: 16),
                const SizedBox(width: 8),
                const Text('Không có công việc nào.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontStyle: FontStyle.italic)),
              ],
            ),
          )
        else
          ...displayedTasks.map((t) => widget.taskBuilder(context, t)),
      ],
    );
  }

  Widget _buildTab(int index, String title, int count) {
    final isSelected = _selectedTab == index;
    final primaryColor = const Color(0xFF00875A); // kPrimaryColor
    final color = isSelected ? primaryColor : Colors.grey;

    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? primaryColor : Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Text(title, style: TextStyle(color: color, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count', style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

final taskDetailProvider = FutureProvider.family<FarmingTask, String>((ref, id) async {
  return await ref.read(farmRepositoryProvider).getTaskDetail(id);
});

class _CompletedTaskDetailSheet extends ConsumerWidget {
  final FarmingTask task;

  const _CompletedTaskDetailSheet({required this.task});

  String _buildFullImageUrl(String url) {
    if (url.startsWith('http')) return url;
    final base = ApiConstants.baseUrl.endsWith('/')
        ? ApiConstants.baseUrl.substring(0, ApiConstants.baseUrl.length - 1)
        : ApiConstants.baseUrl;
    return '$base/${url.startsWith('/') ? url.substring(1) : url}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(taskDetailProvider(task.id));
    final displayTask = detailAsync.value ?? task;
    final assignee = displayTask.assigneeName ?? 'Hệ thống';

    return Container(
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: kBackgroundDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // HEADER
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Chi tiết công việc', style: TextStyle(color: kTextLight, fontSize: 18, fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white70, size: 24),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withOpacity(0.1)),
          
          // BODY
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kSurfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                displayTask.title, 
                                style: const TextStyle(color: kTextLight, fontSize: 18, fontWeight: FontWeight.bold)
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (displayTask.jobType != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  border: Border.all(color: kPrimaryColor),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(displayTask.jobType!, style: const TextStyle(color: kPrimaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          displayTask.description.isEmpty ? 'Không có mô tả.' : displayTask.description, 
                          style: const TextStyle(color: Colors.white70, fontSize: 14)
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Properties List
                  _buildPropRow('Trạng thái:', _buildBadge('Đã hoàn thành', Colors.green)),
                  _buildPropRow('Vùng trồng:', Text(displayTask.locationName ?? '---', style: const TextStyle(color: kTextLight, fontSize: 14, fontWeight: FontWeight.w500))),
                  _buildPropRow('Vụ mùa:', Text(displayTask.cycleName ?? '---', style: const TextStyle(color: kTextLight, fontSize: 14, fontWeight: FontWeight.w500))),
                  if (displayTask.cropName != null && displayTask.cropName!.isNotEmpty)
                    _buildPropRow('Sản phẩm vụ mùa:', Row(
                      children: [
                        Text('${displayTask.cropName} ', style: const TextStyle(color: kTextLight, fontSize: 14, fontWeight: FontWeight.w500)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          decoration: BoxDecoration(
                            border: Border.all(color: kPrimaryColor.withOpacity(0.8)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('(Chính)', style: TextStyle(color: kPrimaryColor.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      ],
                    )),
                  _buildPropRow('Người thực hiện:', Text(assignee, style: const TextStyle(color: kTextLight, fontSize: 14, fontWeight: FontWeight.w500))),
                  _buildPropRow('Hạn hoàn thành:', Text(DateFormat('dd/MM/yyyy').format(displayTask.dueDate), style: const TextStyle(color: kTextLight, fontSize: 14, fontWeight: FontWeight.w500))),
                  _buildPropRow('Thời gian xong:', Text(DateFormat('dd/MM/yyyy').format(displayTask.completedAt ?? DateTime.now()), style: const TextStyle(color: kTextLight, fontSize: 14, fontWeight: FontWeight.w500))),
                  
                  if (displayTask.notes != null && displayTask.notes!.isNotEmpty) ...[
                    Divider(height: 24, color: Colors.white.withOpacity(0.1)),
                    const Text('GHI CHÚ KẾT QUẢ', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kSurfaceDark,
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        displayTask.notes!, 
                        style: const TextStyle(color: kTextLight, fontSize: 14)
                      ),
                    ),
                  ],
                  
                  if (displayTask.evidencePhotos.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('HÌNH ẢNH', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: displayTask.evidencePhotos.map((url) => Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _buildFullImageUrl(url),
                              width: 100, height: 100, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(width: 100, height: 100, color: Colors.grey.shade200, child: const Icon(Icons.broken_image, color: Colors.black26)),
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPropRow(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          Expanded(child: Align(alignment: Alignment.centerLeft, child: child)),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

