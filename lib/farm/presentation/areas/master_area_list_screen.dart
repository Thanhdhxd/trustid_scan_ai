import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:intl/intl.dart';
import 'package:trustid_scan_ai/core/api/dio_client.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';
import '../../domain/master_growing_area.dart';
import 'master_area_form_screen.dart';
import 'master_area_detail_screen.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';
import 'package:trustid_scan_ai/home/data/home_stats_repository.dart';

// --- Constants ---
const Color kPrimaryColor = Color(0xFF00875A);
const Color kBackgroundDark = Color(0xFF0F2B46);
const Color kSurfaceDark = Color(0xFF16325B);
const Color kTextLight = Color(0xFFE8EDF3);
const Color kTextGray = Color(0xFF94A3B8);

class MasterAreaListScreen extends ConsumerStatefulWidget {
  const MasterAreaListScreen({super.key});

  @override
  ConsumerState<MasterAreaListScreen> createState() => _MasterAreaListScreenState();
}

class _MasterAreaListScreenState extends ConsumerState<MasterAreaListScreen> {
  bool _isLoading = true;
  List<MasterGrowingArea> _areas = [];
  String _searchQuery = '';
  Map<String, int> _locationCounts = {};

  int _currentPage = 1;
  final int _limit = 15;
  bool _hasMoreData = true;
  bool _isFetchingMore = false;
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadAreas(isRefresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isFetchingMore && _hasMoreData && !_isLoading) {
        _loadAreas();
      }
    }
  }

  Future<void> _loadAreas({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _hasMoreData = true;
        _isLoading = true;
      });
    } else {
      setState(() => _isFetchingMore = true);
    }
    
    try {
      final dio = ref.read(dioProvider);
      final authState = ref.read(authControllerProvider).value;
      final role = authState?.role ?? '';
      final userId = authState?.id ?? '';

      Map<String, int> locationCounts = {};
      if (isRefresh) {
        try {
          final locResponse = await dio.get('/farm/locations');
          final List locData = (locResponse.data is List) ? locResponse.data : (locResponse.data['data'] ?? []);
          for (var loc in locData) {
            final masterId = (loc['masterGrowingAreaId'] ?? loc['masterAreaId'] ?? '').toString();
            if (masterId.isNotEmpty) {
              locationCounts[masterId] = (locationCounts[masterId] ?? 0) + 1;
            }
          }
        } catch (_) {}
      }

      final response = await dio.get('/farm/master-growing-areas', queryParameters: {
        'page': _currentPage,
        'limit': _limit,
        if (_searchQuery.isNotEmpty) 'search': _searchQuery,
      });

      final List rawData = (response.data is List) ? response.data : (response.data['data'] ?? []);
      var data = rawData.map((e) => MasterGrowingArea.fromJson(e)).toList();

      // Filter by role on client side
      if (role == 'TEAM_LEADER' && userId.isNotEmpty) {
        data = data.where((area) {
          final leaders = area.leaders ?? [];
          return leaders.any((l) {
            if (l is Map) return (l['id'] ?? l['userId'] ?? '').toString() == userId;
            return l.toString() == userId;
          });
        }).toList();
      } else if (role == 'FARMER' && userId.isNotEmpty) {
        data = data.where((area) {
          final locations = area.locations ?? [];
          return locations.any((loc) {
            if (loc is Map) {
              final farmer = loc['farmer'];
              if (farmer is Map) return (farmer['id'] ?? '').toString() == userId;
              return farmer?.toString() == userId;
            }
            return false;
          });
        }).toList();
      }

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _areas = data;
            _locationCounts = locationCounts;
          } else {
            _areas.addAll(data);
          }
          _currentPage++;
          if (data.length < _limit) {
            _hasMoreData = false;
          }
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authControllerProvider).value?.role ?? '';
    final canAddMasterArea = role != 'FARMER';

    return Scaffold(
      backgroundColor: kBackgroundDark,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mã số vùng trồng', style: TextStyle(color: kTextLight, fontWeight: FontWeight.bold, fontSize: 18)),
            if (!_isLoading)
              Text('Tổng số: ${_areas.length} vùng trồng', style: const TextStyle(color: kTextGray, fontSize: 12)),
          ],
        ),
        backgroundColor: kBackgroundDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextGray),
      ),
      body: Column(
        children: [
          // Premium Search Bar & Stats
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên hoặc mã vùng...',
                    hintStyle: const TextStyle(color: kTextGray, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: kTextGray, size: 20),
                    filled: true,
                    fillColor: kSurfaceDark,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
                    ),
                  ),
                  onChanged: (value) {
                    _searchQuery = value;
                    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
                    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                      _loadAreas(isRefresh: true);
                    });
                  },
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
              : _areas.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.landscape_rounded, size: 64, color: kTextGray),
                        const SizedBox(height: 16),
                        Text(
                          (role == 'FARMER' || role == 'TEAM_LEADER')
                              ? 'Bạn chưa được phân công vào vùng trồng nào'
                              : 'Chưa có mã số vùng trồng nào',
                          style: const TextStyle(color: kTextGray, fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _loadAreas(isRefresh: true),
                    color: kPrimaryColor,
                    child: ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _areas.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index == _areas.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: _hasMoreData 
                                  ? const CircularProgressIndicator(color: kPrimaryColor)
                                  : const Text('Đã hiển thị hết danh sách', style: TextStyle(color: kTextGray, fontSize: 13)),
                            ),
                          );
                        }
                        return _buildAreaCard(_areas[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: canAddMasterArea ? FloatingActionButton(
        backgroundColor: kPrimaryColor,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MasterAreaFormScreen()),
          ).then((_) => _loadAreas(isRefresh: true));
        },
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ) : null,
    );
  }

  Widget _buildAreaCard(MasterGrowingArea area) {
    final locationsCount = _locationCounts[area.id] ?? 0;
    final leadersCount = (area.leaders ?? []).length;
    final kcsCount = (area.kcsStaffs ?? []).length;

    return Container(
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MasterAreaDetailScreen(masterAreaId: area.id)),
              ).then((_) => _loadAreas(isRefresh: true));
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Left icon, Name and Status Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              kPrimaryColor,
                              kPrimaryColor.withOpacity(0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: kPrimaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: const Icon(Icons.landscape_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              area.name,
                              style: const TextStyle(
                                color: kTextLight,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // Code & Copy button
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  area.code,
                                  style: TextStyle(
                                    color: kPrimaryColor.withOpacity(0.9),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: area.code));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Đã sao chép mã vùng trồng: ${area.code}'),
                                        duration: const Duration(seconds: 1),
                                        backgroundColor: kPrimaryColor,
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    child: Icon(
                                      Icons.copy_rounded,
                                      size: 14,
                                      color: kPrimaryColor.withOpacity(0.7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: area.status == 'ACTIVE'
                              ? const Color(0xFF10B981).withOpacity(0.15)
                              : Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: area.status == 'ACTIVE'
                                ? const Color(0xFF10B981).withOpacity(0.3)
                                : Colors.red.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: area.status == 'ACTIVE'
                                    ? const Color(0xFF10B981)
                                    : Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              area.status == 'ACTIVE' ? 'Hoạt động' : 'Đã khóa',
                              style: TextStyle(
                                color: area.status == 'ACTIVE'
                                    ? const Color(0xFF10B981)
                                    : Colors.redAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Colors.white10),
                  const SizedBox(height: 14),
                  // Grid of Info
                  Row(
                    children: [
                      // Column 1: Manager and Area
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoItem(
                              icon: Icons.person_outline_rounded,
                              label: 'Quản lý',
                              value: area.managerName ?? 'Chưa cập nhật',
                            ),
                            const SizedBox(height: 10),
                            _buildInfoItem(
                              icon: Icons.aspect_ratio_rounded,
                              label: 'Diện tích',
                              value: '${NumberFormat('#,###').format(area.maxAreaM2)} m²',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Column 2: Lots and Team Count
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoItem(
                              icon: Icons.grid_view_rounded,
                              label: 'Số lô/thửa',
                              value: '$locationsCount lô',
                              valueColor: locationsCount > 0 ? kTextLight : kTextGray,
                            ),
                            const SizedBox(height: 10),
                            _buildInfoItem(
                              icon: Icons.people_outline_rounded,
                              label: 'Nhân sự phụ trách',
                              value: '$leadersCount Đội trưởng • $kcsCount KCS',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: kTextGray),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: kTextGray, fontSize: 10),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? kTextLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
