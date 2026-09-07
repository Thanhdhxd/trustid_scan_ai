import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/dashboard/data/tenant_repository.dart';
import 'package:trustid_scan_ai/farm/data/farm_repository.dart';
import 'package:trustid_scan_ai/farm/domain/location.dart';
import 'package:trustid_scan_ai/home/modern_home_screen.dart';

const Color kPrimaryColor = Color(0xFF00875A);
const Color kPrimaryLight = Color(0xFF10B981);
const Color kBackgroundDark = Color(0xFF0F2B46);
const Color kSurfaceDark = Color(0xFF16325B);
const Color kCardDark = Color(0xFF1C3D6E);
const Color kTextLight = Color(0xFFE8EDF3);
const Color kTextGray = Color(0xFF94A3B8);

class KcsDashboardScreen extends ConsumerStatefulWidget {
  const KcsDashboardScreen({super.key});

  @override
  ConsumerState<KcsDashboardScreen> createState() => _KcsDashboardScreenState();
}

class _KcsDashboardScreenState extends ConsumerState<KcsDashboardScreen> {
  List<GrowingLocation> _locations = [];
  final Set<String> _inspectedIds = {};
  final Map<String, String> _inspectionDates = {};
  bool _isLoading = true;
  int _selectedTab = 0; // 0: Chờ kiểm tra, 1: Đã kiểm tra
  String _searchQuery = '';
  String _selectedFilter = 'ALL'; // 'ALL', 'HAS_CODE', 'NO_CODE'
  bool _sortNewestFirst = true; // Sắp xếp theo thời gian mới nhất
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      // 1. Load locally persisted inspected location IDs/names
      try {
        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getStringList('kcs_inspected_location_ids') ?? [];
        _inspectedIds.addAll(stored);
      } catch (_) {}

      // 2. Load inspections recorded on server
      final user = ref.read(authControllerProvider).value;
      if (user != null) {
        try {
          final identifier = user.id ?? user.username;
          if (identifier != null && identifier.isNotEmpty) {
            final tenantRepo = ref.read(tenantRepositoryProvider);
            final inspections = await tenantRepo.getKcsInspections(identifier);
            for (var ins in inspections) {
              final locId = ins['locationId'] ?? ins['location_id'] ?? ins['location']?['id'];
              if (locId != null) {
                _inspectedIds.add(locId.toString());
                final date = ins['inspectionDate'] ?? ins['createdAt'] ?? ins['updatedAt'];
                if (date != null) _inspectionDates[locId.toString()] = date.toString();
              }
            }
          }
        } catch (_) {}
      }

      // 3. Fetch assigned locations
      final repo = ref.read(farmRepositoryProvider);
      final locations = await repo.getKcsAssignedLocations();

      if (mounted) {
        setState(() {
          _locations = locations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải danh sách thửa: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  bool _isLocationInspected(GrowingLocation loc) {
    if (loc.isInspected) return true;
    if (_inspectedIds.contains(loc.id)) return true;
    if (loc.code != null && loc.code!.isNotEmpty && _inspectedIds.contains(loc.code!)) return true;
    if (_inspectedIds.contains(loc.name)) return true;
    return false;
  }

  DateTime _getLocationTimestamp(GrowingLocation loc) {
    if (_selectedTab == 1) {
      // Đối với tab Đã kiểm tra: ưu tiên ngày kiểm định gần nhất
      final dateStr = _inspectionDates[loc.id] ?? _inspectionDates[loc.code] ?? loc.lastCheckDate;
      if (dateStr != null && dateStr.isNotEmpty) {
        final parsed = DateTime.tryParse(dateStr);
        if (parsed != null) return parsed;
      }
    }
    // Fallback: ngày cập nhật / ngày tạo thửa
    if (loc.updatedAt != null) return loc.updatedAt!;
    if (loc.createdAt != null) return loc.createdAt!;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<GrowingLocation> get _pendingLocations =>
      _locations.where((l) => !_isLocationInspected(l)).toList();

  List<GrowingLocation> get _inspectedLocations =>
      _locations.where((l) => _isLocationInspected(l)).toList();

  List<GrowingLocation> get _currentTabLocations {
    final baseList = _selectedTab == 0 ? _pendingLocations : _inspectedLocations;

    var list = baseList.where((loc) {
      // 1. Filter by category
      if (_selectedFilter == 'HAS_CODE') {
        if (loc.code == null || loc.code!.trim().isEmpty) return false;
      } else if (_selectedFilter == 'NO_CODE') {
        if (loc.code != null && loc.code!.trim().isNotEmpty) return false;
      }

      // 2. Filter by search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatch = loc.name.toLowerCase().contains(q);
        final codeMatch = (loc.code ?? '').toLowerCase().contains(q);
        final addrMatch = (loc.address ?? '').toLowerCase().contains(q);
        final provMatch = (loc.province ?? '').toLowerCase().contains(q);
        final plantMatch = (loc.plantType ?? '').toLowerCase().contains(q);
        if (!nameMatch && !codeMatch && !addrMatch && !provMatch && !plantMatch) {
          return false;
        }
      }
      return true;
    }).toList();

    // Sắp xếp theo thời gian mới nhất (Newest first by default)
    list.sort((a, b) {
      final timeA = _getLocationTimestamp(a);
      final timeB = _getLocationTimestamp(b);
      final comp = timeB.compareTo(timeA); // Newest first
      if (comp != 0) {
        return _sortNewestFirst ? comp : -comp;
      }
      // Fallback nếu trùng thời gian: sắp xếp theo tên
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return list;
  }

  String _formatArea(double area) {
    if (area >= 10000) {
      return '${(area / 10000).toStringAsFixed(1)} ha';
    }
    return '${area.toStringAsFixed(0)} m²';
  }

  String _formatDateOnly(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty || rawDate == 'null') return '';
    try {
      final dt = DateTime.tryParse(rawDate);
      if (dt != null) {
        final local = dt.toLocal();
        final day = local.day.toString().padLeft(2, '0');
        final month = local.month.toString().padLeft(2, '0');
        final year = local.year.toString();
        return '$day/$month/$year';
      }
      if (rawDate.contains('T')) {
        final parts = rawDate.split('T')[0].split('-');
        if (parts.length == 3) {
          return '${parts[2]}/${parts[1]}/${parts[0]}';
        }
      }
      return rawDate;
    } catch (_) {
      return rawDate;
    }
  }

  Future<void> _handleInspectLocation(GrowingLocation loc) async {
    final res = await context.push('/kcs/inspection/${loc.id}');
    if (res != null) {
      final nowStr = DateTime.now().toIso8601String();
      _inspectedIds.add(loc.id);
      _inspectionDates[loc.id] = nowStr;
      if (loc.code != null && loc.code!.isNotEmpty) {
        _inspectedIds.add(loc.code!);
        _inspectionDates[loc.code!] = nowStr;
      }
      _inspectedIds.add(loc.name);
    }
    _loadLocations();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    final pending = _pendingLocations;
    final inspected = _inspectedLocations;
    final filtered = _currentTabLocations;
    final totalArea = _locations.fold<double>(0, (sum, item) => sum + item.areaM2);

    return Scaffold(
      backgroundColor: kBackgroundDark,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.verified_outlined, color: kPrimaryLight, size: 18),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Kiểm Định KCS',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextLight),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'BẢNG ĐIỀU KHIỂN',
                    style: TextStyle(fontSize: 10, color: kTextGray, letterSpacing: 0.5, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: kBackgroundDark,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh, color: kTextLight, size: 22),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadLocations();
            },
          ),
          IconButton(
            tooltip: 'Tài khoản',
            icon: const Icon(Icons.account_circle_outlined, color: kTextLight, size: 22),
            onPressed: () => context.push('/farmer/profile'),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout, color: Colors.redAccent, size: 22),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const ModernHomeScreen()),
                (route) => false,
              );
              ref.read(authControllerProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLocations,
        color: kPrimaryColor,
        backgroundColor: kSurfaceDark,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Welcome Card & Quick Stats ──
              _buildWelcomeCard(
                user?.fullName ?? user?.username ?? 'Kiểm Định Viên',
                _locations.length,
                pending.length,
                inspected.length,
                totalArea,
              ),
              const SizedBox(height: 16),

              // ── 2. Quick Action Cards (Side by Side) ──
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.qr_code_scanner,
                      title: 'Quét mã QR',
                      subtitle: 'Camera tại ruộng',
                      gradientColors: [const Color(0xFF0D9488), const Color(0xFF059669)],
                      onTap: () async {
                        await context.push('/kcs/scan');
                        _loadLocations();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.keyboard_alt_outlined,
                      title: 'Nhập mã thửa',
                      subtitle: 'Nhập tay UUID/Mã',
                      gradientColors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
                      onTap: () => _showManualInput(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── 3. Main Navigation Tabs (Chờ kiểm tra vs Đã kiểm tra) ──
              _buildSegmentedTabBar(pending.length, inspected.length),
              const SizedBox(height: 16),

              // ── 4. Search & Filter Bar ──
              _buildSearchBar(),
              const SizedBox(height: 10),
              _buildFilterChips(),
              const SizedBox(height: 16),

              // ── 5. Section Header với Sắp xếp thời gian ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        _selectedTab == 0 ? 'Thửa chờ kiểm định' : 'Thửa đã kiểm định',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextLight),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (_selectedTab == 0 ? Colors.amberAccent : kPrimaryLight).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${filtered.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _selectedTab == 0 ? Colors.amberAccent : kPrimaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => setState(() => _sortNewestFirst = !_sortNewestFirst),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kSurfaceDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _sortNewestFirst ? Icons.schedule : Icons.history,
                            size: 15,
                            color: kPrimaryLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _sortNewestFirst ? 'Mới nhất' : 'Cũ nhất',
                            style: const TextStyle(fontSize: 12, color: kPrimaryLight, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── 6. Location List Items ──
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48.0),
                  child: Center(child: CircularProgressIndicator(color: kPrimaryColor)),
                )
              else if (filtered.isEmpty)
                _buildEmptyState()
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final loc = filtered[index];
                    return _buildLocationCard(loc);
                  },
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Segmented Tab Bar ──
  Widget _buildSegmentedTabBar(int pendingCount, int inspectedCount) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              title: 'Chờ kiểm tra',
              count: pendingCount,
              isSelected: _selectedTab == 0,
              icon: Icons.pending_actions,
              activeColor: Colors.amberAccent,
              onTap: () => setState(() => _selectedTab = 0),
            ),
          ),
          Expanded(
            child: _buildTabButton(
              title: 'Đã kiểm tra',
              count: inspectedCount,
              isSelected: _selectedTab == 1,
              icon: Icons.check_circle_outline,
              activeColor: kPrimaryLight,
              onTap: () => setState(() => _selectedTab = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required int count,
    required bool isSelected,
    required IconData icon,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? kCardDark : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeColor : kTextGray,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : kTextGray,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? activeColor.withOpacity(0.2) : Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? activeColor : kTextGray,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Welcome & Overview Card ──
  Widget _buildWelcomeCard(String userName, int total, int pending, int inspected, double totalArea) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kSurfaceDark, kCardDark.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: kPrimaryColor.withOpacity(0.2),
                child: const Icon(Icons.person, color: kPrimaryLight, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xin chào, $userName',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextLight),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Chọn phương thức hoặc chọn thửa bên dưới để kiểm định',
                      style: TextStyle(fontSize: 12, color: kTextGray),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('Tổng thửa', '$total', Icons.landscape_outlined, Colors.lightBlueAccent),
              _buildStatDivider(),
              _buildStatItem('Chờ kiểm tra', '$pending', Icons.pending_actions, Colors.amberAccent),
              _buildStatDivider(),
              _buildStatItem('Đã kiểm tra', '$inspected', Icons.check_circle_outline, const Color(0xFF34D399)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: kTextGray),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white12,
    );
  }

  // ── Quick Action Card (Grid) ──
  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 24, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Search Bar ──
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: kTextLight, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm tên thửa, mã thửa, địa chỉ...',
          hintStyle: const TextStyle(color: kTextGray, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: kTextGray, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: kTextGray, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: InputBorder.none,
        ),
        onChanged: (val) => setState(() => _searchQuery = val.trim()),
      ),
    );
  }

  // ── Filter Chips ──
  Widget _buildFilterChips() {
    final currentBase = _selectedTab == 0 ? _pendingLocations : _inspectedLocations;
    final countHasCode = currentBase.where((l) => l.code != null && l.code!.trim().isNotEmpty).length;
    final countNoCode = currentBase.where((l) => l.code == null || l.code!.trim().isEmpty).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('Tất cả (${currentBase.length})', 'ALL'),
          const SizedBox(width: 8),
          _buildFilterChip('Có mã thửa ($countHasCode)', 'HAS_CODE'),
          const SizedBox(width: 8),
          _buildFilterChip('Chưa có mã ($countNoCode)', 'NO_CODE'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor : kSurfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? kPrimaryLight : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : kTextGray,
          ),
        ),
      ),
    );
  }

  // ── Redesigned Spacious Location Card Item ──
  Widget _buildLocationCard(GrowingLocation loc) {
    final hasCode = loc.code != null && loc.code!.trim().isNotEmpty;
    final isInspected = _isLocationInspected(loc);
    final inspectedDate = _inspectionDates[loc.id] ?? _inspectionDates[loc.code] ?? loc.lastCheckDate;

    return Container(
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isInspected ? kPrimaryLight.withOpacity(0.35) : Colors.white.withOpacity(0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleInspectLocation(loc),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Row: Icon + Full Name (No truncation) + Status Chip ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: (isInspected ? kPrimaryLight : kPrimaryColor).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (isInspected ? kPrimaryLight : kPrimaryColor).withOpacity(0.35),
                        ),
                      ),
                      child: Icon(
                        isInspected ? Icons.check_circle_outline : Icons.eco,
                        color: isInspected ? kPrimaryLight : kPrimaryLight,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Full Location Name — NEVER clipped
                          Text(
                            loc.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: kTextLight,
                              fontSize: 16,
                              height: 1.25,
                            ),
                            maxLines: 3,
                            softWrap: true,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (hasCode) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    loc.code!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.lightBlueAccent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (isInspected)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: kPrimaryLight.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: kPrimaryLight.withOpacity(0.3)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified, size: 12, color: kPrimaryLight),
                                      SizedBox(width: 3),
                                      Text(
                                        'ĐÃ KIỂM ĐỊNH',
                                        style: TextStyle(fontSize: 10, color: kPrimaryLight, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 10),

                // ── Bottom Row: Meta Info & Action Button ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (loc.areaM2 > 0)
                            _buildCardMetaItem(Icons.crop_square, _formatArea(loc.areaM2), kTextGray),
                          if (isInspected && inspectedDate != null)
                            _buildCardMetaItem(Icons.event_available, 'Ngày: ${_formatDateOnly(inspectedDate)}', kPrimaryLight)
                          else if (loc.plantType != null && loc.plantType!.isNotEmpty)
                            _buildCardMetaItem(Icons.grass, loc.plantType!, kPrimaryLight)
                          else if (loc.province != null && loc.province!.isNotEmpty)
                            _buildCardMetaItem(Icons.location_on_outlined, loc.province!, kTextGray),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isInspected ? kCardDark : kPrimaryColor,
                        foregroundColor: Colors.white,
                        side: isInspected ? const BorderSide(color: kPrimaryLight, width: 1) : null,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _handleInspectLocation(loc),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isInspected ? 'Chi tiết' : 'Kiểm tra',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios, size: 11),
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
    );
  }

  Widget _buildCardMetaItem(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ── Empty State ──
  Widget _buildEmptyState() {
    final isPendingTab = _selectedTab == 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: kSurfaceDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(
            isPendingTab ? Icons.task_alt_outlined : Icons.inventory_2_outlined,
            size: 48,
            color: isPendingTab ? kPrimaryLight.withOpacity(0.7) : kTextGray.withOpacity(0.6),
          ),
          const SizedBox(height: 12),
          Text(
            isPendingTab
                ? (_searchQuery.isNotEmpty ? 'Không tìm thấy thửa chờ kiểm tra' : 'Tuyệt vời! Đã hoàn thành tất cả các thửa')
                : (_searchQuery.isNotEmpty ? 'Không tìm thấy thửa đã kiểm tra' : 'Chưa có thửa nào được kiểm định'),
            style: const TextStyle(color: kTextLight, fontSize: 15, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _searchQuery.isNotEmpty
                ? 'Hãy thử tìm bằng từ khóa khác hoặc xóa bộ lọc'
                : (isPendingTab
                    ? 'Tất cả các thửa đất đã được kiểm tra và ghi nhận kết quả.'
                    : 'Các thửa sau khi kiểm định sẽ được lưu trữ và hiển thị tại đây.'),
            style: const TextStyle(color: kTextGray, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty || _selectedFilter != 'ALL') ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedFilter = 'ALL';
                });
              },
              icon: const Icon(Icons.refresh, size: 16, color: kPrimaryLight),
              label: const Text('Xóa bộ lọc tìm kiếm', style: TextStyle(color: kPrimaryLight, fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }

  // ── Manual Input Dialog ──
  void _showManualInput(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note, color: kPrimaryLight, size: 22),
            SizedBox(width: 8),
            Text('Nhập mã thửa', style: TextStyle(color: kTextLight, fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập mã định danh (UUID hoặc mã thửa) để tiến hành kiểm định trực tiếp:',
              style: TextStyle(color: kTextGray, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              style: const TextStyle(color: kTextLight),
              decoration: InputDecoration(
                filled: true,
                fillColor: kBackgroundDark,
                hintText: 'VD: HN12356 hoặc UUID...',
                hintStyle: const TextStyle(color: kTextGray, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: kTextGray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(context);
                final res = await context.push('/kcs/inspection/$text');
                if (res != null) {
                  _inspectedIds.add(text);
                  _inspectionDates[text] = DateTime.now().toIso8601String();
                }
                _loadLocations();
              }
            },
            child: const Text('Tiến hành kiểm tra', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
