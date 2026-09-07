import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'widgets/consumer_bottom_nav.dart';
import 'widgets/consumer_theme.dart';
import '../scan/scanner_screen.dart';
import 'providers/home_stats_provider.dart';
import 'providers/scan_count_provider.dart';
import 'data/home_stats_repository.dart';
import '../history/history_screen.dart';
import '../store/store_screen.dart' hide SectionHeader, GridProductCard;
import '../core/widgets/user_avatar.dart';
import '../auth/user_profile_screen.dart';
import 'widgets/home_data_widgets.dart';
import '../auth/presentation/auth_controller.dart';
import '../dashboard/dashboard_screen.dart';
import '../farm/presentation/home/farmer_home_screen.dart';
import '../supply/presentation/driver/driver_home_screen.dart';
import '../supply/presentation/warehouse/warehouse_home_screen.dart';
import '../supply/presentation/dealer/dealer_home_screen.dart';
import '../kcs/presentation/kcs_dashboard_screen.dart';
import 'data/weather_location_store.dart';
import 'data/consumer_models.dart';
import '../core/navigation.dart';

class ModernHomeScreen extends ConsumerStatefulWidget {
  const ModernHomeScreen({super.key});

  @override
  ConsumerState<ModernHomeScreen> createState() => _ModernHomeScreenState();
}

class _ModernHomeScreenState extends ConsumerState<ModernHomeScreen> {
  int _currentIndex = 0;
  double _weatherLat = 21.0285;
  double _weatherLon = 105.8542;
  String _weatherLocationName = 'Hà Nội';

  @override
  void initState() {
    super.initState();
    _loadSelectedWeatherLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).refreshProfile();
    });
  }

  Future<void> _loadSelectedWeatherLocation() async {
    try {
      final selected = await ref.read(weatherLocationStoreProvider).getSelectedLocation();
      if (!mounted) return;
      setState(() {
        _weatherLat = selected.lat;
        _weatherLon = selected.lon;
        _weatherLocationName = selected.name;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ConsumerTheme.backgroundDark,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(child: _buildBody()),
      ),
      bottomNavigationBar: ConsumerBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        onScanTapped: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScannerScreen()),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return const HistoryScreen();
      case 3:
        return const StoreScreen();
      case 4:
        return const UserProfileScreen();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    return _buildConsumerHomeTab();
  }

  Widget _buildConsumerHomeTab() {
    final partnersAsync = ref.watch(topPartnersProvider);
    final productsAsync = ref.watch(featuredProductsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(homeStatsProvider);
        ref.invalidate(topPartnersProvider);
        ref.invalidate(featuredProductsProvider);
      },
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _ModernHeroSection()),
          SliverToBoxAdapter(
            child: _ModernScanButton(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScannerScreen()),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: ConsumerWeatherSummarySection(
              lat: _weatherLat,
              lon: _weatherLon,
              locationName: _weatherLocationName,
              onReturnedFromDetail: _loadSelectedWeatherLocation,
            ),
          ),
          const SliverToBoxAdapter(child: _ModernStatsRow()),
          const SliverToBoxAdapter(child: _ModernScanChart()),
          const SliverToBoxAdapter(child: _ModernCertifications()),
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),

          const SliverToBoxAdapter(
            child: SectionHeader(title: 'HTX/Doanh Nghiệp Uy Tín'),
          ),
          SliverToBoxAdapter(
            child: partnersAsync.when(
              data: (partners) => PartnerList(
                partners: partners,
                onPartnerTap: (partner) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xem đối tác: ${partner.name}')));
                },
              ),
              loading: () => const PartnersSkeleton(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          const SliverToBoxAdapter(
            child: SectionHeader(title: 'Sản phẩm nổi bật'),
          ),
          productsAsync.when(
            data: (products) => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.68,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => GridProductCard(
                    product: products[index],
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xem SP: ${products[index].name}')));
                    },
                  ),
                  childCount: products.length,
                ),
              ),
            ),
            loading: () => const SliverToBoxAdapter(child: ProductsSkeleton()),
            error: (_, __) => const SliverToBoxAdapter(
              child: Center(child: Text('Không thể tải sản phẩm')),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }
}

// --- WIDGETS ---

class _ModernHeroSection extends ConsumerWidget {
  const _ModernHeroSection();

  String _getFriendlyRole(String role) {
    final map = {
      'ADMIN': 'Quản trị viên',
      'TENANT_ADMIN': 'Quản trị viên HTX',
      'TENANT': 'Chủ Doanh nghiệp',
      'MANAGER': 'Cán bộ Quản lý',
      'FARMER': 'Nông dân',
      'TEAM_LEADER': 'Đội trưởng',
      'DRIVER': 'Tài xế',
      'TRANSPORTER': 'Đơn vị vận chuyển',
      'WAREHOUSE_MANAGER': 'Thủ kho',
      'KCS_STAFF': 'Nhân viên KCS',
      'DEALER': 'Đại lý',
    };
    return map[role.toUpperCase()] ?? role;
  }

  void _navigateToRole(BuildContext context, User user) {
    final role = user.role.toUpperCase();
    if (['FARMER', 'TEAM_LEADER'].contains(role)) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FarmerHomeScreen()),
      );
    } else if (['DRIVER', 'TRANSPORTER'].contains(role)) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
      );
    } else if (role == 'WAREHOUSE_MANAGER') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WarehouseHomeScreen()),
      );
    } else if (role == 'DEALER') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DealerHomeScreen()),
      );
    } else if (role == 'KCS_STAFF') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const KcsDashboardScreen()),
      );
    } else if (['MANAGER', 'ADMIN', 'TENANT_ADMIN', 'TENANT'].contains(role)) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DashboardScreen(userProfile: user.toJson())),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanCount = ref.watch(scanCountProvider);
    final authState = ref.watch(authControllerProvider);
    final user = authState.value;

    final displayName = user != null ? user.fullName : 'Người dùng';
    final displayRole = user != null ? _getFriendlyRole(user.role) : 'Tài khoản khách';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    if (user != null) {
                      _navigateToRole(context, user);
                    }
                  },
                  child: Image.asset(
                    'assets/images/logo_w.png',
                    height: 60,
                    fit: BoxFit.contain,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B2738),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: const Icon(Icons.notifications_none, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    UserAvatar(
                      avatarUrl: user?.avatar,
                      fullName: user?.fullName,
                      size: 44,
                      borderColor: ConsumerTheme.actionBlue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Greeting Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InkWell(
              onTap: user != null ? () => _navigateToRole(context, user) : null,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF13223A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Xin chào,', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: ConsumerTheme.actionBlue.withOpacity(0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8, height: 8,
                                      decoration: const BoxDecoration(color: ConsumerTheme.actionBlue, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(displayRole, style: const TextStyle(color: ConsumerTheme.actionBlue, fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (user != null) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  'Chạm để vào Bảng làm việc ➔',
                                  style: TextStyle(
                                    color: ConsumerTheme.actionBlue.withOpacity(0.9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    UserAvatar(
                      avatarUrl: user?.avatar,
                      fullName: user?.fullName,
                      size: 60,
                      borderColor: ConsumerTheme.actionBlue,
                      borderWidth: 2.5,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                        );
                      },
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

class _ModernScanButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ModernScanButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: ConsumerTheme.actionBlue,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: ConsumerTheme.actionBlue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Quét mã AI Phát hiện lỗi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              const Icon(Icons.chevron_right, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class ConsumerWeatherSummarySection extends ConsumerStatefulWidget {
  final double lat;
  final double lon;
  final String locationName;
  final Future<void> Function()? onReturnedFromDetail;

  const ConsumerWeatherSummarySection({
    super.key,
    required this.lat,
    required this.lon,
    required this.locationName,
    this.onReturnedFromDetail,
  });

  @override
  ConsumerState<ConsumerWeatherSummarySection> createState() => _ConsumerWeatherSummarySectionState();
}

class _ConsumerWeatherSummarySectionState extends ConsumerState<ConsumerWeatherSummarySection> {
  int _weatherRefreshNonce = 0;
  WeatherSummary? _lastWeatherSummary;

  @override
  void didUpdateWidget(covariant ConsumerWeatherSummarySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lat != widget.lat || oldWidget.lon != widget.lon) {
      _lastWeatherSummary = null;
      _weatherRefreshNonce = 0;
    }
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'warning':
        return const Color(0xFFEF4444);
      case 'caution':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF20A376);
    }
  }

  IconData _weatherIcon(String icon) {
    if (icon.contains('rain')) return Icons.water_drop;
    if (icon.contains('thunder')) return Icons.bolt;
    if (icon.contains('cloud')) return Icons.cloud;
    return Icons.wb_sunny;
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(
      weatherSummaryProvider((
        lat: widget.lat,
        lon: widget.lon,
        refreshNonce: _weatherRefreshNonce,
      )),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: summaryAsync.when(
        data: (data) {
          data ??= _lastWeatherSummary;
          if (data == null) {
            return const SizedBox.shrink();
          }
          _lastWeatherSummary = data;
          if (_weatherRefreshNonce > 0 && !data.fromCache) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _weatherRefreshNonce = 0);
            });
          }

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A2E40), Color(0xFF132436)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thời tiết tại ${widget.locationName}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${data.temp.toStringAsFixed(0)}°C',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            data.description,
                            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Icon(_weatherIcon(data.icon), color: const Color(0xFFF59E0B), size: 40),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () async {
                            await context.push(
                              '/consumer/weather?lat=${widget.lat}&lon=${widget.lon}',
                            );
                            await widget.onReturnedFromDetail?.call();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF20A376),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text(
                            'Xem thêm',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _metric('Mưa', '${data.rainChance}%'),
                    const SizedBox(width: 8),
                    _metric('Độ ẩm', '${data.humidity}%'),
                    const SizedBox(width: 8),
                    _metric('Gió', '${data.windSpeed} km/h'),
                  ],
                ),
                if (data.topAlerts.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...data.topAlerts.map(
                    (alert) => GestureDetector(
                      onTap: () async {
                        await context.push(
                          '/consumer/weather?lat=${widget.lat}&lon=${widget.lon}',
                        );
                        await widget.onReturnedFromDetail?.call();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _severityColor(alert.severity).withOpacity(0.4)),
                          color: _severityColor(alert.severity).withOpacity(0.1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert.title,
                              style: TextStyle(
                                color: _severityColor(alert.severity),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              alert.message,
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => Container(
          height: 110,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1D263B),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF20A376)),
        ),
        error: (_, __) {
          final data = _lastWeatherSummary;
          if (data == null) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A2E40), Color(0xFF132436)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Thời tiết tại ${widget.locationName}: ${data.temp.toStringAsFixed(0)}°C, ${data.description}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _weatherRefreshNonce++),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF20A376),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _ModernStatsRow extends ConsumerWidget {
  const _ModernStatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(homeStatsProvider);

    return statsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox(),
      data: (stats) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatBlock(stats.totalVerifications.formatted, stats.totalVerifications.label),
            const SizedBox(width: 12),
            _buildStatBlock(stats.successRate.formatted, stats.successRate.label),
            const SizedBox(width: 12),
            _buildStatBlock(stats.totalProducts.formatted, stats.totalProducts.label),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBlock(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1D263B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _ModernScanChart extends ConsumerWidget {
  const _ModernScanChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(homeStatsProvider);

    return statsAsync.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (stats) => _buildChart(stats.chart),
    );
  }

  Widget _buildChart(List<ChartItem> chartData) {
    final maxY = chartData.isEmpty ? 200.0 : chartData.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1D263B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lượt xác thực 7 ngày qua', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 24),
            SizedBox(
              height: 100,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= chartData.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(chartData[index].label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: chartData.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.value,
                          color: ConsumerTheme.actionBlue,
                          width: e.key >= 5 ? 24 : 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernCertifications extends ConsumerWidget {
  const _ModernCertifications();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(homeStatsProvider);

    return statsAsync.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (stats) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chứng nhận được xác thực', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...stats.certifications.map((cert) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D263B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified, color: ConsumerTheme.actionBlue),
                    const SizedBox(width: 12),
                    Expanded(child: Text(cert.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    Text('${cert.productCount} SP', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}
