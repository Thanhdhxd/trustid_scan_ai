import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

import 'package:trustid_scan_ai/core/api_client.dart';
import 'package:trustid_scan_ai/farm/domain/location.dart';
import 'package:trustid_scan_ai/farm/data/farm_repository.dart';
import 'package:trustid_scan_ai/farm/presentation/locations/location_form_screen.dart';
import 'package:trustid_scan_ai/farm/presentation/locations/location_detail_screen.dart';
import 'package:trustid_scan_ai/core/constants/api_constants.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/core/theme/app_colors.dart';
import 'package:trustid_scan_ai/home/data/home_stats_repository.dart';

class LocationManagementScreen extends ConsumerStatefulWidget {
  const LocationManagementScreen({super.key});

  @override
  ConsumerState<LocationManagementScreen> createState() =>
      _LocationManagementScreenState();
}

class _LocationManagementScreenState
    extends ConsumerState<LocationManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'ALL'; // 'ALL', 'APPROVED', 'PENDING', 'OVERLAPPED', 'NON_COMPLIANT'

  bool _isLoading = true;
  List<GrowingLocation> _allLocations = [];
  List<GrowingLocation> _filteredLocations = [];
  List<GrowingLocation> _displayedLocations = [];

  double _totalArea = 0;
  int _approvedCount = 0;

  int _currentPage = 1;
  final int _limit = 10;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadLocations(isRefresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMoreData && !_isLoading) {
        final nextIndex = _currentPage * _limit;
        final nextBatch =
            _filteredLocations.skip(nextIndex).take(_limit).toList();
        if (nextBatch.isNotEmpty) {
          setState(() {
            _displayedLocations.addAll(nextBatch);
            _currentPage++;
            _hasMoreData =
                _filteredLocations.length > _displayedLocations.length;
          });
        } else {
          setState(() {
            _hasMoreData = false;
          });
        }
      }
    }
  }

  Future<void> _loadLocations({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _hasMoreData = true;
      });
    }

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/farm/locations');
      final List rawData = (response.data is List)
          ? response.data
          : (response.data['data'] ?? []);
      final data = rawData.map((e) => GrowingLocation.fromJson(e)).toList();

      if (mounted) {
        setState(() {
          _allLocations = data;

          // Calculate overall statistics
          _totalArea =
              data.fold<double>(0, (prev, element) => prev + element.areaM2);
          _approvedCount =
              data.where((e) => e.approvalStatus == 'APPROVED').length;

          _applyFilterAndSearch();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleanErrorMessage(e))),
        );
      }
    }
  }

  void _applyFilterAndSearch() {
    final query = _searchQuery.trim().toLowerCase();

    final filtered = _allLocations.where((loc) {
      // 1. Search Query
      if (query.isNotEmpty) {
        final nameMatch = loc.name.toLowerCase().contains(query);
        final codeMatch = (loc.code ?? '').toLowerCase().contains(query);
        final addressMatch = (loc.address ?? '').toLowerCase().contains(query);
        final plantMatch = (loc.plantType ?? '').toLowerCase().contains(query);
        final farmerMatch = (loc.farmer is Map)
            ? (loc.farmer['fullName'] ?? '')
                .toString()
                .toLowerCase()
                .contains(query)
            : (loc.manager ?? '').toLowerCase().contains(query);
        if (!nameMatch &&
            !codeMatch &&
            !addressMatch &&
            !plantMatch &&
            !farmerMatch) {
          return false;
        }
      }

      // 2. Filter Status
      switch (_selectedFilter) {
        case 'APPROVED':
          return loc.approvalStatus == 'APPROVED';
        case 'PENDING':
          return loc.approvalStatus == 'PENDING';
        case 'OVERLAPPED':
          return loc.isOverlapped;
        case 'NON_COMPLIANT':
          return loc.eudrStatus == 'NON_COMPLIANT';
        default:
          return true;
      }
    }).toList();

    setState(() {
      _filteredLocations = filtered;
      _currentPage = 1;
      _displayedLocations = _filteredLocations.take(_limit).toList();
      _hasMoreData = _filteredLocations.length > _displayedLocations.length;
    });
  }

  Widget _buildFilterChip(String filterType, String label) {
    final isSelected = _selectedFilter == filterType;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : kTextGray,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedFilter = filterType;
              _applyFilterAndSearch();
            });
          }
        },
        selectedColor: kPrimaryColor,
        backgroundColor: kSurfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? kPrimaryColor : Colors.white.withOpacity(0.08),
          ),
        ),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      appBar: AppBar(
        backgroundColor: kBackgroundDark,
        title: const Text(
          'Quản lý Lô thửa',
          style: TextStyle(color: kTextLight, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: kTextGray),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: kPrimaryColor),
            )
          : Column(
              children: [
                // 1. Top Stats Cards
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: kSurfaceDark,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: kPrimaryColor.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.zoom_out_map_rounded, color: kPrimaryColor, size: 20),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Tổng diện tích',
                                      style: TextStyle(color: kTextGray, fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${NumberFormat('#,###').format(_totalArea.round())} m²',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: kSurfaceDark,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.eco_rounded, color: Colors.blue, size: 20),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Số lượng thửa',
                                      style: TextStyle(color: kTextGray, fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${_allLocations.length} / $_approvedCount duyệt',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: kSurfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: kTextLight, fontSize: 14),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, color: kTextGray, size: 20),
                        hintText: 'Tìm kiếm tên thửa, mã, địa chỉ...',
                        hintStyle: const TextStyle(color: kTextGray, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: kTextGray, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                    _applyFilterAndSearch();
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        _searchQuery = val;
                        if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
                        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                          if (mounted) {
                            _applyFilterAndSearch();
                          }
                        });
                      },
                    ),
                  ),
                ),

                // 3. Filter Chips Row
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildFilterChip('ALL', 'Tất cả'),
                        _buildFilterChip('APPROVED', 'Đã duyệt'),
                        _buildFilterChip('PENDING', 'Chờ duyệt'),
                        _buildFilterChip('OVERLAPPED', 'Lấn ranh'),
                        _buildFilterChip('NON_COMPLIANT', 'Vi phạm EUDR'),
                      ],
                    ),
                  ),
                ),

                // 4. List Items or Empty State
                if (_displayedLocations.isEmpty)
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: kSurfaceDark.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.map_outlined,
                                size: 60,
                                color: kTextGray,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Không tìm thấy thửa đất nào',
                              style: TextStyle(
                                fontSize: 16,
                                color: kTextLight,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Không có thửa đất nào khớp với tìm kiếm.'
                                  : 'Không có thửa đất nào ở trạng thái này.',
                              style: const TextStyle(
                                fontSize: 13,
                                color: kTextGray,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_searchQuery.isNotEmpty || _selectedFilter != 'ALL')
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                    _selectedFilter = 'ALL';
                                    _applyFilterAndSearch();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kPrimaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Làm mới bộ lọc'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _loadLocations(isRefresh: true),
                      color: kPrimaryColor,
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _displayedLocations.length + (_hasMoreData ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == _displayedLocations.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: CircularProgressIndicator(color: kPrimaryColor),
                              ),
                            );
                          }

                          final loc = _displayedLocations[index];
                          final isApproved = loc.approvalStatus == 'APPROVED';

                          // Determine leading color & icon based on state
                          Color statusColor = Colors.orange;
                          IconData statusIcon = Icons.hourglass_empty_rounded;
                          if (loc.eudrStatus == 'NON_COMPLIANT') {
                            statusColor = Colors.redAccent;
                            statusIcon = Icons.gpp_bad_rounded;
                          } else if (loc.isOverlapped) {
                            statusColor = Colors.amber;
                            statusIcon = Icons.warning_amber_rounded;
                          } else if (isApproved) {
                            statusColor = kPrimaryColor;
                            statusIcon = Icons.eco_rounded;
                          }

                          // Determine manager name
                          String farmerName = 'N/A';
                          if (loc.farmer is Map) {
                            farmerName = loc.farmer['fullName'] ?? loc.farmer['username'] ?? 'N/A';
                          } else if (loc.manager != null && loc.manager!.isNotEmpty) {
                            farmerName = loc.manager!;
                          }

                          return Container(
                            decoration: BoxDecoration(
                              color: kSurfaceDark,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.06),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 8,
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
                                      MaterialPageRoute(
                                        builder: (_) => LocationDetailScreen(locationId: loc.id),
                                      ),
                                    ).then((_) => _loadLocations(isRefresh: true));
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Row 1: Icon + Title + Popup Menu
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(0.12),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(statusIcon, color: statusColor, size: 20),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    loc.name,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    loc.code ?? 'Chưa có mã',
                                                    style: const TextStyle(
                                                      color: kTextGray,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Three-dot Action Menu
                                            IconButton(
                                              icon: const Icon(Icons.more_vert, color: kTextGray, size: 20),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () => _showLocationOptions(loc),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        // Row 2: Badges (Approval, Overlap, EUDR)
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            // Approval Status Badge
                                            _buildBadge(
                                              isApproved ? 'Đã duyệt' : 'Chờ duyệt',
                                              isApproved ? kPrimaryColor : Colors.orange,
                                            ),
                                            // Overlap Badge
                                            if (loc.isOverlapped)
                                              _buildBadge('⚠️ Lấn ranh', Colors.amber),
                                            // EUDR Status Badge
                                            if (loc.eudrStatus == 'COMPLIANT')
                                              _buildBadge('🟢 Hợp quy EUDR', kPrimaryColor)
                                            else if (loc.eudrStatus == 'NON_COMPLIANT')
                                              _buildBadge('🔴 Vi phạm EUDR', Colors.redAccent)
                                            else if (loc.eudrStatus == 'PENDING')
                                              _buildBadge('⏳ Đang phân tích EUDR', Colors.amber),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        // Divider
                                        Container(height: 1, color: Colors.white.withOpacity(0.06)),
                                        const SizedBox(height: 12),
                                        // Row 3: Meta details (Address, Plant Type, Farmer, Area)
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // Address
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.location_on_outlined, color: kTextGray, size: 14),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          [loc.address, loc.ward, loc.province]
                                                              .where((e) => e != null && e.isNotEmpty)
                                                              .join(', ')
                                                              .isEmpty
                                                              ? 'Chưa có địa chỉ'
                                                              : [loc.address, loc.ward, loc.province]
                                                                  .where((e) => e != null && e.isNotEmpty)
                                                                  .join(', '),
                                                          style: const TextStyle(color: kTextGray, fontSize: 12),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  // Crop Type & Manager
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.grass_outlined, color: kTextGray, size: 14),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          '${loc.plantType ?? "Chưa trồng cây"} • $farmerName',
                                                          style: const TextStyle(color: kTextGray, fontSize: 12),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            // Area
                                            Text(
                                              '${NumberFormat('#,###').format(loc.areaM2.round())} m²',
                                              style: const TextStyle(
                                                color: kPrimaryColor,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
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
                        },
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: BottomAppBar(
        color: kSurfaceDark,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LocationFormScreen()),
            ).then((_) => _loadLocations(isRefresh: true)),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'THÊM LÔ THỬA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLocationOptions(GrowingLocation loc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kTextGray.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kPrimaryColor.withOpacity(0.2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      loc.name.isNotEmpty
                          ? loc.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.name,
                          style: const TextStyle(
                            color: kTextLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          loc.code ?? 'Chưa có mã',
                          style: const TextStyle(
                            color: kTextGray,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            // Edit option
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text(
                'Chỉnh sửa thông tin',
                style: TextStyle(color: kTextLight),
              ),
              subtitle: const Text(
                'Cập nhật tên, địa chỉ, bản đồ...',
                style: TextStyle(color: kTextGray, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LocationFormScreen(location: loc),
                  ),
                ).then((_) => _loadLocations(isRefresh: true));
              },
            ),
            // Delete option
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Xóa lô thửa',
                style: TextStyle(color: Colors.redAccent),
              ),
              subtitle: const Text(
                'Xóa vĩnh viễn lô thửa này',
                style: TextStyle(color: kTextGray, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, loc);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    GrowingLocation loc,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 8),
            Text('Xác nhận xóa', style: TextStyle(color: kTextLight, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa thửa đất "${loc.name}"? Hành động này không thể hoàn tác.',
          style: const TextStyle(color: kTextGray, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: kTextGray, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(farmRepositoryProvider).deleteLocation(loc.id);
                _loadLocations(isRefresh: true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã xóa thửa đất thành công'),
                      backgroundColor: kPrimaryColor,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(cleanErrorMessage(e)),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Xóa', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// --- User Management Screen ---
