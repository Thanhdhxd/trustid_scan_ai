import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/api_client.dart';
import 'package:trustid_scan_ai/core/widgets/user_avatar.dart';
import 'package:trustid_scan_ai/dashboard/placeholder_screen.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/home/modern_home_screen.dart';
import 'package:trustid_scan_ai/auth/user_profile_screen.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';
import 'package:trustid_scan_ai/scan/scanner_screen.dart';

const Color kPrimaryColor = Color(0xFF00875A); // Neon Green
const Color kBackgroundDark = Color(0xFF0F2B46); // Deep Charcoal/Forest Green
const Color kSurfaceDark = Color(0xFF16325B); // Slightly lighter for cards
const Color kTextLight = Color(0xFFE8EDF3);
const Color kTextGray = Color(0xFF94A3B8); // slate-400

class DashboardScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? userProfile;

  const DashboardScreen({Key? key, this.userProfile}) : super(key: key);

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Future<List<dynamic>>? _statsFuture;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    _statsFuture = Future.wait([
      companyApi.get('/tenant/dashboard/summary'),
      companyApi.get('/tenant/dashboard/supply-stats'),
    ]);
  }

  void _showUnavailableSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tính năng chưa khả dụng trên bản Scan AI')),
    );
  }

  Widget _buildIconBtn(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: kTextGray),
      onPressed: onTap,
    );
  }

  Widget _buildDetailedStatCard({
    required String title,
    required String total,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(
            total,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: kTextLight,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: kTextGray,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kTextLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: kTextGray,
                ),
              ),
            ],
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    final role = user?.role.toUpperCase() ?? widget.userProfile?['role']?.toString().toUpperCase() ?? 'MANAGER';
    final fullName = user?.fullName ?? widget.userProfile?['fullName']?.toString() ?? 'Người dùng';
    final avatar = user?.avatar ?? widget.userProfile?['avatar']?.toString();

    return Scaffold(
      backgroundColor: kBackgroundDark,
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
                  color: kBackgroundDark.withOpacity(0.95),
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          UserAvatar(
                            avatarUrl: avatar,
                            fullName: fullName,
                            size: 48,
                            borderColor: kPrimaryColor,
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
                              const Text(
                                'Xin chào,',
                                style: TextStyle(
                                  color: kTextGray,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                fullName,
                                style: const TextStyle(
                                  color: kTextLight,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        _buildIconBtn(Icons.qr_code_scanner, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ScannerScreen()),
                          );
                        }),
                        const SizedBox(width: 8),
                        _buildIconBtn(Icons.home_outlined, () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const ModernHomeScreen()),
                            (route) => false,
                          );
                        }),
                        const SizedBox(width: 8),
                        _buildIconBtn(Icons.logout, () async {
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const ModernHomeScreen()),
                              (route) => false,
                            );
                          }
                          await ref.read(authControllerProvider.notifier).logout();
                        }),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        'Chỉ số hôm nay',
                        'Cập nhật 5p trước',
                        trailing: TextButton(
                          onPressed: _showUnavailableSnackbar,
                          child: const Text('Chi tiết >', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 130,
                        child: FutureBuilder(
                          future: _statsFuture,
                          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                            }
                            if (snapshot.hasError) {
                              return Center(child: Text('Lỗi tải dữ liệu', style: const TextStyle(color: Colors.redAccent)));
                            }

                            final summaryData = snapshot.data?[0]?.data;
                            final supplyData = snapshot.data?[1]?.data;

                            final totalMembers = summaryData?['members']?['total']?.toString() ?? '0';
                            final totalProducts = summaryData?['products']?['total']?.toString() ?? '0';
                            final totalSeasons = summaryData?['seasons']?['total']?.toString() ?? '0';
                            final totalStamps = supplyData?['codes']?['total']?.toString() ?? '0';

                            return ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              children: [
                                _buildDetailedStatCard(
                                  title: 'Thành viên',
                                  total: totalMembers,
                                  icon: Icons.person_outline,
                                  color: Colors.blueAccent,
                                ),
                                const SizedBox(width: 16),
                                _buildDetailedStatCard(
                                  title: 'Sản phẩm',
                                  total: totalProducts,
                                  icon: Icons.shopping_bag_outlined,
                                  color: Colors.orangeAccent,
                                ),
                                const SizedBox(width: 16),
                                _buildDetailedStatCard(
                                  title: 'Mùa vụ',
                                  total: totalSeasons,
                                  icon: Icons.calendar_month_outlined,
                                  color: Colors.greenAccent,
                                ),
                                const SizedBox(width: 16),
                                _buildDetailedStatCard(
                                  title: 'Mã tem',
                                  total: totalStamps,
                                  icon: Icons.sell_outlined,
                                  color: Colors.amberAccent,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 4. Quick Tasks Tabs
                      _QuickTasksWidget(role: role),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickTasksWidget extends StatefulWidget {
  final String role;
  const _QuickTasksWidget({required this.role});

  @override
  State<_QuickTasksWidget> createState() => _QuickTasksWidgetState();
}

class _QuickTasksWidgetState extends State<_QuickTasksWidget> {
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
          color: kSurfaceDark,
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
                      color: kTextLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: kTextGray,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kTextGray, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = <Map<String, dynamic>>[];
    
    categories.add({
      'title': 'Thành Phẩm',
      'icon': Icons.inventory_2,
      'items': [
        _buildSleekListTile(context, 'Tạo Lệnh Sản Xuất', 'Lập kế hoạch sản xuất mới', Icons.add_circle_outline, Colors.teal[400]!, () => context.push('/manager/production-orders/create')),
        _buildSleekListTile(context, 'Đóng bao', 'Tạo bao thành phẩm (A1, A2)', Icons.view_in_ar, kPrimaryColor, () => context.push('/manager/orders-bag-linking')),
        _buildSleekListTile(context, 'Xếp Pallet', 'Đóng gói pallet', Icons.move_to_inbox, Colors.teal[400]!, () => context.push('/manager/orders-pallet-linking')),
        _buildSleekListTile(context, 'Quản lý Pallet', 'Chỉnh sửa, Xóa', Icons.view_module, Colors.blueGrey[400]!, () => context.push('/manager/pallets')),
      ],
    });

    categories.add({
      'title': 'Kho & Vận Chuyển',
      'icon': Icons.warehouse,
      'items': [
        _buildSleekListTile(context, 'Lệnh xuất hàng', 'Lập lệnh điều chuyển (A3)', Icons.post_add, Colors.orange[400]!, () => context.push('/manager/export-orders')),
        _buildSleekListTile(context, 'Phiếu xuất kho', 'Thực thi xuất kho (A4)', Icons.receipt_long, Colors.redAccent[200]!, () => context.push('/manager/export-sheets')),
      ],
    });

    categories.add({
      'title': 'Bán TP B2B',
      'icon': Icons.category,
      'items': [
        _buildSleekListTile(context, 'Quản lý Bán TP B2B', 'Nhập/Xuất kho B2B (B1, B2)', Icons.sync_alt, Colors.indigo[400]!, () => context.push('/manager/semi-finished')),
        _buildSleekListTile(context, 'Xếp Pallet BTP', 'Đóng gói pallet BTP', Icons.pallet, Colors.blue[400]!, () => context.push('/manager/sf-pallets')),
      ],
    });

    categories.add({
      'title': 'Kiểm Định & QC',
      'icon': Icons.verified,
      'items': [
        _buildSleekListTile(context, 'Kiểm định KCS', 'Danh sách thửa & kiểm định', Icons.fact_check_outlined, Colors.teal[400]!, () => context.push('/kcs')),
        _buildSleekListTile(context, 'Nhân viên KCS', 'Quản lý nhân sự kiểm định', Icons.badge_outlined, Colors.cyan[400]!, () => context.push('/manager/kcs-staff')),
      ],
    });

    if (_selectedTabIndex >= categories.length) {
      _selectedTabIndex = 0;
    }

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
              color: kTextLight,
            ),
          ),
        ),
        const SizedBox(height: 16),
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
                    color: isSelected ? kPrimaryColor : kSurfaceDark,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isSelected ? kPrimaryColor : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        cat['icon'] as IconData,
                        size: 18,
                        color: isSelected ? Colors.white : kTextGray,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cat['title'] as String,
                        style: TextStyle(
                          color: isSelected ? Colors.white : kTextGray,
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
