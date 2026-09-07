import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/core/widgets/skeleton_loader.dart';
import '../data/supply_repository.dart';
import '../domain/production_order.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  final String mode; // 'bag-linking' or 'pallet-linking'
  const OrderListScreen({super.key, required this.mode});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  static const Color kPrimaryColor = Color(0xFF00875A);
  static const Color kBackgroundDark = Color(0xFF0F2B46);
  static const Color kSurfaceDark = Color(0xFF16325B);
  static const Color kTextLight = Color(0xFFE8EDF3);
  static const Color kTextGray = Color(0xFF94A3B8);

  List<ProductionOrder> _orders = [];
  String _searchQuery = '';
  bool _isLoading = true;

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
    _loadOrders(isRefresh: true);
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
        _loadOrders();
      }
    }
  }

  Future<void> _loadOrders({bool isRefresh = false}) async {
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
      final repo = ref.read(supplyRepositoryProvider);
      final data = await repo.getProductionOrders(
        page: _currentPage,
        limit: _limit,
        search: _searchQuery,
      );
      List<ProductionOrder> loadedOrders = data.map((e) => ProductionOrder.fromJson(e)).toList();

      // Mặc định API /supply/production-orders có thể trả về 0/0.
      // Cần gọi API lot-mappings để đếm chính xác số bao của từng lệnh.
      final futures = loadedOrders.map((order) async {
        try {
          final mappings = await repo.getOrderLotMappings(order.id);
          final tBags = mappings.length;
          final lBags = mappings.where((m) => (m['lotStatus'] ?? m['lot_status'] ?? '') == 'LINKED').length;
          return order.copyWith(totalBags: tBags, linkedBags: lBags);
        } catch (_) {
          return order;
        }
      });
      loadedOrders = await Future.wait(futures);

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _orders = loadedOrders;
          } else {
            _orders.addAll(loadedOrders);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải LSX: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _navigateToOrder(ProductionOrder order) async {
    if (widget.mode == 'bag-linking') {
      final incomplete = order.totalBags == 0 || order.linkedBags < order.totalBags;
      if (incomplete && order.status.toUpperCase() == 'COMPLETED') {
        final reopened = await ref.read(supplyRepositoryProvider).reopenIfIncompleteBagOrder(order.id);
        if (reopened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã mở lại phiếu để đóng bao tiếp'),
              backgroundColor: kPrimaryColor,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
      await context.push('/manager/bag-linking/${order.id}');
    } else {
      await context.push('/manager/pallet-linking/${order.id}');
    }
    _loadOrders(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.mode == 'pallet-linking' ? 'Chọn LSX — Xếp Pallet' : 'Chọn LSX — Đóng Bao';
    final icon = widget.mode == 'pallet-linking' ? Icons.palette_outlined : Icons.inventory_2;

    return Scaffold(
      backgroundColor: kBackgroundDark,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: kTextLight, fontSize: 16)),
        backgroundColor: kBackgroundDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextGray),
        actions: [
          if (widget.mode == 'bag-linking')
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: kPrimaryColor),
              tooltip: 'Tạo lệnh mới',
              onPressed: () async {
                await context.push('/manager/production-orders/create');
                _loadOrders(isRefresh: true);
              },
            ),
          IconButton(icon: const Icon(Icons.refresh, color: kTextGray), onPressed: () => _loadOrders(isRefresh: true)),
        ],
      ),
      floatingActionButton: widget.mode == 'bag-linking'
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push('/manager/production-orders/create');
                _loadOrders(isRefresh: true);
              },
              backgroundColor: kPrimaryColor,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Tạo Lệnh Mới', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              style: const TextStyle(color: kTextLight),
              decoration: InputDecoration(
                hintText: 'Tìm lệnh sản xuất...',
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
                  _loadOrders(isRefresh: true);
                });
              },
            ),
          ),
          Expanded(
            child: _isLoading 
                ? const SingleChildScrollView(child: SkeletonListView(count: 6))
                : _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, size: 64, color: kTextGray),
                            const SizedBox(height: 16),
                            const Text('Không có lệnh sản xuất nào', style: TextStyle(color: kTextGray, fontSize: 16)),
                            if (widget.mode == 'bag-linking') ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await context.push('/manager/production-orders/create');
                                  _loadOrders(isRefresh: true);
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                                icon: const Icon(Icons.add, color: Colors.white),
                                label: const Text('Tạo Lệnh Sản Xuất Ngay', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadOrders(isRefresh: true),
                        color: kPrimaryColor,
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: _orders.length + 1,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemBuilder: (context, index) {
                            if (index == _orders.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: _hasMoreData 
                                      ? const CircularProgressIndicator(color: kPrimaryColor)
                                      : const Text('Đã hiển thị hết danh sách', style: TextStyle(color: kTextGray)),
                                ),
                              );
                            }
                            return _buildOrderCard(_orders[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(ProductionOrder order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToOrder(order),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    widget.mode == 'pallet-linking' ? Icons.palette_outlined : Icons.inventory_2,
                    color: kPrimaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderCode,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: kTextLight, fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      if (order.productName != null)
                        Text(
                          order.productName!,
                          style: const TextStyle(fontSize: 12, color: kTextGray),
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 6),
                      // Progress
                      if (order.totalBags > 0)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: order.progress,
                            minHeight: 4,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation(
                              order.isComplete ? Colors.orange : kPrimaryColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Count
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${order.linkedBags}/${order.totalBags}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryColor, fontSize: 15),
                    ),
                    const Text('bao', style: TextStyle(fontSize: 10, color: kTextGray)),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor(order.displayStatus).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _statusLabel(order.displayStatus),
                        style: TextStyle(fontSize: 10, color: _statusColor(order.displayStatus), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: kTextGray, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case 'IN_PROGRESS':
        return kPrimaryColor;
      case 'APPROVED':
      case 'CODES_READY':
        return Colors.teal;
      case 'COMPLETED':
        return Colors.blue;
      case 'CANCELLED':
        return Colors.red;
      default:
        return kTextGray;
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case 'IN_PROGRESS':
        return widget.mode == 'pallet-linking' ? 'Đang xếp' : 'Đang đóng bao';
      case 'APPROVED':
        return 'Đã duyệt';
      case 'CODES_READY':
        return 'Mã sẵn sàng';
      case 'COMPLETED':
        return 'Hoàn thành';
      case 'CANCELLED':
        return 'Đã huỷ';
      case 'DRAFT':
        return 'Nháp';
      default:
        return status;
    }
  }
}
