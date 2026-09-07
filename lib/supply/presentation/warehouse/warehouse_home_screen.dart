import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/supply/data/supply_repository.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';
import 'package:trustid_scan_ai/auth/user_profile_screen.dart';
import 'package:trustid_scan_ai/home/modern_home_screen.dart';
import 'package:trustid_scan_ai/core/widgets/user_avatar.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'warehouse_management_screen.dart';
import 'warehouse_stock_screen.dart';
import '../pallets/pallet_list_screen.dart';
import '../semi_finished/semi_finished_list_screen.dart';
import '../semi_finished/sf_pallet_list_screen.dart';
import '../export_orders/export_order_list_screen.dart';
import '../export_orders/export_order_sheet_screen.dart';
import '../order_list_screen.dart';

const Color kWarehouseBg = Color(0xFF0A192F);
const Color kWarehouseSurface = Color(0xFF112240);
const Color kWarehousePrimary = Color(0xFF00875A); // Emerald green
const Color kWarehouseText = Color(0xFFCCD6F6);
const Color kWarehouseTextMuted = Color(0xFF8892B0);

final warehouseListProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.watch(supplyRepositoryProvider).getWarehouses(page: 1, limit: 10);
});

final warehouseStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(supplyRepositoryProvider).getWarehouseDashboardStats();
});

class _WarehouseQuickTasksWidget extends StatefulWidget {
  const _WarehouseQuickTasksWidget();

  @override
  State<_WarehouseQuickTasksWidget> createState() => _WarehouseQuickTasksWidgetState();
}

class _WarehouseQuickTasksWidgetState extends State<_WarehouseQuickTasksWidget> {
  int _selectedTabIndex = 0;

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
          color: kWarehouseSurface,
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
                      color: kWarehouseText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: kWarehouseTextMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: kWarehouseTextMuted,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      {
        'title': 'SX & Đóng Gói',
        'icon': Icons.precision_manufacturing,
        'items': [
          _buildSleekListTile(context, 'Tạo Lệnh Sản Xuất', 'Lập kế hoạch sản xuất mới', Icons.add_circle_outline, Colors.teal[400]!, () {
            context.push('/manager/production-orders/create');
          }),
          _buildSleekListTile(context, 'Đóng Bao', 'Gói sản phẩm active', Icons.inventory, Colors.indigo[400]!, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderListScreen(mode: 'bag-linking')));
          }),
          _buildSleekListTile(context, 'Xếp Pallet', 'Đóng gói pallet', Icons.move_to_inbox, Colors.teal[400]!, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderListScreen(mode: 'pallet-linking')));
          }),
          _buildSleekListTile(context, 'Quản lý Pallet', 'Danh sách & chi tiết', Icons.view_module, Colors.blueGrey[400]!, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PalletListScreen()));
          }),
        ],
      },
      {
        'title': 'Nguyên Liệu & BTP',
        'icon': Icons.category,
        'items': [
          _buildSleekListTile(context, 'Bán TP (BTP)', 'Bán thành phẩm', Icons.inventory_2, kWarehousePrimary, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SemiFinishedListScreen()));
          }),
          _buildSleekListTile(context, 'Pallet BTP', 'Quản lý Pallet BTP', Icons.pallet, Colors.blue[400]!, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SFPalletListScreen()));
          }),
        ],
      },
      {
        'title': 'Kho & XNT',
        'icon': Icons.warehouse,
        'items': [
          _buildSleekListTile(context, 'Quản lý Kho', 'Danh sách & vị trí kho', Icons.warehouse, Colors.blueGrey[400]!, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehouseManagementScreen()));
          }),
          _buildSleekListTile(context, 'Lệnh xuất hàng', 'Quản lý lệnh xuất', Icons.outbox, Colors.red[400]!, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ExportOrderListScreen()));
          }),
          _buildSleekListTile(context, 'Phiếu xuất kho', 'Thực thi xuất kho', Icons.receipt_long, Colors.redAccent[200]!, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ExportOrderSheetScreen()));
          }),
        ],
      },
      {
        'title': 'Vận Chuyển',
        'icon': Icons.local_shipping,
        'items': [
          _buildSleekListTile(context, 'Chuyến hàng', 'Danh sách chuyến vận chuyển', Icons.local_shipping, Colors.indigo[400]!, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderListScreen(mode: 'orders')));
          }),
        ],
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Tác vụ nhanh',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kWarehouseText,
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
            separatorBuilder: (_, __) => const SizedBox(width: 12),
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
                    color: isSelected ? kWarehousePrimary : kWarehouseSurface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isSelected ? kWarehousePrimary : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        cat['icon'] as IconData,
                        size: 18,
                        color: isSelected ? Colors.white : kWarehouseTextMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cat['title'] as String,
                        style: TextStyle(
                          color: isSelected ? Colors.white : kWarehouseTextMuted,
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
      ],
    );
  }
}

class WarehouseHomeScreen extends ConsumerWidget {
  const WarehouseHomeScreen({super.key});

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 145,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kWarehouseSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.15),
              kWarehouseSurface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 10,
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
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 18),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kWarehouseText,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: kWarehouseTextMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.value;
    final warehousesAsync = ref.watch(warehouseListProvider);
    final statsAsync = ref.watch(warehouseStatsProvider);

    return Scaffold(
      backgroundColor: kWarehouseBg,
      body: Column(
        children: [
          // 1. Fixed Header synced with Dealer / Farmer / Dashboard
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              bottom: 12,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              color: kWarehouseBg.withOpacity(0.95),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    UserAvatar(
                      avatarUrl: user?.avatar,
                      fullName: user?.fullName ?? 'Thủ kho',
                      size: 40,
                      borderColor: kWarehousePrimary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Xin chào,', style: TextStyle(color: kWarehouseTextMuted, fontSize: 12)),
                        Text(
                          user?.fullName ?? 'Thủ kho',
                          style: const TextStyle(
                            color: kWarehouseText,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: kWarehouseText, size: 22),
                        tooltip: 'Quét mã',
                        onPressed: () => context.push('/consumer/scan'),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.home_outlined, color: kWarehouseText, size: 22),
                        tooltip: 'Trang chủ',
                        onPressed: () {
                          ref.invalidate(warehouseListProvider);
                          ref.invalidate(warehouseStatsProvider);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const ModernHomeScreen()),
                            (route) => false,
                          );
                        },
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.logout, color: kWarehouseTextMuted, size: 22),
                        tooltip: 'Đăng xuất',
                        onPressed: () async {
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const ModernHomeScreen()),
                              (route) => false,
                            );
                          }
                          await ref.read(authControllerProvider.notifier).logout();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Scrollable Body
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(warehouseStatsProvider);
                ref.invalidate(warehouseListProvider);
              },
              color: kWarehousePrimary,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // Stats Carousel
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Chỉ số tổng quan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kWarehouseText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 135,
                      child: statsAsync.when(
                        data: (stats) {
                          final totalQuantity = stats['totalQuantity'] ?? 0;
                          final totalAvailable = stats['totalAvailable'] ?? 0;
                          final totalPending = stats['totalPending'] ?? 0;
                          final totalProducts = stats['totalProducts'] ?? 0;

                          return ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              _buildStatCard(
                                'Tổng SL (kg)',
                                '$totalQuantity',
                                Icons.inventory_2,
                                Colors.blue[400]!,
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehouseManagementScreen())),
                              ),
                              const SizedBox(width: 16),
                              _buildStatCard(
                                'TT xuất bán',
                                '$totalAvailable',
                                Icons.check_circle_outline,
                                Colors.green[400]!,
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExportOrderListScreen())),
                              ),
                              const SizedBox(width: 16),
                              _buildStatCard(
                                'Đang chờ xuất',
                                '$totalPending',
                                Icons.pending_actions,
                                Colors.orange[400]!,
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExportOrderListScreen())),
                              ),
                              const SizedBox(width: 16),
                              _buildStatCard(
                                'Tổng sản phẩm',
                                '$totalProducts',
                                Icons.category,
                                Colors.purple[400]!,
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SemiFinishedListScreen())),
                              ),
                            ],
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator(color: kWarehousePrimary)),
                        error: (e, s) => Center(child: Text('Lỗi: $e', style: const TextStyle(color: Colors.red))),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Quick Tasks Widget
                    const _WarehouseQuickTasksWidget(),

                    const SizedBox(height: 32),

                    // Warehouses List Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Kho đang quản lý',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: kWarehouseText,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehouseManagementScreen())),
                            child: const Text(
                              'Xem tất cả',
                              style: TextStyle(
                                color: kWarehousePrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    warehousesAsync.when(
                      data: (warehouses) {
                        if (warehouses.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                            child: Center(
                              child: Text('Chưa có dữ liệu kho', style: TextStyle(color: kWarehouseTextMuted)),
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: warehouses.length > 3 ? 3 : warehouses.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final w = warehouses[index];
                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => WarehouseStockScreen(warehouseId: w['id']?.toString() ?? '')),
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: kWarehouseSurface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: kWarehousePrimary.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.warehouse_rounded, color: kWarehousePrimary, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            w['name'] ?? 'Warehouse',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: kWarehouseText,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            w['address'] ?? 'Chưa có địa chỉ',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: kWarehouseTextMuted,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: kWarehousePrimary.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: kWarehousePrimary.withOpacity(0.3)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Xem tồn', style: TextStyle(color: kWarehousePrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                                          SizedBox(width: 4),
                                          Icon(Icons.arrow_forward_ios, size: 10, color: kWarehousePrimary),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: kWarehousePrimary))),
                      error: (e, s) => const SizedBox(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
