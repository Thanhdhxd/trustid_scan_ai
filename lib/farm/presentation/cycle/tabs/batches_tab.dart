import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:trustid_scan_ai/core/theme/app_colors.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';
import '../../../data/farm_repository.dart';
import '../../../domain/crop_cycle.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';

class BatchesTab extends ConsumerStatefulWidget {
  const BatchesTab({super.key});

  @override
  ConsumerState<BatchesTab> createState() => _BatchesTabState();
}

class _BatchesTabState extends ConsumerState<BatchesTab> {
  bool _isLoading = true;
  List<HarvestBatch> _batches = [];
  List<HarvestBatch> _filteredBatches = [];
  String _searchQuery = '';
  String _filterStatus = '';

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _fetchBatches();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchBatches() async {
    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authControllerProvider).value;
      final params = <String, dynamic>{};

      // Tạm thời bỏ truyền search/status lên Backend vì Backend không hỗ trợ tìm theo Tên vụ mùa
      // if (_searchQuery.isNotEmpty) params['search'] = _searchQuery;
      // if (_filterStatus.isNotEmpty) params['status'] = _filterStatus;

      final repo = ref.read(farmRepositoryProvider);
      List<HarvestBatch> data = await repo.getHarvests(params);
      
      int rawLength = data.length;

      // Fallback: Lọc lô thu hoạch dựa trên danh sách mùa vụ của Đội trưởng hoặc Nông dân
      if (authState?.role == 'TEAM_LEADER' || authState?.role == 'FARMER') {
        final queryParam = authState?.role == 'TEAM_LEADER' 
            ? {'leader_id': authState?.id}
            : {'farmer_id': authState?.id};
            
        final myCycles = await repo.getCycles(queryParam);
        final myCycleIds = myCycles.map((c) => c.id).toSet();
        
        data = data.where((b) {
          final cycleId = b.cropCycle?.id;
          return cycleId != null && myCycleIds.contains(cycleId);
        }).toList();
      }

      if (mounted) {
        setState(() {
          _batches = data;
          _isLoading = false;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanErrorMessage(e))));
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredBatches = _batches.where((b) {
        final term = _searchQuery.toLowerCase();
        final matchesSearch = b.batchCode.toLowerCase().contains(term) ||
                              (b.cropCycle?.name.toLowerCase().contains(term) ?? false);
        final matchesStatus = _filterStatus.isEmpty || b.status == _filterStatus;
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  Future<void> _sendToPackaging(HarvestBatch batch) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBackgroundDark,
        title: const Text('Xác nhận chuyển kho', style: TextStyle(color: kTextLight)),
        content: Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Bạn có chắc chắn muốn chuyển lô ', style: TextStyle(color: kTextGray)),
              TextSpan(text: '"${batch.batchCode}"', style: const TextStyle(color: kTextLight, fontWeight: FontWeight.bold)),
              const TextSpan(text: ' sang bộ phận đóng gói?', style: TextStyle(color: kTextGray)),
            ]
          )
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy', style: TextStyle(color: kTextGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
            child: const Text('Đồng ý', style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );

    if (confirm == true) {
      try {
        await ref.read(farmRepositoryProvider).updateHarvestStatus(batch.id, 'READY_FOR_PACKAGING');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chuyển đóng gói thành công!')));
        _fetchBatches();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanErrorMessage(e))));
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'CREATED': return Colors.grey;
      case 'READY_FOR_PACKAGING': return Colors.orange;
      case 'PACKAGING': return Colors.blue;
      case 'COMPLETED': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'CREATED': return 'Mới (Tại nông trại)';
      case 'READY_FOR_PACKAGING': return 'Chờ đóng gói';
      case 'PACKAGING': return 'Đang đóng gói';
      case 'COMPLETED': return 'Hoàn thành';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    hintText: 'Tìm theo mã lô...',
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
                    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                      _applyFilters();
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
                    DropdownMenuItem(value: 'CREATED', child: Text('Mới tạo')),
                    DropdownMenuItem(value: 'READY_FOR_PACKAGING', child: Text('Chờ đóng gói')),
                    DropdownMenuItem(value: 'PACKAGING', child: Text('Đang đóng gói')),
                    DropdownMenuItem(value: 'COMPLETED', child: Text('Hoàn thành')),
                  ],
                  onChanged: (val) {
                    _filterStatus = val ?? '';
                    _applyFilters();
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
            : _filteredBatches.isEmpty
              ? const Center(child: Text('Không có dữ liệu', style: TextStyle(color: kTextGray)))
              : RefreshIndicator(
                  onRefresh: _fetchBatches,
                  color: kPrimaryColor,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 80),
                    itemCount: _filteredBatches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final batch = _filteredBatches[index];
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
                                    batch.batchCode,
                                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace'),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(batch.status).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _getStatusText(batch.status),
                                    style: TextStyle(color: _getStatusColor(batch.status), fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              batch.cropCycle?.name ?? '---',
                              style: const TextStyle(color: kTextLight, fontSize: 14),
                            ),
                            if (batch.cropCycle?.location?.name != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(batch.cropCycle!.location!.name, style: const TextStyle(color: kTextGray, fontSize: 13)),
                              ),
                            if (batch.productName != null && batch.productName!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: kPrimaryColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
                                  ),
                                  child: Text(batch.productName!, style: const TextStyle(color: kPrimaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, color: kTextGray, size: 16),
                                    const SizedBox(width: 4),
                                    Text(batch.harvestDate != null ? DateFormat('dd/MM/yyyy').format(batch.harvestDate!) : '---', style: const TextStyle(color: kTextGray, fontSize: 13)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.scale, color: kTextGray, size: 15),
                                        const SizedBox(width: 4),
                                        Text('Thu hoạch: ${batch.quantityKg.toStringAsFixed(0)} kg', style: const TextStyle(color: kTextLight, fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text('Tồn: ${(batch.remainingQuantityKg ?? batch.quantityKg).toStringAsFixed(0)} kg', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                            if (batch.status == 'CREATED') ...[
                              const SizedBox(height: 12),
                              const Divider(color: kBackgroundDark, thickness: 1, height: 1),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _sendToPackaging(batch),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kPrimaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      minimumSize: const Size(0, 36),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.outbox, size: 16),
                                    label: const Text('Chuyển đóng gói'),
                                  ),
                                ],
                              ),
                            ]
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
