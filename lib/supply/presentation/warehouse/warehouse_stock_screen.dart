import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:trustid_scan_ai/supply/data/supply_repository.dart';

class WarehouseStockScreen extends ConsumerStatefulWidget {
  final String warehouseId;
  const WarehouseStockScreen({super.key, required this.warehouseId});

  @override
  ConsumerState<WarehouseStockScreen> createState() => _WarehouseStockScreenState();
}

class _WarehouseStockScreenState extends ConsumerState<WarehouseStockScreen> with SingleTickerProviderStateMixin {
  static const Color kPrimaryColor = Color(0xFF00875A);
  static const Color kBackgroundDark = Color(0xFF0F2B46);
  static const Color kSurfaceDark = Color(0xFF16325B);
  static const Color kTextLight = Color(0xFFE8EDF3);
  static const Color kTextGray = Color(0xFF94A3B8);

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      appBar: AppBar(
        title: const Text('Chi Tiết Kho & Tồn Kho', style: TextStyle(color: kTextLight, fontWeight: FontWeight.bold)),
        backgroundColor: kBackgroundDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextLight),
        bottom: TabBar(
          controller: _tabController,
          labelColor: kPrimaryColor,
          unselectedLabelColor: kTextGray,
          indicatorColor: kPrimaryColor,
          tabs: const [
            Tab(text: 'Tồn kho'),
            Tab(text: 'Lịch sử XNT'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _StockTab(warehouseId: widget.warehouseId),
          _MovementsTab(warehouseId: widget.warehouseId),
        ],
      ),
    );
  }
}

class _StockTab extends ConsumerStatefulWidget {
  final String warehouseId;
  const _StockTab({required this.warehouseId});
  @override
  ConsumerState<_StockTab> createState() => _StockTabState();
}

class _StockTabState extends ConsumerState<_StockTab> {
  List<dynamic> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final list = await ref.read(supplyRepositoryProvider).getStock(widget.warehouseId);
      if (mounted) {
        setState(() {
          _items = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00875A)));
    }
    if (_items.isEmpty) {
      return const Center(child: Text('Kho hiện chưa có dữ liệu tồn', style: TextStyle(color: Color(0xFF94A3B8))));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF00875A),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _items[index];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF16325B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Container(
                  height: 48, width: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00875A).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.inventory_2, color: Color(0xFF00875A), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['productName'] ?? item['name'] ?? 'Sản phẩm', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('Mã: ${item['productCode'] ?? item['code'] ?? '---'}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00875A).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('SL: ${item['quantity'] ?? item['stock'] ?? 0}', style: const TextStyle(color: Color(0xFF00875A), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MovementsTab extends ConsumerWidget {
  final String warehouseId;
  const _MovementsTab({required this.warehouseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Center(
      child: Text('Lịch sử xuất nhập kho đang cập nhật', style: TextStyle(color: Color(0xFF94A3B8))),
    );
  }
}
