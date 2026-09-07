import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';
import 'package:trustid_scan_ai/auth/user_profile_screen.dart';
import 'package:trustid_scan_ai/home/modern_home_screen.dart';
import 'package:trustid_scan_ai/core/api_client.dart';
import 'package:trustid_scan_ai/core/widgets/user_avatar.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/scan/scanner_screen.dart';
import 'package:trustid_scan_ai/supply/data/dealer_providers.dart';

// --- Theme ---
const Color kDealerBg = Color(0xFF0F2B46);
const Color kDealerSurface = Color(0xFF16325B);
const Color kDealerPrimary = Color(0xFF00875A);
const Color kDealerText = Color(0xFFE8EDF3);
const Color kDealerTextMuted = Color(0xFF94A3B8);

class _DealerQuickTasksWidget extends StatefulWidget {
  const _DealerQuickTasksWidget();

  @override
  State<_DealerQuickTasksWidget> createState() => _DealerQuickTasksWidgetState();
}

class _DealerQuickTasksWidgetState extends State<_DealerQuickTasksWidget> {
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
          color: kDealerSurface,
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
                      color: kDealerText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: kDealerTextMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kDealerTextMuted, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      {
        'title': 'Kho & Vận chuyển',
        'icon': Icons.local_shipping,
        'items': [
          _buildSleekListTile(context, 'Nhận hàng', 'Xác nhận đơn đến', Icons.download, Colors.orange, () => context.push('/dealer/receive')),
          _buildSleekListTile(context, 'Quản lý Tồn kho', 'Kiểm tra tồn kho', Icons.inventory_2, Colors.purple, () => context.push('/dealer/inventory')),
        ],
      },
      {
        'title': 'Bán hàng & Dịch vụ',
        'icon': Icons.point_of_sale,
        'items': [
          _buildSleekListTile(context, 'Khách hàng', 'Quản lý khách hàng', Icons.people, Colors.pinkAccent, () => context.push('/dealer/customers')),
          _buildSleekListTile(context, 'Bảng giá', 'Cài đặt giá bán', Icons.price_change, Colors.orangeAccent, () => context.push('/dealer/pricing')),
          _buildSleekListTile(context, 'Bán lẻ (POS)', 'Tạo hóa đơn bán', Icons.point_of_sale, Colors.blueAccent, () => context.push('/dealer/pos')),
          _buildSleekListTile(context, 'Lịch sử Bán', 'Danh sách giao dịch', Icons.receipt_long, Colors.teal, () => context.push('/dealer/sales')),
        ],
      }
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
              color: kDealerText,
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
            separatorBuilder: (context, index) => const SizedBox(width: 12),
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
                    color: isSelected ? kDealerPrimary : kDealerSurface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isSelected ? kDealerPrimary : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        cat['icon'] as IconData,
                        size: 18,
                        color: isSelected ? Colors.white : kDealerTextMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cat['title'] as String,
                        style: TextStyle(
                          color: isSelected ? Colors.white : kDealerTextMuted,
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

class DealerHomeScreen extends ConsumerWidget {
  const DealerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dealerDashboardStatsProvider);
    final topProductsAsync = ref.watch(dealerTopProductsProvider);
    final activityAsync = ref.watch(dealerActivityProvider);
    final authState = ref.watch(authControllerProvider);

    final formatCurrency = (dynamic v) {
      final numValue = num.tryParse(v.toString()) ?? 0;
      return numValue.toStringAsFixed(0).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.') + ' đ';
    };

    return Scaffold(
      backgroundColor: kDealerBg,
      body: Stack(
        children: [
          Column(
            children: [
              // 1. Fixed Header
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 10,
                  bottom: 12,
                  left: 16,
                  right: 16,
                ),
                decoration: BoxDecoration(
                  color: kDealerBg.withOpacity(0.95),
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
                          avatarUrl: authState.value?.avatar,
                          fullName: authState.value?.fullName ?? 'Đại lý',
                          size: 48,
                          borderColor: kDealerPrimary,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserProfileScreen())),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Xin chào,',
                              style: TextStyle(
                                color: kDealerTextMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            authState.when(
                              data: (user) => Text(
                                user != null ? user.fullName : 'Đại lý',
                                style: const TextStyle(
                                  color: kDealerText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              loading: () => const SizedBox(
                                width: 60,
                                height: 16,
                                child: LinearProgressIndicator(
                                  color: kDealerPrimary,
                                  backgroundColor: kDealerSurface,
                                ),
                              ),
                              error: (e, s) => const Text(
                                'Error',
                                style: TextStyle(color: Colors.red),
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
                            icon: const Icon(Icons.qr_code_scanner, color: kDealerText, size: 22),
                            tooltip: 'Quét mã',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ScannerScreen()),
                              );
                            },
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.home_outlined, color: kDealerText, size: 22),
                            tooltip: 'Trang chủ',
                            onPressed: () {
                              ref.invalidate(dealerDashboardStatsProvider);
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
                            icon: const Icon(Icons.logout, color: kDealerTextMuted, size: 22),
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

              // 2. Scrollable Content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(dealerDashboardStatsProvider);
                    ref.invalidate(dealerTopProductsProvider);
                    ref.invalidate(dealerActivityProvider);
                  },
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
                              color: kDealerText,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 135,
                          child: statsAsync.when(
                            data: (stats) {
                              final todayRevenue = stats['todayRevenue'] ?? 0;
                              final monthRevenue = stats['monthRevenue'] ?? 0;
                              final totalStock = stats['currentStock'] ?? 0;
                              final pendingReceives = stats['pendingShipments'] ?? 0;

                              return ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                children: [
                                  _buildStatCard(
                                    'Doanh thu hôm nay',
                                    formatCurrency(todayRevenue),
                                    Icons.attach_money,
                                    Colors.greenAccent,
                                  ),
                                  const SizedBox(width: 16),
                                  _buildStatCard(
                                    'Doanh thu tháng này',
                                    formatCurrency(monthRevenue),
                                    Icons.trending_up,
                                    Colors.blueAccent,
                                  ),
                                  const SizedBox(width: 16),
                                  _buildStatCard(
                                    'Tổng tồn kho',
                                    '$totalStock',
                                    Icons.inventory,
                                    Colors.orangeAccent,
                                    onTap: () => context.push('/dealer/inventory'),
                                  ),
                                  const SizedBox(width: 16),
                                  _buildStatCard(
                                    'Đơn chờ nhận',
                                    '$pendingReceives',
                                    Icons.local_shipping,
                                    Colors.purpleAccent,
                                    onTap: () => context.push('/dealer/receive'),
                                  ),
                                ],
                              );
                            },
                            loading: () => const Center(child: CircularProgressIndicator(color: kDealerPrimary)),
                            error: (e, s) => Center(child: Text('Lỗi: $e', style: const TextStyle(color: Colors.red))),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Quick Tasks
                        const _DealerQuickTasksWidget(),

                        const SizedBox(height: 32),

                        // Top Products
                        if (topProductsAsync.value?.isNotEmpty == true) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Sản phẩm bán chạy',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: kDealerText,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: topProductsAsync.value!.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final p = topProductsAsync.value![index];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: kDealerSurface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      height: 40,
                                      width: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          '🔥',
                                          style: TextStyle(fontSize: 20),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p['name'] ?? 'Sản phẩm',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: kDealerText,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Đã bán: ${p['qty']}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: kDealerTextMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          formatCurrency(p['revenue'] ?? p['totalAmount'] ?? 0),
                                          style: const TextStyle(
                                            color: Colors.greenAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Doanh thu',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: kDealerTextMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 32),
                        ],

                        // Recent Activity
                        if (activityAsync.value?.isNotEmpty == true) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text(
                                  'Hoạt động gần đây',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: kDealerText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: activityAsync.value!.length > 5 ? 5 : activityAsync.value!.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final act = activityAsync.value![index];
                              final isSale = act['type'] == 'SALE';
                              final date = act['time'] != null ? DateTime.tryParse(act['time'])?.toLocal() ?? DateTime.now() : DateTime.now();
                              final timeStr = DateFormat('dd/MM HH:mm').format(date);

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: kDealerSurface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      isSale ? Icons.check_circle : Icons.info,
                                      color: isSale ? Colors.greenAccent : kDealerPrimary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            act['description'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: kDealerText,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            timeStr,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: kDealerTextMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if ((num.tryParse(act['amount']?.toString() ?? '0') ?? 0) > 0)
                                      Text(
                                        '+${formatCurrency(act['amount'])}',
                                        style: const TextStyle(
                                          color: Colors.greenAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    final content = Container(
      width: 145,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kDealerSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.15),
            kDealerSurface,
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
        mainAxisAlignment: MainAxisAlignment.start,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title, 
                  style: const TextStyle(color: kDealerTextMuted, fontSize: 13, height: 1.2), 
                  maxLines: 1, 
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value, 
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }
}
