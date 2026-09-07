import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:intl/intl.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';
import 'package:trustid_scan_ai/core/api_client.dart';
import 'package:trustid_scan_ai/core/constants/api_constants.dart';
import '../../data/farm_repository.dart';
import '../../domain/farming_task.dart';
import '../../domain/crop_cycle.dart';
import '../../domain/location.dart';
import 'package:trustid_scan_ai/core/widgets/user_avatar.dart';
import 'package:trustid_scan_ai/home/modern_home_screen.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';

// --- Providers ---
final farmerActiveCyclesProvider = FutureProvider<List<CropCycle>>((ref) {
  return ref.watch(farmRepositoryProvider).getActiveCycles();
});

final farmerLocationsProvider = FutureProvider<List<GrowingLocation>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  final repo = ref.watch(farmRepositoryProvider);
  final userId = authState.value?.id;
  if (userId == null) return repo.getLocations();
  final list = await repo.getLocations(farmerId: userId);
  if (list.isEmpty) {
    return repo.getLocations();
  }
  return list;
});

final leaderLocationsProvider = FutureProvider<List<GrowingLocation>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  final repo = ref.watch(farmRepositoryProvider);
  final userId = authState.value?.id;
  if (userId == null) return repo.getLocations();
  final list = await repo.getLeaderMap(userId);
  if (list.isEmpty) {
    return repo.getLocations();
  }
  return list;
});

final farmerTodayTasksProvider = FutureProvider<List<FarmingTask>>((ref) async {
  final repo = ref.watch(farmRepositoryProvider);
  final authState = ref.watch(authControllerProvider);
  final userId = authState.value?.id;
  
  final today = DateTime.now();
  final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  final todayTasks = await repo.getDailyTasks(date: dateStr, assigneeId: userId);
  if (todayTasks.isNotEmpty) return todayTasks;
  
  // Fallback: fetch all active tasks for user or tenant
  final allTasks = await repo.getDailyTasks(assigneeId: userId);
  if (allTasks.isNotEmpty) return allTasks;
  return repo.getDailyTasks();
});

final farmerRecentActivitiesProvider = FutureProvider<List<FarmingTask>>((ref) async {
  final repo = ref.watch(farmRepositoryProvider);
  final authState = ref.watch(authControllerProvider);
  final userId = authState.value?.id;

  final tasks = await repo.getDailyTasks(assigneeId: userId);
  
  final completedTasks = tasks.where((t) => t.status == 'COMPLETED').toList();
  completedTasks.sort((a, b) {
    final timeA = a.completedAt ?? a.dueDate;
    final timeB = b.completedAt ?? b.dueDate;
    return timeB.compareTo(timeA);
  });
  
  return completedTasks.take(5).toList();
});

// --- Constants & Theme synced with Manager Screen ---
const Color kPrimaryColor = Color(0xFF00875A);       // Verify Green
const Color kBackgroundDark = Color(0xFF0F2B46);      // Trust Navy
const Color kSurfaceDark = Color(0xFF163452);          // Surface card
const Color kTextLight = Color(0xFFE8EDF3);
const Color kTextGray = Color(0xFF94A3B8);

class FarmerHomeScreen extends ConsumerStatefulWidget {
  const FarmerHomeScreen({super.key});

  @override
  ConsumerState<FarmerHomeScreen> createState() => _FarmerHomeScreenState();
}

class _FarmerHomeScreenState extends ConsumerState<FarmerHomeScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: kBackgroundDark,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(context, authState),
              Expanded(
                child: RefreshIndicator(
                  color: kPrimaryColor,
                  onRefresh: () async {
                    ref.invalidate(authControllerProvider);
                    ref.invalidate(farmerActiveCyclesProvider);
                    ref.invalidate(farmerTodayTasksProvider);
                    ref.invalidate(farmerRecentActivitiesProvider);
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      const SizedBox(height: 24),
                      _buildSectionHeader('Tổng quan', 'Hôm nay'),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 140,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                                  Consumer(
                                    builder: (context, ref, child) {
                                      final isLeader = authState.value?.role == 'TEAM_LEADER';
                                      final locationsAsync = isLeader ? ref.watch(leaderLocationsProvider) : ref.watch(farmerLocationsProvider);
                                      return locationsAsync.when(
                                        data: (locations) {
                                          final totalArea = locations.fold(0.0, (sum, l) => sum + (l.areaM2));
                                          
                                          if (isLeader) {
                                            final farmerCount = locations.where((l) => l.farmer != null).map((l) {
                                              if (l.farmer is Map) {
                                                return l.farmer['id'] ?? l.farmer.toString();
                                              }
                                              return l.farmer.toString();
                                            }).toSet().length;

                                            return Row(
                                              children: [
                                                _buildStatCard(
                                                  'Số thửa canh tác',
                                                  locations.length.toString(),
                                                  Icons.location_on_outlined,
                                                  Colors.blue[400]!,
                                                  'Đang canh tác',
                                                ),
                                                const SizedBox(width: 12),
                                                _buildStatCard(
                                                  'Số nông hộ quản lý',
                                                  farmerCount.toString(),
                                                  Icons.person_outline,
                                                  Colors.green[400]!,
                                                  'Đang quản lý',
                                                ),
                                                const SizedBox(width: 12),
                                                _buildStatCard(
                                                  'Tổng diện tích',
                                                  (totalArea / 10000).toStringAsFixed(2),
                                                  Icons.dashboard_outlined,
                                                  Colors.purple[400]!,
                                                  'ha',
                                                ),
                                              ],
                                            );
                                          } else {
                                            return Row(
                                              children: [
                                                _buildStatCard(
                                                  'Số thửa canh tác',
                                                  locations.length.toString(),
                                                  Icons.location_on_outlined,
                                                  Colors.blue[400]!,
                                                  'Đang canh tác',
                                                ),
                                                const SizedBox(width: 12),
                                                _buildStatCard(
                                                  'Tổng diện tích',
                                                  (totalArea / 10000).toStringAsFixed(2),
                                                  Icons.dashboard_outlined,
                                                  Colors.purple[400]!,
                                                  'ha',
                                                ),
                                              ],
                                            );
                                          }
                                        },
                                        loading: () => const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
                                        error: (e, _) => Center(
                                           child: Padding(
                                             padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                             child: Text(cleanErrorMessage(e), style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                                           ),
                                         ),
                                      );
                                    }
                                  ),
                                ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      _buildQuickTasksSection(context, authState.value?.role == 'TEAM_LEADER'),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Hoạt động gần đây',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: kTextLight,
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.push('/farmer/diary'),
                              child: const Text(
                                'Xem tất cả',
                                style: TextStyle(
                                  color: kPrimaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Consumer(
                        builder: (context, ref, child) {
                          final activitiesAsync = ref.watch(farmerRecentActivitiesProvider);
                          
                          return activitiesAsync.when(
                            data: (tasks) {
                              if (tasks.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                    child: Text('Chưa có hoạt động nào', style: TextStyle(color: kTextGray)),
                                  ),
                                );
                              }
                              return ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: tasks.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final task = tasks[index];
                                  final displayTime = task.completedAt ?? task.dueDate;
                                  final timeStr = DateFormat('dd/MM - HH:mm').format(displayTime);
                                  return _buildActivityItem(
                                    task.title,
                                    task.locationName ?? 'Khu vực chung',
                                    timeStr,
                                    task.status == 'COMPLETED' ? kPrimaryColor : Colors.orange[400]!,
                                    task.status == 'COMPLETED' ? Icons.check_circle : Icons.pending_actions,
                                  );
                                },
                              );
                            },
                            loading: () => const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
                            error: (e, _) => Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                child: Text(cleanErrorMessage(e), style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                ), // Close RefreshIndicator
              ), // Close Expanded
            ],
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomNav(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AsyncValue<dynamic> authState) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: kBackgroundDark.withOpacity(0.95),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.push('/farmer/profile'),
            child: Row(
              children: [
                UserAvatar(
                  avatarUrl: authState.value?.avatar,
                  fullName: authState.value?.fullName ?? (authState.value?.role == 'TEAM_LEADER' ? 'Đội trưởng' : 'Nông dân'),
                  size: 48,
                  borderColor: kPrimaryColor,
                  onTap: () => context.push('/farmer/profile'),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authState.value?.role == 'TEAM_LEADER' ? '🌾 Đội trưởng' : '👨‍🌾 Nông dân',
                      style: const TextStyle(
                        color: kPrimaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    authState.when(
                      data: (user) => Text(
                        user?.fullName ?? (authState.value?.role == 'TEAM_LEADER' ? 'Đội trưởng' : 'Nông dân'),
                        style: const TextStyle(
                          color: kTextLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      loading: () => const SizedBox(
                        width: 60,
                        height: 16,
                        child: LinearProgressIndicator(
                          color: kPrimaryColor,
                          backgroundColor: kSurfaceDark,
                        ),
                      ),
                      error: (_, __) => const Text('User', style: TextStyle(color: kTextLight)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildIconBtn(Icons.qr_code_scanner, () {
                context.push('/consumer/scan');
              }),
              const SizedBox(width: 8),
              _buildIconBtn(Icons.home_outlined, () {
                ref.invalidate(farmerActiveCyclesProvider);
                ref.invalidate(farmerLocationsProvider);
                ref.invalidate(farmerTodayTasksProvider);
                ref.invalidate(farmerRecentActivitiesProvider);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const ModernHomeScreen()),
                  (route) => false,
                );
              }),
              const SizedBox(width: 8),
              _buildIconBtn(Icons.logout, () async {
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const ModernHomeScreen()),
                    (route) => false,
                  );
                }
                await ref.read(authControllerProvider.notifier).logout();
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, VoidCallback onTap) {
    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: kTextGray, size: 24),
        onPressed: onTap,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kTextLight,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: kPrimaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String trend,
  ) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(16),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: kTextGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: kTextLight,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.trending_up, size: 14, color: color),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      trend,
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTasksSection(BuildContext context, bool isTeamLeader) {
    final categories = <Map<String, dynamic>>[];
    
    if (isTeamLeader) {
      categories.add({
        'title': 'Đội của tôi',
        'icon': Icons.groups,
        'items': [
          _buildSleekListTile(context, 'Quản lý Nông dân', 'Phân công và quản lý', Icons.groups, Colors.purple[400]!, () => context.push('/farmer/my-team')),
        ],
      });
    }

    categories.add({
      'title': 'Vùng trồng',
      'icon': Icons.map,
      'items': [
        _buildSleekListTile(context, 'Quản lý Thửa', 'Bản đồ và thông tin lô', Icons.location_on, Colors.blue[400]!, () => context.push('/farmer/locations')),
        _buildSleekListTile(context, 'Mã vùng lớn', 'Quản lý vùng trồng quy mô', Icons.business, Colors.purple[400]!, () => context.push('/farmer/master-areas')),
      ],
    });

    categories.add({
      'title': 'Canh tác',
      'icon': Icons.eco,
      'items': [
        _buildSleekListTile(context, 'Vật tư & Kho nông trại', 'Quản lý xuất nhập vật tư', Icons.inventory, Colors.brown[400]!, () => context.push('/farmer/materials')),
        _buildSleekListTile(context, 'Mùa vụ', 'Quản lý danh sách mùa vụ', Icons.calendar_today, kPrimaryColor, () => context.push('/farmer/cycles')),
        _buildSleekListTile(context, 'Nhật ký điện tử', 'Ghi chú công việc', Icons.menu_book, Colors.orange[400]!, () => context.push('/farmer/diary')),
        _buildSleekListTile(context, 'Lô thu hoạch', 'Thông tin lô thu hoạch', Icons.inventory_2, Colors.green[600]!, () => context.push('/farmer/harvest')),
      ],
    });

    categories.add({
      'title': 'Danh mục',
      'icon': Icons.category,
      'items': [
        _buildSleekListTile(context, 'Sản phẩm', 'Danh mục sản phẩm', Icons.shopping_bag, Colors.pink[400]!, () => context.push('/farmer/products')),
      ],
    });


    if (_selectedTabIndex >= categories.length) {
      _selectedTabIndex = 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Chức năng',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kTextLight,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Horizontal Tabs
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = _selectedTabIndex == index;
              return GestureDetector(
                onTap: () => setState(() => _selectedTabIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? kPrimaryColor : kSurfaceDark,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isSelected ? kPrimaryColor : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        cat['icon'] as IconData,
                        size: 18,
                        color: isSelected ? Colors.white : kTextGray,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cat['title'] as String,
                        style: TextStyle(
                          color: isSelected ? Colors.white : kTextGray,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Tab Content
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: (categories[_selectedTabIndex]['items'] as List<Widget>).length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => (categories[_selectedTabIndex]['items'] as List<Widget>)[index],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSleekListTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kSurfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: kTextLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: kTextGray,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kTextGray, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String subtitle,
    String time,
    Color color,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: kTextLight,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: const TextStyle(fontSize: 11, color: kTextGray),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: kTextGray),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, WidgetRef ref) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: kBackgroundDark.withOpacity(0.95),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Trang chủ', true),
              _buildNavItem(
                Icons.calendar_month,
                'Mùa vụ',
                false,
                onTap: () {
                  context.push('/farmer/cycle-list');
                },
              ),
              const SizedBox(width: 48),
              _buildNavItem(
                Icons.notifications,
                'Thông báo',
                false,
                onTap: () {
                  context.push('/consumer/notifications');
                },
              ),
              _buildNavItem(
                Icons.person,
                'Tài khoản',
                false,
                onTap: () {
                  context.push('/farmer/profile');
                },
              ),
            ],
          ),
          Positioned(
            top: 5,
            child: InkWell(
              onTap: () => context.push('/farmer/diary'),
              customBorder: const CircleBorder(),
              child: Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  color: kPrimaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: kBackgroundDark, width: 6),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimaryColor.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.menu_book,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    bool isActive, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isActive ? kPrimaryColor : kTextGray, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isActive ? kPrimaryColor : kTextGray,
            ),
          ),
        ],
      ),
    );
  }
}
