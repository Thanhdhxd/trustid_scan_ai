import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/core/utils/app_toast.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';
import 'package:trustid_scan_ai/core/utils/permission_helper.dart';
import 'package:trustid_scan_ai/core/services/app_route_observer.dart';
import 'package:trustid_scan_ai/core/widgets/app_shimmer.dart';
import '../data/supply_repository.dart';
import '../domain/production_order.dart';
import 'production_order/constants/prod_order_constants.dart';
import 'production_order/constants/prod_order_helpers.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  final String mode; // 'bag-linking' (chung LSX) or 'pallet-linking'
  const OrderListScreen({super.key, required this.mode});

  static void clearStaticCache() {
    _OrderListScreenState.clearStaticCache();
  }

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen>
    with RouteAware {
  static List<ProductionOrder>? _cachedOrders;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheTtl = Duration(minutes: 15);
  static final ValueNotifier<int> _cacheRevision = ValueNotifier<int>(0);

  static void clearStaticCache() {
    _cachedOrders = null;
    _cacheTimestamp = null;
    _cacheRevision.value++;
  }

  List<ProductionOrder> _orders = [];
  String _searchQuery = '';
  String? _selectedOrderType; // null | 'BAG_PACKAGING' | 'STANDARD'
  String? _selectedStatus; // null | 'CODES_READY' | 'IN_PROGRESS' | 'GENERATION_FAILED' | 'COMPLETED'
  bool _isLoading = true;
  final Set<String> _retryingIds = {};

  int _currentPage = 1;
  final int _limit = 15;
  bool _hasMoreData = true;
  bool _isFetchingMore = false;
  int _loadGeneration = 0;
  bool _refreshedByPopNext = false;
  ModalRoute<void>? _subscribedRoute;
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  bool get _isPalletMode => widget.mode == 'pallet-linking';

  @override
  void initState() {
    super.initState();
    if (_isPalletMode) {
      _selectedOrderType = 'BAG_PACKAGING';
    }
    _scrollController.addListener(_onScroll);
    _cacheRevision.addListener(_onCacheInvalidated);
    final isCacheValid = !_isPalletMode &&
        _cachedOrders != null &&
        _cachedOrders!.isNotEmpty &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheTtl;

    if (isCacheValid) {
      _orders = List.from(_cachedOrders!);
      _isLoading = false;
    }
    _loadOrders(isRefresh: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        appRouteObserver.unsubscribe(this);
      }
      _subscribedRoute = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _subscribedRoute = null;
    _cacheRevision.removeListener(_onCacheInvalidated);
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didPopNext() {
    _refreshedByPopNext = true;
    _loadOrders(isRefresh: true);
  }

  void _onCacheInvalidated() {
    if (!mounted) return;
    _loadOrders(isRefresh: true);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isFetchingMore && _hasMoreData && !_isLoading) {
        _loadOrders();
      }
    }
  }

  Future<void> _loadOrders({bool isRefresh = false}) async {
    final requestGen = isRefresh ? ++_loadGeneration : _loadGeneration;
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _hasMoreData = true;
        if (_orders.isEmpty) {
          _isLoading = true;
        }
      });
    } else {
      setState(() => _isFetchingMore = true);
    }

    try {
      final repo = ref.read(supplyRepositoryProvider);
      final effectiveType = _isPalletMode ? 'BAG_PACKAGING' : _selectedOrderType;
      final data = await repo.getProductionOrders(
        page: _currentPage,
        limit: _limit,
        search: _searchQuery,
        status: _selectedStatus,
        orderType: effectiveType,
      );
      final loadedOrders = data
          .whereType<Map>()
          .map((e) => ProductionOrder.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (!mounted || requestGen != _loadGeneration) return;
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

      if (!_isPalletMode &&
          _searchQuery.isEmpty &&
          _selectedOrderType == null &&
          _selectedStatus == null) {
        _cachedOrders = List.from(_orders);
        _cacheTimestamp = DateTime.now();
      }
    } catch (e) {
      if (!mounted || requestGen != _loadGeneration) return;
      setState(() {
        _isLoading = false;
        _isFetchingMore = false;
      });
      AppToast.error(context, parseSupplyHttpError(e).message);
    }
  }

  Future<void> _retryGenerate(ProductionOrder order) async {
    setState(() => _retryingIds.add(order.id));
    try {
      await ref.read(supplyRepositoryProvider).retryGenerateCodes(order.id);
      if (mounted) {
        AppToast.success(context, 'Đã gửi yêu cầu sinh lại mã QR.');
      }
      await _loadOrders(isRefresh: true);
    } catch (e) {
      if (mounted) {
        AppToast.error(context, parseSupplyHttpError(e).message);
      }
    } finally {
      if (mounted) {
        setState(() => _retryingIds.remove(order.id));
      }
    }
  }

  Future<void> _pushAndRefresh(String location) async {
    _refreshedByPopNext = false;
    await context.push(location);
    if (mounted && !_refreshedByPopNext) {
      _loadOrders(isRefresh: true);
    }
  }

  Future<void> _navigateToOrder(ProductionOrder order) async {
    if (_isPalletMode) {
      await _pushAndRefresh('/manager/pallet-linking/${order.id}');
    } else {
      await _pushAndRefresh('/manager/production-orders/${order.id}');
    }
  }

  Future<void> _openCreateOrder() async {
    await _pushAndRefresh('/manager/production-orders/create');
  }

  Future<void> _quickScanOrder(ProductionOrder order) async {
    if (order.isBagPackaging) {
      await _pushAndRefresh('/manager/bag-linking/${order.id}');
    } else {
      await _pushAndRefresh('/manager/standard-packaging/${order.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isPalletMode ? 'Chọn LSX — Đóng Pallet' : 'Danh sách Lệnh Sản Xuất';
    final canManage = PermissionHelper.canManageProductionOrders(ref);
    final emptyIcon = _isPalletMode ? Icons.palette_outlined : Icons.inventory_2_outlined;

    return Scaffold(
      backgroundColor: kProdOrderBg,
      appBar: AppBar(
        titleSpacing: 0,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            maxLines: 1,
            style: const TextStyle(color: kProdOrderText, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        backgroundColor: kProdOrderBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: kProdOrderTextGray),
        actions: [
          if (_isPalletMode)
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _pushAndRefresh('/manager/pallet-linking'),
              icon: const Icon(Icons.qr_code_scanner, size: 16, color: kProdOrderPrimaryLight),
              label: const Text(
                'Ngoài lệnh',
                style: TextStyle(color: kProdOrderPrimaryLight, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.refresh, color: kProdOrderTextGray),
            onPressed: () => _loadOrders(isRefresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              style: const TextStyle(color: kProdOrderText),
              decoration: InputDecoration(
                hintText: 'Tìm theo mã lệnh hoặc tên sản phẩm...',
                hintStyle: const TextStyle(color: kProdOrderTextGray, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: kProdOrderTextGray),
                filled: true,
                fillColor: kProdOrderSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              onChanged: (val) {
                _searchQuery = val.trim();
                if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 400), () {
                  _loadOrders(isRefresh: true);
                });
              },
            ),
          ),
          if (!_isPalletMode) _buildTypeFilterRow(),
          _buildStatusFilterRow(),
          const SizedBox(height: 6),
          Expanded(
            child: _isLoading
                ? const OrderListSkeleton()
                : _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(emptyIcon, size: 64, color: Colors.white12),
                            const SizedBox(height: 12),
                            const Text(
                              'Không có lệnh sản xuất phù hợp',
                              style: TextStyle(color: kProdOrderTextGray),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadOrders(isRefresh: true),
                        color: kProdOrderPrimary,
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: _orders.length + 1,
                          padding: EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            !_isPalletMode && canManage ? 84 : 16,
                          ),
                          itemBuilder: (context, index) {
                            if (index == _orders.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: _hasMoreData
                                      ? const CircularProgressIndicator(color: kProdOrderPrimary)
                                      : const Text(
                                          'Đã hiển thị hết danh sách',
                                          style: TextStyle(color: kProdOrderTextGray, fontSize: 12),
                                        ),
                                ),
                              );
                            }
                            return _buildOrderCard(_orders[index], canManage: canManage);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: (!_isPalletMode && canManage)
          ? FloatingActionButton(
              onPressed: _openCreateOrder,
              backgroundColor: kProdOrderPrimary,
              foregroundColor: Colors.white,
              tooltip: 'Tạo Lệnh Sản Xuất',
              child: const Icon(Icons.add, size: 28),
            )
          : null,
    );
  }

  Widget _buildTypeFilterRow() {
    const types = <(String?, String)>[
      (null, 'Tất cả'),
      ('BAG_PACKAGING', 'Đóng bao'),
      ('STANDARD', 'Tiêu chuẩn'),
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: types.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (val, label) = types[i];
          final active = _selectedOrderType == val;
          return ChoiceChip(
            label: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : kProdOrderTextGray,
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            selected: active,
            selectedColor: kProdOrderPrimary,
            backgroundColor: kProdOrderSurface,
            side: BorderSide(color: active ? kProdOrderPrimaryLight : Colors.white12),
            onSelected: (_) {
              setState(() => _selectedOrderType = val);
              _loadOrders(isRefresh: true);
            },
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  Widget _buildStatusFilterRow() {
    const statuses = <(String?, String)>[
      (null, 'Mọi trạng thái'),
      ('CODES_READY', 'Mã sẵn sàng'),
      ('IN_PROGRESS', 'Đang SX'),
      ('GENERATION_FAILED', 'Lỗi sinh mã'),
      ('COMPLETED', 'Hoàn thành'),
    ];
    return Container(
      height: 36,
      margin: const EdgeInsets.only(top: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (val, label) = statuses[i];
          final active = _selectedStatus == val;
          return FilterChip(
            label: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : kProdOrderTextGray,
                fontSize: 11.5,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            selected: active,
            showCheckmark: false,
            selectedColor: const Color(0xFF1E4273),
            backgroundColor: kProdOrderSurface,
            side: BorderSide(
              color: active ? Colors.lightBlueAccent : Colors.white12,
            ),
            onSelected: (_) {
              setState(() => _selectedStatus = val);
              _loadOrders(isRefresh: true);
            },
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(ProductionOrder order, {required bool canManage}) {
    final statusColor = prodOrderStatusColor(order.status);
    final statusLabel = prodOrderStatusLabel(order.status, isPalletMode: _isPalletMode);
    final isBag = order.isBagPackaging;
    final retrying = _retryingIds.contains(order.id);
    final canQuickScan = !_isPalletMode &&
        (order.status == 'CODES_READY' || order.status == 'IN_PROGRESS');

    final String progressSummary;
    if (isBag && order.totalBags > 0) {
      progressSummary =
          '${order.linkedBags}/${order.totalBags} bao • ${order.actualUnits}/${order.plannedUnits} gói';
    } else if (order.plannedUnits > 0) {
      progressSummary =
          '${order.actualUnits}/${order.plannedUnits} gói • ${order.actualWeightKg.toStringAsFixed(1)}/${order.plannedWeightKg.toStringAsFixed(1)} kg';
    } else {
      progressSummary =
          '${order.actualWeightKg.toStringAsFixed(1)}/${order.plannedWeightKg.toStringAsFixed(1)} kg';
    }

    final pct = (order.progress.clamp(0.0, 1.0) * 100).round();
    final progressColor = order.isCompleted
        ? Colors.lightBlueAccent
        : (order.isGenerationFailed ? Colors.redAccent : kProdOrderPrimaryLight);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kProdOrderSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: order.isGenerationFailed
              ? Colors.redAccent.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToOrder(order),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hàng 1: Icon + Mã lệnh đầy đủ + Trạng thái
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (isBag ? kProdOrderPrimary : Colors.lightBlueAccent)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        _isPalletMode
                            ? Icons.palette_outlined
                            : (isBag ? Icons.inventory_2_outlined : Icons.qr_code_2_rounded),
                        color: isBag ? kProdOrderPrimaryLight : Colors.lightBlueAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        order.orderCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: kProdOrderText,
                          fontSize: 14.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Hàng 2: Tên sản phẩm đầy đủ
                if (order.productName != null && order.productName!.isNotEmpty) ...[
                  Text(
                    order.productName!,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: kProdOrderTextSub,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Hàng 3: Chips thông tin gọn (Loại lệnh, Khối lượng, Ngày TH)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _metaPill(
                      label: prodOrderTypeLabel(order.orderType),
                      color: isBag ? kProdOrderPrimaryLight : Colors.lightBlueAccent,
                    ),
                    if (order.plannedWeightKg > 0)
                      _metaPill(
                        icon: Icons.scale_outlined,
                        label:
                            '${order.actualWeightKg.toStringAsFixed(1)}/${order.plannedWeightKg.toStringAsFixed(1)} kg',
                        color: kProdOrderTextSub,
                        neutral: true,
                      ),
                    if (order.plannedDate != null)
                      _metaPill(
                        icon: Icons.calendar_today_outlined,
                        label: formatProdOrderDate(order.plannedDate),
                        color: kProdOrderTextGray,
                        neutral: true,
                      ),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: Colors.white10, height: 1),
                ),

                // Hàng 4: Tiến độ + Hành động
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  progressSummary,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: kProdOrderTextSub,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$pct%',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: progressColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: order.progress.clamp(0.0, 1.0),
                              minHeight: 5,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation(progressColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (order.isGenerationFailed && canManage) ...[
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: retrying ? null : () => _retryGenerate(order),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: retrying
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.refresh, size: 14),
                        label: const Text(
                          'Thử lại sinh mã',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ] else if (canQuickScan) ...[
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => _quickScanOrder(order),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kProdOrderPrimaryLight,
                          side: const BorderSide(color: kProdOrderPrimaryLight),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.qr_code_scanner, size: 14),
                        label: const Text(
                          'Quét nhanh',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: kProdOrderTextGray, size: 22),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metaPill({
    IconData? icon,
    required String label,
    required Color color,
    bool neutral = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: neutral
            ? Colors.white.withValues(alpha: 0.06)
            : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: neutral ? FontWeight.w500 : FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
