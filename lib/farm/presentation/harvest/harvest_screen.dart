import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:intl/intl.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';
import '../../data/farm_repository.dart';
import '../../domain/crop_cycle.dart';
import '../../../auth/presentation/auth_controller.dart';

final harvestBatchesProvider = FutureProvider.autoDispose<List<HarvestBatch>>((ref) async {
  final repo = ref.watch(farmRepositoryProvider);
  final user = ref.watch(authControllerProvider).value;
  
  List<HarvestBatch> data = await repo.getHarvests();
  
  if (user != null && (user.role == 'TEAM_LEADER' || user.role == 'FARMER')) {
    final queryParam = user.role == 'TEAM_LEADER' 
        ? {'leader_id': user.id}
        : {'farmer_id': user.id};
        
    final myCycles = await repo.getCycles(queryParam);
    final myCycleIds = myCycles.map((c) => c.id).toSet();
    
    data = data.where((b) {
      final cycleId = b.cropCycle?.id;
      return cycleId != null && myCycleIds.contains(cycleId);
    }).toList();
  }
  
  return data;
});

final activeCyclesForHarvestProvider = FutureProvider.autoDispose<List<CropCycle>>((ref) async {
  final repo = ref.watch(farmRepositoryProvider);
  return repo.getActiveCycles();
});

// Theme Constants (Synced with dashboard)
const Color kPrimaryColor = Color(0xFF00875A);
const Color kBackgroundDark = Color(0xFF0F2B46);
const Color kSurfaceDark = Color(0xFF16325B);
const Color kTextLight = Color(0xFFE8EDF3);
const Color kTextGray = Color(0xFF94A3B8);

class HarvestScreen extends ConsumerStatefulWidget {
  const HarvestScreen({super.key});

  @override
  ConsumerState<HarvestScreen> createState() => _HarvestScreenState();
}

class _HarvestScreenState extends ConsumerState<HarvestScreen> {
  String _searchQuery = '';
  String _filterStatus = '';
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(harvestBatchesProvider);

    return Scaffold(
      backgroundColor: kBackgroundDark,
      appBar: AppBar(
        backgroundColor: kBackgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextGray),
          onPressed: () => context.pop(),
        ),
        title: const Text('Danh Sách Lô Thu Hoạch', style: TextStyle(color: kTextLight, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
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
                      if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
                      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                        setState(() {
                          _searchQuery = val;
                        });
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
                      setState(() {
                        _filterStatus = val ?? '';
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: kPrimaryColor,
              onRefresh: () async {
                ref.invalidate(harvestBatchesProvider);
                await ref.read(harvestBatchesProvider.future);
              },
              child: batchesAsync.when(
                data: (batches) {
                  final filteredBatches = batches.where((b) {
                    final term = _searchQuery.toLowerCase();
                    final matchesSearch = b.batchCode.toLowerCase().contains(term) ||
                                          (b.cropCycle?.name.toLowerCase().contains(term) ?? false);
                    final matchesStatus = _filterStatus.isEmpty || b.status == _filterStatus;
                    return matchesSearch && matchesStatus;
                  }).toList();

                  if (filteredBatches.isEmpty) {
                    return ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, color: kTextGray, size: 64),
                              SizedBox(height: 16),
                              Text('Không tìm thấy lô thu hoạch nào', style: TextStyle(color: kTextGray, fontSize: 16)),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  
                  return ListView.separated(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                    itemCount: filteredBatches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final batch = filteredBatches[index];
                      return _buildHarvestBatchCard(context, batch);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
                error: (e, s) => Center(child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(cleanErrorMessage(e), style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHarvestBatchCard(BuildContext context, HarvestBatch batch) {
    Color statusColor;
    String statusLabel;
    
    switch (batch.status) {
      case 'COMPLETED':
        statusColor = Colors.green;
        statusLabel = 'Hoàn thành';
        break;
      case 'READY_FOR_PACKAGING':
      case 'PROCESSING':
        statusColor = Colors.orange;
        statusLabel = 'Chờ đóng gói';
        break;
      case 'CREATED':
        statusColor = kPrimaryColor;
        statusLabel = 'Mới tạo';
        break;
      default:
        statusColor = kPrimaryColor;
        statusLabel = batch.status;
    }

    final title = batch.batchCode.isNotEmpty ? batch.batchCode : 'Mã Lô: ${batch.id}';
    final cropCycleName = batch.cropCycle?.name ?? 'Không có thông tin mùa vụ';
    final locationName = batch.cropCycle?.locationName ?? 'Không có thông tin vùng trồng';
    
    String? productTag = batch.productName;
    if (productTag == null && batch.cropCycle != null && batch.cropCycle!.productNames.isNotEmpty) {
      productTag = batch.cropCycle!.productNames.first;
    }

    return Container(
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF42A5F5), // Light blue similar to image
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            cropCycleName,
            style: const TextStyle(color: kTextLight, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            batch.cropCycle?.location?.name ?? locationName,
            style: const TextStyle(color: kTextGray, fontSize: 13),
          ),
          if (productTag != null && productTag.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                productTag,
                style: const TextStyle(color: kPrimaryColor, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today, color: kTextGray, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    batch.harvestDate != null
                        ? DateFormat('dd/MM/yyyy').format(batch.harvestDate!)
                        : '--/--/----',
                    style: const TextStyle(color: kTextGray, fontSize: 13),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.scale, color: kTextLight, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        'Thu hoạch: ${batch.quantityKg.toInt()} kg',
                        style: const TextStyle(color: kTextLight, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tồn: ${(batch.remainingQuantityKg ?? batch.quantityKg).toInt()} kg',
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
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
                  onPressed: () => _sendToPackaging(context, ref, batch),
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
          ],
        ],
      ),
    );
  }

  Future<void> _sendToPackaging(BuildContext context, WidgetRef ref, HarvestBatch batch) async {
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
            child: const Text('Huỷ', style: TextStyle(color: kTextGray)),
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
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chuyển đóng gói thành công!')));
          ref.invalidate(harvestBatchesProvider);
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanErrorMessage(e))));
      }
    }
  }
}
