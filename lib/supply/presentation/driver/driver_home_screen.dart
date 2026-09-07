import 'dart:ui' as ui;
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';
import 'package:trustid_scan_ai/auth/user_profile_screen.dart';
import 'package:trustid_scan_ai/home/modern_home_screen.dart';
import 'package:trustid_scan_ai/farm/data/farm_repository.dart';
import 'package:trustid_scan_ai/core/api_client.dart';
import 'package:trustid_scan_ai/core/widgets/user_avatar.dart';
import 'package:trustid_scan_ai/scan/scanner_screen.dart';
import 'driver_controller.dart';
import '../../domain/shipment.dart';

final driverShipmentDetailProvider = FutureProvider.autoDispose.family<Shipment, String>((ref, id) async {
  final response = await companyApi.get('/shipments-v2/$id');
  return Shipment.fromJson(response.data);
});

const Color kPrimaryColor = Color(0xFF00875A);
const Color kBackgroundDark = Color(0xFF0F2B46);
const Color kSurfaceDark = Color(0xFF16325B);
const Color kTextLight = Color(0xFFE8EDF3);
const Color kTextGray = Color(0xFF94A3B8);

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shipmentsAsync = ref.watch(shipmentsProvider);
    final user = ref.watch(authControllerProvider).value;

    ref.listen(driverControllerProvider, (prev, next) {
      next.whenOrNull(
        error: (err, stack) {
          String errMsg = 'Lỗi: $err';
          if (err.toString().contains('403')) {
            errMsg = 'Bạn không phải tài xế được chỉ định cho chuyến hàng này!';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errMsg), backgroundColor: Colors.red),
          );
        },
        data: (_) {
          ref.invalidate(shipmentsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thành công!'), backgroundColor: Colors.green),
          );
        },
      );
    });

    return Scaffold(
      backgroundColor: kBackgroundDark,
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserProfileScreen())),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserAvatar(
                avatarUrl: user?.avatar,
                fullName: user?.fullName ?? 'Tài xế',
                size: 38,
                borderColor: kPrimaryColor,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserProfileScreen())),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🚛 Tài xế', style: TextStyle(color: kTextLight, fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(user?.fullName ?? '', style: const TextStyle(color: kTextGray, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        centerTitle: false,
        backgroundColor: kBackgroundDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextLight),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: kTextLight),
            tooltip: 'Quét mã',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScannerScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.home_outlined, color: kTextLight),
            tooltip: 'Trang chủ',
            onPressed: () {
              ref.invalidate(shipmentsProvider);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const ModernHomeScreen()),
                (route) => false,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: kTextLight),
            tooltip: 'Làm mới',
            onPressed: () => ref.invalidate(shipmentsProvider),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
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
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: kTextLight,
          unselectedLabelColor: kTextGray,
          indicatorColor: kPrimaryColor,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt), text: 'Tất cả'),
            Tab(icon: Icon(Icons.inbox), text: 'Chờ nhận'),
            Tab(icon: Icon(Icons.local_shipping), text: 'Đang giao'),
            Tab(icon: Icon(Icons.check_circle), text: 'Đã giao'),
          ],
        ),
      ),
      body: shipmentsAsync.when(
        data: (list) {
          final inTransit = list.where((s) => ['IN_TRANSIT', 'SHIPPING', 'PENDING_DEALER_CONFIRM'].contains(s.status.toUpperCase())).toList();
          final delivered = list.where((s) => ['DELIVERED', 'AT_DEALER', 'COMPLETED', 'DONE'].contains(s.status.toUpperCase())).toList();
          final waiting = list.where((s) => !inTransit.contains(s) && !delivered.contains(s)).toList();

          return Column(
            children: [
              _StatsRow(
                all: list.length,
                waiting: waiting.length,
                transit: inTransit.length,
                delivered: delivered.length,
                onTabTap: (index) => _tabController.animateTo(index),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ShipmentList(shipments: list, type: _ListType.all),
                    _ShipmentList(shipments: waiting, type: _ListType.waiting),
                    _ShipmentList(shipments: inTransit, type: _ListType.inTransit),
                    _ShipmentList(shipments: delivered, type: _ListType.delivered),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
        error: (e, s) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Lỗi: $e', textAlign: TextAlign.center, style: const TextStyle(color: kTextLight)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(shipmentsProvider),
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, foregroundColor: Colors.white),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int all, waiting, transit, delivered;
  final Function(int) onTabTap;
  const _StatsRow({required this.all, required this.waiting, required this.transit, required this.delivered, required this.onTabTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _StatCard(label: 'Tất cả', count: all, color: Colors.grey, onTap: () => onTabTap(0)),
          const SizedBox(width: 8),
          _StatCard(label: 'Chờ nhận', count: waiting, color: Colors.orangeAccent, onTap: () => onTabTap(1)),
          const SizedBox(width: 8),
          _StatCard(label: 'Đang giao', count: transit, color: Colors.blueAccent, onTap: () => onTabTap(2)),
          const SizedBox(width: 8),
          _StatCard(label: 'Đã giao', count: delivered, color: Colors.greenAccent, onTap: () => onTabTap(3)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;
  
  const _StatCard({required this.label, required this.count, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: kSurfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Text('$count', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextLight)),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ListType { all, waiting, inTransit, delivered }

class _ShipmentList extends ConsumerWidget {
  final List<Shipment> shipments;
  final _ListType type;
  const _ShipmentList({required this.shipments, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (shipments.isEmpty) {
      return const Center(child: Text('Trống', style: TextStyle(color: kTextGray)));
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(shipmentsProvider),
      color: kPrimaryColor,
      backgroundColor: kSurfaceDark,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: shipments.length,
        itemBuilder: (context, index) {
          final s = shipments[index];
          return _ShipmentCard(shipment: s, type: type);
        },
      ),
    );
  }
}

class _ShipmentCard extends ConsumerWidget {
  final Shipment shipment;
  final _ListType type;
  const _ShipmentCard({required this.shipment, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(driverControllerProvider).isLoading;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: kSurfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetail(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    shipment.trackingCode,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent),
                  ),
                  _StatusChip(status: shipment.status, type: type),
                ],
              ),
              if (type == _ListType.delivered) ...[
                const SizedBox(height: 8),
                if (shipment.dealerName != null) _InfoRow(Icons.store, 'Đại lý: ${shipment.dealerName}'),
                if (shipment.endTime != null) _InfoRow(Icons.access_time, 'Giao lúc: ${_formatDate(shipment.endTime!)}'),
              ] else if (type == _ListType.inTransit) ...[
                const SizedBox(height: 8),
                _InfoRow(Icons.store, 'Đại lý: ${shipment.dealerName ?? '---'}'),
                if (shipment.dealerAddress != null) _InfoRow(Icons.location_on, 'Địa chỉ: ${shipment.dealerAddress}'),
                if (shipment.dealerContactName != null) _InfoRow(Icons.person, 'Liên hệ: ${shipment.dealerContactName}'),
                if (shipment.dealerPhone != null) _InfoRow(Icons.phone, 'SĐT: ${shipment.dealerPhone}'),
                _InfoRow(Icons.local_shipping, 'Xe: ${shipment.vehiclePlate}'),
                _InfoRow(Icons.inventory_2, 'Hàng: ${shipment.expectedItems.length} sản phẩm'),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        shipment.startTime != null ? 'Nhận lúc: ${_formatDate(shipment.startTime!)}' : '',
                        style: const TextStyle(color: kTextGray, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (shipment.status == 'PENDING_DEALER_CONFIRM')
                          ElevatedButton.icon(
                            icon: const Icon(Icons.hourglass_empty, size: 16),
                            label: const Text('Đợi đại lý'),
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.withOpacity(0.5),
                              disabledForegroundColor: Colors.white70,
                              elevation: 0,
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle, size: 16),
                            label: const Text('Đã đến đại lý'),
                            onPressed: isLoading ? null : () => _confirmDelivery(context, ref),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ] else if (type == _ListType.waiting) ...[
                const SizedBox(height: 8),
                if (shipment.sourceWarehouseName != null) _InfoRow(Icons.warehouse, 'Kho: ${shipment.sourceWarehouseName}'),
                if (shipment.dealerName != null) _InfoRow(Icons.store, 'Đại lý: ${shipment.dealerName}'),
                if (shipment.dealerAddress != null) _InfoRow(Icons.location_on, 'Địa chỉ: ${shipment.dealerAddress}'),
                if (shipment.dealerContactName != null) _InfoRow(Icons.person, 'Liên hệ: ${shipment.dealerContactName}'),
                if (shipment.dealerPhone != null) _InfoRow(Icons.phone, 'SĐT: ${shipment.dealerPhone}'),
                _InfoRow(Icons.local_shipping, 'Xe: ${shipment.vehiclePlate}'),
                _InfoRow(Icons.inventory_2, 'Hàng: ${shipment.expectedItems.length} sản phẩm'),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Nhận hàng'),
                    onPressed: isLoading ? null : () => _confirmPickup(context, ref),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                _InfoRow(Icons.store, 'Đại lý: ${shipment.dealerName ?? '---'}'),
                if (shipment.dealerAddress != null) _InfoRow(Icons.location_on, 'Địa chỉ: ${shipment.dealerAddress}'),
                _InfoRow(Icons.local_shipping, 'Xe: ${shipment.vehiclePlate}'),
                _InfoRow(Icons.inventory_2, 'Hàng: ${shipment.expectedItems.length} sản phẩm'),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        shipment.startTime != null ? _formatDate(shipment.startTime!) : (shipment.createdAt != null ? _formatDate(shipment.createdAt!) : ''),
                        style: const TextStyle(color: kTextGray, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (['WAITING_DRIVER'].contains(shipment.status.toUpperCase()))
                          ElevatedButton.icon(
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('Nhận hàng'),
                            onPressed: isLoading ? null : () => _confirmPickup(context, ref),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orangeAccent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                          ),
                        if (['IN_TRANSIT', 'SHIPPING'].contains(shipment.status.toUpperCase()))
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle, size: 16),
                            label: const Text('Đã đến đại lý'),
                            onPressed: isLoading ? null : () => _confirmDelivery(context, ref),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                          ),
                        if (shipment.status == 'PENDING_DEALER_CONFIRM')
                          ElevatedButton.icon(
                            icon: const Icon(Icons.hourglass_empty, size: 16),
                            label: const Text('Đợi đại lý'),
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.withOpacity(0.5),
                              disabledForegroundColor: Colors.white70,
                              elevation: 0,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmPickup(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nhận hàng', style: TextStyle(color: kTextLight)),
        content: Text('Xác nhận nhận hàng phiếu ${shipment.trackingCode}?\nHệ thống sẽ lấy vị trí GPS.', style: const TextStyle(color: kTextLight)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy', style: TextStyle(color: kTextGray))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(driverControllerProvider.notifier).confirmPickup(shipment.id);
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  void _confirmDelivery(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DeliveryHandshakeDialog(shipment: shipment),
    );
  }

  Widget _buildStepper(String status) {
    int currentStep = 1;
    if (['IN_TRANSIT', 'SHIPPING'].contains(status.toUpperCase())) currentStep = 2;
    else if (status.toUpperCase() == 'PENDING_DEALER_CONFIRM') currentStep = 3;
    else if (['DELIVERED', 'AT_DEALER', 'COMPLETED', 'DONE'].contains(status.toUpperCase())) currentStep = 4;

    Widget stepCircle(int step, String title) {
      bool isActive = currentStep >= step;
      return Column(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isActive ? Colors.blueAccent : kSurfaceDark,
            child: Text('$step', style: TextStyle(color: isActive ? Colors.white : kTextGray, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 6),
          Text(title, style: TextStyle(color: isActive ? Colors.blueAccent : kTextGray, fontSize: 11, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
        ],
      );
    }

    Widget line(int step) {
      bool isActive = currentStep > step;
      return Expanded(
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          height: 2,
          color: isActive ? Colors.blueAccent : kSurfaceDark,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          stepCircle(1, 'Tạo phiếu'),
          line(1),
          stepCircle(2, 'Tài xế nhận'),
          line(2),
          stepCircle(3, 'Tài xế giao'),
          line(3),
          stepCircle(4, 'Đại lý nhận'),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kBackgroundDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Consumer(
          builder: (context, ref, _) {
            final detailAsync = ref.watch(driverShipmentDetailProvider(shipment.id));
            return detailAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
              error: (e, s) => Center(child: Text('Lỗi tải dữ liệu: $e', style: const TextStyle(color: Colors.redAccent))),
              data: (detailedShipment) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Chi tiết phiếu ${detailedShipment.trackingCode}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextLight)),
                        IconButton(icon: const Icon(Icons.close, color: kTextGray), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStepper(detailedShipment.status),
                            const SizedBox(height: 12),
                            _DetailRowObj('Mã phiếu', Text(detailedShipment.trackingCode, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))),
                            _DetailRowObj('Trạng thái', Align(alignment: Alignment.centerLeft, child: _StatusChip(status: detailedShipment.status, type: _ListType.all))),
                            _DetailRowObj('Biển số xe', Text(detailedShipment.vehiclePlate, style: const TextStyle(color: kTextLight, fontWeight: FontWeight.w500))),
                            if (detailedShipment.sourceWarehouseName != null) _DetailRowObj('Kho xuất', Text(detailedShipment.sourceWarehouseName!, style: const TextStyle(color: kTextLight, fontWeight: FontWeight.w500))),
                            _DetailRowObj('Đại lý nhận', Text(detailedShipment.dealerName ?? '---', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold))),
                            if (detailedShipment.dealerAddress != null) _DetailRowObj('Địa chỉ', Text(detailedShipment.dealerAddress!, style: const TextStyle(color: kTextLight, fontWeight: FontWeight.w500))),
                            if (detailedShipment.dealerContactName != null) _DetailRowObj('Người liên hệ', Text(detailedShipment.dealerContactName!, style: const TextStyle(color: kTextLight, fontWeight: FontWeight.w500))),
                            if (detailedShipment.dealerPhone != null) _DetailRowObj('Số điện thoại', Text(detailedShipment.dealerPhone!, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))),
                            if (detailedShipment.startTime != null) _DetailRowObj('Bắt đầu', Text(_formatDate(detailedShipment.startTime!), style: const TextStyle(color: kTextLight, fontWeight: FontWeight.w500))),
                            if (detailedShipment.endTime != null) _DetailRowObj('Hoàn thành', Text(_formatDate(detailedShipment.endTime!), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                            
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                const Icon(Icons.inventory_2, color: Colors.orangeAccent, size: 20),
                                const SizedBox(width: 8),
                                Text('Danh sách hàng hóa (${detailedShipment.expectedItems.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextLight)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: const BoxDecoration(color: kSurfaceDark, borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
                                    child: const Row(
                                      children: [
                                        SizedBox(width: 30, child: Text('#', style: TextStyle(color: kTextGray, fontWeight: FontWeight.bold))),
                                        Expanded(child: Text('Sản phẩm', style: TextStyle(color: kTextGray, fontWeight: FontWeight.bold))),
                                        SizedBox(width: 80, child: Text('Số lượng', textAlign: TextAlign.right, style: TextStyle(color: kTextGray, fontWeight: FontWeight.bold))),
                                      ],
                                    ),
                                  ),
                                  if (detailedShipment.expectedItems.isEmpty)
                                    const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Không có chi tiết', style: TextStyle(color: kTextGray))))
                                  else
                                    ...detailedShipment.expectedItems.asMap().entries.map((entry) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white24))),
                                      child: Row(
                                        children: [
                                          SizedBox(width: 30, child: Text('${entry.key + 1}', style: const TextStyle(color: kTextLight))),
                                          Expanded(child: Text(entry.value.productName.isNotEmpty ? entry.value.productName : '---', style: const TextStyle(color: kTextLight))),
                                          SizedBox(width: 80, child: Text('${entry.value.quantity}', textAlign: TextAlign.right, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))),
                                        ],
                                      ),
                                    )),
                                ],
                              ),
                            ),
                            if ((detailedShipment.signature != null && detailedShipment.signature!.isNotEmpty) || 
                                (detailedShipment.evidenceUrl != null && detailedShipment.evidenceUrl!.isNotEmpty)) ...[
                              const SizedBox(height: 24),
                              Row(
                                children: const [
                                  Icon(Icons.verified_user_outlined, color: Colors.greenAccent, size: 20),
                                  SizedBox(width: 8),
                                  Text('Minh chứng giao nhận', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextLight)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: kSurfaceDark,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (detailedShipment.signature != null && detailedShipment.signature!.isNotEmpty)
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Chữ ký nhận:', style: TextStyle(color: kTextGray, fontSize: 12)),
                                            const SizedBox(height: 8),
                                            Container(
                                              height: 100,
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              padding: const EdgeInsets.all(4),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(6),
                                                child: Image.network(
                                                  detailedShipment.signature!,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, __, ___) => const Center(
                                                    child: Icon(Icons.broken_image, color: Colors.grey),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (detailedShipment.signature != null && detailedShipment.signature!.isNotEmpty && 
                                        detailedShipment.evidenceUrl != null && detailedShipment.evidenceUrl!.isNotEmpty)
                                      const SizedBox(width: 16),
                                    if (detailedShipment.evidenceUrl != null && detailedShipment.evidenceUrl!.isNotEmpty)
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Ảnh hóa đơn:', style: TextStyle(color: kTextGray, fontSize: 12)),
                                            const SizedBox(height: 8),
                                            Container(
                                              height: 100,
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: Colors.white12,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.white24),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.network(
                                                  detailedShipment.evidenceUrl!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => const Center(
                                                    child: Icon(Icons.broken_image, color: Colors.white24),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (detailedShipment.dealerPhone != null)
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _callDealer(detailedShipment.dealerPhone!);
                                    },
                                    icon: const Icon(Icons.phone),
                                    label: const Text('Gọi đại lý', style: TextStyle(fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: kTextLight,
                                      side: const BorderSide(color: Colors.white24),
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                    ),
                                  ),
                                if (detailedShipment.dealerPhone != null && detailedShipment.status == 'WAITING_DRIVER')
                                  const SizedBox(width: 16),
                                if (detailedShipment.status == 'WAITING_DRIVER')
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      if (ref.read(driverControllerProvider).isLoading) return;
                                      Navigator.pop(ctx);
                                      _confirmPickup(context, ref);
                                    },
                                    icon: const Icon(Icons.download),
                                    label: const Text('Nhận hàng', style: TextStyle(fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orangeAccent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                      elevation: 0,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _callDealer(String phone) => launchUrl(Uri.parse('tel:$phone'));
  String _formatDate(DateTime dt) {
    final localDt = dt.toLocal();
    return '${localDt.hour.toString().padLeft(2, '0')}:${localDt.minute.toString().padLeft(2, '0')}:${localDt.second.toString().padLeft(2, '0')} ${localDt.day}/${localDt.month}/${localDt.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: kTextGray),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: kTextGray))),
        ],
      ),
    );
  }
}

class _DetailRowObj extends StatelessWidget {
  final String label;
  final Widget child;
  const _DetailRowObj(this.label, this.child);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: kTextGray, fontSize: 13))),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final _ListType type;
  const _StatusChip({required this.status, required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'WAITING_DRIVER' => (type == _ListType.all ? 'Chờ tài xế nhận' : 'Chờ nhận', Colors.orangeAccent),
      'IN_TRANSIT' => ('Đang giao', Colors.blueAccent),
      'PENDING_DEALER_CONFIRM' => ('Chờ đại lý xác nhận', type == _ListType.all ? Colors.grey : Colors.indigoAccent),
      'READY_FOR_PICKUP' => ('Sẵn sàng', Colors.amberAccent),
      'AT_DEALER' => (type == _ListType.all ? 'Đã nhập kho đại lý' : 'Đã giao ✓', kPrimaryColor),
      'DELIVERED' => (type == _ListType.all ? 'Đã nhập kho đại lý' : 'Đã giao ✓', kPrimaryColor),
      'COMPLETED' => (type == _ListType.all ? 'Đã nhập kho đại lý' : 'Đã giao ✓', kPrimaryColor),
      'DONE' => (type == _ListType.all ? 'Đã nhập kho đại lý' : 'Đã giao ✓', kPrimaryColor),
      _ => (status, kTextGray),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class SignaturePad extends StatefulWidget {
  final Function(List<Offset?> points) onDraw;
  const SignaturePad({super.key, required this.onDraw});

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  List<Offset?> points = [];

  void clear() {
    setState(() {
      points.clear();
      widget.onDraw(points);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white30),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: GestureDetector(
          onPanUpdate: (details) {
            RenderBox renderBox = context.findRenderObject() as RenderBox;
            final localPos = renderBox.globalToLocal(details.globalPosition);
            if (localPos.dx >= 0 && localPos.dx <= renderBox.size.width && localPos.dy >= 0 && localPos.dy <= renderBox.size.height) {
              setState(() {
                points.add(localPos);
                widget.onDraw(points);
              });
            }
          },
          onPanEnd: (details) {
            setState(() {
              points.add(null);
              widget.onDraw(points);
            });
          },
          child: CustomPaint(
            painter: _SignaturePainter(points),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.shade900
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

class DeliveryHandshakeDialog extends ConsumerStatefulWidget {
  final Shipment shipment;
  const DeliveryHandshakeDialog({super.key, required this.shipment});

  @override
  ConsumerState<DeliveryHandshakeDialog> createState() => _DeliveryHandshakeDialogState();
}

class _DeliveryHandshakeDialogState extends ConsumerState<DeliveryHandshakeDialog> {
  final GlobalKey<_SignaturePadState> _sigKey = GlobalKey<_SignaturePadState>();
  List<Offset?> _points = [];
  XFile? _invoicePhoto;
  bool _isSubmitting = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickPhoto([ImageSource source = ImageSource.camera]) async {
    try {
      final img = await _picker.pickImage(
        source: source,
        imageQuality: 65,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (img != null) {
        setState(() => _invoicePhoto = img);
      }
    } catch (e) {
      if (source == ImageSource.camera) {
        // Fallback to gallery if camera fails
        _pickPhoto(ImageSource.gallery);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi chọn ảnh: $e')));
      }
    }
  }

  Future<String?> _exportSignature() async {
    if (_points.isEmpty) return null;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 300, 180));
      
      final bgPaint = Paint()..color = Colors.white;
      canvas.drawRect(const Rect.fromLTWH(0, 0, 300, 180), bgPaint);

      final paint = Paint()
        ..color = Colors.blue.shade900
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4.0;

      for (int i = 0; i < _points.length - 1; i++) {
        if (_points[i] != null && _points[i + 1] != null) {
          canvas.drawLine(_points[i]!, _points[i + 1]!, paint);
        }
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(300, 180);
      final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
      if (pngBytes == null) return null;

      final repo = ref.read(farmRepositoryProvider);
      return await repo.uploadImage(pngBytes.buffer.asUint8List(), 'signature_${widget.shipment.id}.png');
    } catch (e) {
      print('Signature upload error: $e');
      return null;
    }
  }

  Future<void> _submit() async {
    if (_points.isEmpty && _invoicePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng ký xác nhận hoặc chụp ảnh hóa đơn!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? sigUrl;
      String? photoUrl;

      if (_points.isNotEmpty) {
        sigUrl = await _exportSignature();
      }

      if (_invoicePhoto != null) {
        final bytes = await _invoicePhoto!.readAsBytes();
        photoUrl = await ref.read(farmRepositoryProvider).uploadImage(bytes, _invoicePhoto!.name);
      }

      await ref.read(driverControllerProvider.notifier).confirmDelivery(
        widget.shipment.id,
        signature: sigUrl,
        evidenceUrl: photoUrl,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi giao hàng: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kSurfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Ký Nhận & Giao Hàng',
                style: TextStyle(color: kTextLight, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Phiếu: ${widget.shipment.trackingCode}',
                style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text('1. Đại lý ký trực tiếp lên màn hình:', style: TextStyle(color: kTextGray, fontSize: 13)),
              const SizedBox(height: 8),
              SignaturePad(
                key: _sigKey,
                onDraw: (p) => _points = p,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _sigKey.currentState?.clear(),
                    icon: const Icon(Icons.clear, size: 16, color: Colors.orangeAccent),
                    label: const Text('Xóa chữ ký', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 20),
              const Text('2. Hoặc chụp ảnh hóa đơn đã ký:', style: TextStyle(color: kTextGray, fontSize: 13)),
              const SizedBox(height: 12),
              if (_invoicePhoto != null) ...[
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? Image.network(
                            _invoicePhoto!.path,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            io.File(_invoicePhoto!.path),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => setState(() => _invoicePhoto = null),
                  icon: const Icon(Icons.delete, size: 16, color: Colors.redAccent),
                  label: const Text('Xóa ảnh', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _pickPhoto(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                        label: const Text('Chụp ảnh', style: TextStyle(color: Colors.white, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickPhoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library, color: Colors.white70, size: 18),
                        label: const Text('Chọn từ thư viện', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text('Hủy', style: TextStyle(color: kTextGray)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Đã đến đại lý', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
