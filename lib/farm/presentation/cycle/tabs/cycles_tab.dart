import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:trustid_scan_ai/core/theme/app_colors.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';
import '../../../data/farm_repository.dart';
import '../../../domain/crop_cycle.dart';
import '../widgets/season_form_sheet.dart';
import '../widgets/harvest_modal.dart';
import '../cycle_management_screen.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';

class CyclesTab extends ConsumerStatefulWidget {
  const CyclesTab({super.key});

  @override
  ConsumerState<CyclesTab> createState() => _CyclesTabState();
}

class _CyclesTabState extends ConsumerState<CyclesTab> {
  bool _isLoading = true;
  List<CropCycle> _cycles = [];
  String _searchQuery = '';
  String _filterStatus = '';

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
    _fetchCycles(isRefresh: true);
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
        _fetchCycles();
      }
    }
  }

  Future<void> _fetchCycles({bool isRefresh = false}) async {
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
      final authState = ref.read(authControllerProvider).value;
      final params = <String, dynamic>{
        'page': _currentPage,
        'limit': _limit,
      };

      if (_searchQuery.isNotEmpty) params['search'] = _searchQuery;
      if (_filterStatus.isNotEmpty) params['status'] = _filterStatus;

      if (authState?.role == 'TEAM_LEADER') params['leader_id'] = authState?.id;
      if (authState?.role == 'FARMER') params['farmer_id'] = authState?.id;

      final repo = ref.read(farmRepositoryProvider);
      final data = await repo.getCycles(params);
      
      if (mounted) {
        setState(() {
          if (isRefresh) {
            _cycles = data;
          } else {
            _cycles.addAll(data);
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

  void _showForm([CropCycle? cycle]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SeasonFormSheet(
        cycle: cycle,
        onSaved: () => _fetchCycles(isRefresh: true),
      ),
    );
  }

  void _showHarvest(CropCycle cycle) {
    showDialog(
      context: context,
      builder: (_) => HarvestModal(
        cycle: cycle,
        onSaved: () => _fetchCycles(isRefresh: true),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ACTIVE': return Colors.green;
      case 'COMPLETED':
      case 'HARVESTED': return Colors.blue;
      case 'CANCELLED': return Colors.red;
      case 'PLANNED': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'ACTIVE': return 'Đang canh tác';
      case 'COMPLETED':
      case 'HARVESTED': return 'Đã thu hoạch';
      case 'CANCELLED': return 'Đã hủy';
      case 'PLANNED': return 'Kế hoạch';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(cycleRefreshProvider, (prev, next) {
      _fetchCycles(isRefresh: true);
    });

    return Column(
      children: [
        // Toolbar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  style: const TextStyle(color: kTextLight),
                  decoration: InputDecoration(
                    hintText: 'Tìm vụ mùa...',
                    hintStyle: const TextStyle(color: kTextGray),
                    prefixIcon: const Icon(Icons.search, color: kTextGray),
                    filled: true,
                    fillColor: kSurfaceDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  ),
                  onChanged: (val) {
                    _searchQuery = val;
                    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
                    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                      _fetchCycles(isRefresh: true);
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _filterStatus.isEmpty ? null : _filterStatus,
                  dropdownColor: kSurfaceDark,
                  style: const TextStyle(color: kTextLight),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: kSurfaceDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  ),
                  isExpanded: true,
                  hint: const Text('Trạng thái', style: TextStyle(color: kTextGray, overflow: TextOverflow.ellipsis)),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Tất cả')),
                    DropdownMenuItem(value: 'ACTIVE', child: Text('Đang canh tác')),
                    DropdownMenuItem(value: 'HARVESTED', child: Text('Đã thu hoạch')),
                    DropdownMenuItem(value: 'CANCELLED', child: Text('Đã hủy')),
                  ],
                  onChanged: (val) {
                    _filterStatus = val ?? '';
                    _fetchCycles(isRefresh: true);
                  },
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
            : _cycles.isEmpty
              ? const Center(child: Text('Không có dữ liệu', style: TextStyle(color: kTextGray)))
              : RefreshIndicator(
                  onRefresh: () => _fetchCycles(isRefresh: true),
                  color: kPrimaryColor,
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 80),
                    itemCount: _cycles.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == _cycles.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: _hasMoreData 
                                ? const CircularProgressIndicator(color: kPrimaryColor)
                                : const Text('Đã hiển thị hết danh sách', style: TextStyle(color: kTextGray)),
                          ),
                        );
                      }
                      final cycle = _cycles[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kSurfaceDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    cycle.name,
                                    style: const TextStyle(color: kTextLight, fontWeight: FontWeight.bold, fontSize: 16),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(cycle.status).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _getStatusText(cycle.status),
                                    style: TextStyle(color: _getStatusColor(cycle.status), fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: kTextGray, size: 16),
                                const SizedBox(width: 4),
                                Expanded(child: Text(cycle.locationName ?? cycle.location?.name ?? cycle.locationId ?? '---', style: const TextStyle(color: kTextGray, fontSize: 13))),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, color: kTextGray, size: 16),
                                const SizedBox(width: 4),
                                Text(cycle.startDate != null ? DateFormat('dd/MM/yyyy').format(cycle.startDate!) : '---', style: const TextStyle(color: kTextGray, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (cycle.productNames.isNotEmpty) ...[
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: cycle.productNames.map((name) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: kPrimaryColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
                                    ),
                                    child: Text(name, style: const TextStyle(color: kPrimaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 12),
                            ],
                            const Divider(color: kBackgroundDark, thickness: 1, height: 1),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (cycle.status == 'ACTIVE') ...[
                                  ElevatedButton.icon(
                                    onPressed: () => _showHarvest(cycle),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kPrimaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      minimumSize: const Size(0, 36),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.shopping_basket, size: 16),
                                    label: const Text('Thu hoạch', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                OutlinedButton.icon(
                                  onPressed: () => _showForm(cycle),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(color: Colors.white.withOpacity(0.5)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    minimumSize: const Size(0, 36),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text('Sửa'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
