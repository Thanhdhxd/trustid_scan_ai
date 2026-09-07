import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:trustid_scan_ai/core/api/dio_client.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';
import '../../domain/master_growing_area.dart';
import '../../domain/location.dart';
import 'widgets/quick_add_user_dialog.dart';
import '../locations/location_form_screen.dart';
import 'master_area_form_screen.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';
import 'package:trustid_scan_ai/home/data/home_stats_repository.dart';

const Color kPrimaryColor = Color(0xFF00875A);
const Color kBackgroundDark = Color(0xFF0F2B46);
const Color kSurfaceDark = Color(0xFF16325B);
const Color kTextLight = Color(0xFFE8EDF3);
const Color kTextGray = Color(0xFF94A3B8);

// Providers
final masterAreaDetailProvider = FutureProvider.family.autoDispose<MasterGrowingArea, String>((ref, id) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/farm/master-growing-areas/$id');
  return MasterGrowingArea.fromJson(response.data);
});

final masterAreaLocationsProvider = FutureProvider.family.autoDispose<List<GrowingLocation>, String>((ref, id) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/farm/locations', queryParameters: {'masterGrowingAreaId': id});
  return (response.data as List).map((e) => GrowingLocation.fromJson(e)).toList();
});

class MasterAreaDetailScreen extends ConsumerStatefulWidget {
  final String masterAreaId;

  const MasterAreaDetailScreen({super.key, required this.masterAreaId});

  @override
  ConsumerState<MasterAreaDetailScreen> createState() => _MasterAreaDetailScreenState();
}

class _MasterAreaDetailScreenState extends ConsumerState<MasterAreaDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addTeamLeader(MasterGrowingArea area) {
    showDialog(
      context: context,
      builder: (_) => const QuickAddUserDialog(roleName: 'TEAM_LEADER'),
    ).then((_) {
      ref.invalidate(masterAreaDetailProvider(widget.masterAreaId));
    });
  }


  void _showAssignLeaderBottomSheet(MasterGrowingArea area) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kBackgroundDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return _AssignLeaderBottomSheet(
          masterAreaId: area.id,
          currentLeaderIds: (area.leaders ?? []).map((e) => e['id'] as String).toList(),
          onAssigned: () {
            ref.invalidate(masterAreaDetailProvider(widget.masterAreaId));
          },
        );
      },
    );
  }

  void _showAssignKcsBottomSheet(MasterGrowingArea area) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kBackgroundDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return _AssignKcsBottomSheet(
          masterAreaId: area.id,
          currentKcsIds: (area.kcsStaffs ?? []).map((e) => e['id'] as String).toList(),
          onAssigned: () {
            ref.invalidate(masterAreaDetailProvider(widget.masterAreaId));
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final areaAsync = ref.watch(masterAreaDetailProvider(widget.masterAreaId));
    final locationsAsync = ref.watch(masterAreaLocationsProvider(widget.masterAreaId));

    return Scaffold(
      backgroundColor: kBackgroundDark,
      appBar: AppBar(
        title: const Text('Chi tiết Vùng trồng tổng', style: TextStyle(color: kTextLight, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: kBackgroundDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextGray),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: kSurfaceDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: kTextGray,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: kPrimaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(text: 'Thông tin & Bản đồ'),
                Tab(text: 'Danh sách Lô/thửa'),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              key: const ValueKey('add_location_fab'),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LocationFormScreen(
                      initialMasterAreaId: widget.masterAreaId,
                    ),
                  ),
                ).then((_) {
                  ref.invalidate(masterAreaLocationsProvider(widget.masterAreaId));
                });
              },
              backgroundColor: kPrimaryColor,
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            )
          : areaAsync.when(
              data: (area) {
                final role = ref.watch(authControllerProvider).value?.role ?? '';
                if (role == 'FARMER') return null;
                return FloatingActionButton(
                  key: const ValueKey('edit_area_fab'),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MasterAreaFormScreen(masterArea: area),
                      ),
                    ).then((_) {
                      ref.invalidate(masterAreaDetailProvider(widget.masterAreaId));
                    });
                  },
                  backgroundColor: kPrimaryColor,
                  child: const Icon(Icons.edit, color: Colors.white, size: 24),
                );
              },
              loading: () => null,
              error: (_, __) => null,
            ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoAndMapTab(areaAsync, locationsAsync),
          _buildLocationsTab(locationsAsync),
        ],
      ),
    );
  }

  Widget _buildInfoAndMapTab(AsyncValue<MasterGrowingArea> areaAsync, AsyncValue<List<GrowingLocation>> locationsAsync) {
    return areaAsync.when(
      data: (area) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Map Area with Card Styling
              Container(
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: locationsAsync.when(
                  data: (locations) {
                    final polygons = <Polygon>[];
                    final allPoints = <LatLng>[];
                    
                    for (var loc in locations) {
                      final activeBoundary = (loc.approvalStatus == 'PENDING' && loc.pendingBoundary != null)
                          ? loc.pendingBoundary
                          : loc.boundary;
                      if (activeBoundary != null && activeBoundary.isNotEmpty) {
                        final pts = activeBoundary.map((e) => LatLng(e[1], e[0])).toList();
                        allPoints.addAll(pts);
                        polygons.add(Polygon(
                          points: pts,
                          color: kPrimaryColor.withOpacity(0.2),
                          borderColor: kPrimaryColor,
                          borderStrokeWidth: 1.5,
                        ));
                      }
                    }

                    LatLngBounds? bounds;
                    if (allPoints.isNotEmpty) {
                      bounds = LatLngBounds.fromPoints(allPoints);
                    }
                    
                    return Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: bounds?.center ?? const LatLng(14.0583, 108.2772),
                            initialZoom: 13,
                            minZoom: 5.0,
                            cameraConstraint: CameraConstraint.contain(
                              bounds: LatLngBounds(
                                const LatLng(8.0, 102.0),
                                const LatLng(23.5, 109.5),
                              ),
                            ),
                            initialCameraFit: bounds != null 
                              ? CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40))
                              : null,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: kIsWeb
                                  ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                                  : 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
                              userAgentPackageName: 'zps.trustid.com.vn',
                              maxZoom: 22,
                              maxNativeZoom: kIsWeb ? 18 : 20,
                            ),
                            if (polygons.isNotEmpty)
                              PolygonLayer(polygons: polygons),
                          ],
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Column(
                            children: [
                              _buildMapControlBtn(
                                Icons.add,
                                () {
                                  final currentZoom = _mapController.camera.zoom;
                                  _mapController.move(_mapController.camera.center, currentZoom + 1);
                                },
                              ),
                              const SizedBox(height: 8),
                              _buildMapControlBtn(
                                Icons.remove,
                                () {
                                  final currentZoom = _mapController.camera.zoom;
                                  _mapController.move(_mapController.camera.center, currentZoom - 1);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
                  error: (_, __) => const Center(child: Text('Lỗi tải bản đồ', style: TextStyle(color: kTextGray))),
                ),
              ),

              const SizedBox(height: 20),

              // General Info Card
              _buildHeader('Thông tin chung'),
              _buildInfoCard([
                _buildRow(
                  icon: Icons.agriculture_rounded,
                  label: 'Tên vùng trồng',
                  value: area.name,
                ),
                const Divider(height: 1, color: Colors.white10),
                _buildRow(
                  icon: Icons.tag_rounded,
                  label: 'Mã vùng trồng',
                  value: area.code,
                  trailing: InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: area.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã sao chép mã: ${area.code}'),
                          duration: const Duration(seconds: 1),
                          backgroundColor: kPrimaryColor,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.copy_rounded, size: 14, color: kPrimaryColor),
                    ),
                  ),
                ),
                const Divider(height: 1, color: Colors.white10),
                _buildRow(
                  icon: Icons.aspect_ratio_rounded,
                  label: 'Diện tích tổng',
                  value: '${NumberFormat('#,###').format(area.maxAreaM2)} m²',
                ),
                const Divider(height: 1, color: Colors.white10),
                _buildRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Người quản lý',
                  value: area.managerName ?? 'Chưa cập nhật',
                ),
                const Divider(height: 1, color: Colors.white10),
                _buildRow(
                  icon: Icons.info_outline_rounded,
                  label: 'Trạng thái',
                  value: '',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: area.status == 'ACTIVE'
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: area.status == 'ACTIVE'
                            ? const Color(0xFF10B981).withOpacity(0.3)
                            : Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: area.status == 'ACTIVE' ? const Color(0xFF10B981) : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          area.status == 'ACTIVE' ? 'Hoạt động' : 'Đã khóa',
                          style: TextStyle(
                            color: area.status == 'ACTIVE' ? const Color(0xFF10B981) : Colors.redAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: 24),
              // Team Leaders section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _buildHeader('Đội trưởng phụ trách')),
                  Container(
                    height: 30,
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
                    ),
                    child: TextButton.icon(
                      onPressed: () => _addTeamLeader(area),
                      icon: const Icon(Icons.add_rounded, size: 14, color: kPrimaryColor),
                      label: const Text('Thêm mới', style: TextStyle(color: kPrimaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 30,
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextButton.icon(
                      onPressed: () => _showAssignLeaderBottomSheet(area),
                      icon: const Icon(Icons.person_add_rounded, size: 14, color: Colors.white),
                      label: const Text('Phân công', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 10),
              if (area.leaders == null || area.leaders!.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: kSurfaceDark.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: const Center(
                    child: Text('Chưa có đội trưởng nào được phân công.', style: TextStyle(color: kTextGray, fontSize: 13)),
                  ),
                )
              else
                ...area.leaders!.map((leader) {
                  final name = leader['fullName'] ?? leader['username'] ?? 'Unknown';
                  final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: kSurfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.withOpacity(0.15),
                        foregroundColor: Colors.orange,
                        radius: 18,
                        child: Text(initials, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      title: Text(name, style: const TextStyle(color: kTextLight, fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: Text(leader['username'] ?? '', style: const TextStyle(color: kTextGray, fontSize: 12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    ),
                  );
                }).toList(),

              const SizedBox(height: 24),
              // KCS Staff section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _buildHeader('Nhân viên KCS phụ trách')),
                  Container(
                    height: 30,
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextButton.icon(
                      onPressed: () => _showAssignKcsBottomSheet(area),
                      icon: const Icon(Icons.person_add_rounded, size: 14, color: Colors.white),
                      label: const Text('Phân công', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 10),
              if (area.kcsStaffs == null || area.kcsStaffs!.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: kSurfaceDark.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: const Center(
                    child: Text('Chưa có nhân viên KCS nào được phân công.', style: TextStyle(color: kTextGray, fontSize: 13)),
                  ),
                )
              else
                ...area.kcsStaffs!.map((kcs) {
                  final name = kcs['fullName'] ?? kcs['username'] ?? 'Unknown';
                  final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'K';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: kSurfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: kPrimaryColor.withOpacity(0.15),
                        foregroundColor: kPrimaryColor,
                        radius: 18,
                        child: Text(initials, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      title: Text(name, style: const TextStyle(color: kTextLight, fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: Text(kcs['username'] ?? '', style: const TextStyle(color: kTextGray, fontSize: 12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    ),
                  );
                }).toList(),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
      error: (e, s) => Center(child: Text(cleanErrorMessage(e), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildLocationsTab(AsyncValue<List<GrowingLocation>> locationsAsync) {
    return locationsAsync.when(
      data: (locations) {
        if (locations.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.eco_outlined, size: 64, color: kTextGray),
                SizedBox(height: 16),
                Text('Chưa có lô/thửa nào', style: TextStyle(color: kTextGray, fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: locations.length,
          itemBuilder: (context, index) {
            final loc = locations[index];
            String farmerName = "Chưa cập nhật";
            if (loc.farmer is Map) {
              farmerName = loc.farmer['fullName'] ?? loc.farmer['full_name'] ?? loc.farmer['username'] ?? 'Chưa cập nhật';
            } else if (loc.manager != null && loc.manager!.isNotEmpty) {
              farmerName = loc.manager!;
            } else if (loc.farmer != null) {
              farmerName = loc.farmer.toString();
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: kSurfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LocationFormScreen(location: loc),
                        ),
                      ).then((_) {
                        ref.invalidate(masterAreaLocationsProvider(widget.masterAreaId));
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  kPrimaryColor.withOpacity(0.15),
                                  kPrimaryColor.withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
                            ),
                            child: const Icon(Icons.eco_rounded, color: kPrimaryColor, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        loc.name,
                                        style: const TextStyle(
                                          color: kTextLight,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (loc.isOverlapped) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.warning_amber_rounded, size: 12, color: Colors.amberAccent),
                                            SizedBox(width: 4),
                                            Text(
                                              'Lấn ranh',
                                              style: TextStyle(
                                                color: Colors.amberAccent,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(Icons.person_outline, size: 14, color: kTextGray),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              farmerName,
                                              style: const TextStyle(color: kTextGray, fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Row(
                                      children: [
                                        const Icon(Icons.aspect_ratio_rounded, size: 14, color: kTextGray),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${NumberFormat('#,###.#').format(loc.areaM2)} m²',
                                          style: const TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
      error: (e, s) => Center(child: Text(cleanErrorMessage(e), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextLight, letterSpacing: 0.1)),
    );
  }

  Widget _buildMapControlBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: kSurfaceDark.withOpacity(0.9),
      borderRadius: BorderRadius.circular(8),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: kPrimaryColor, size: 24),
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceDark, 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: Column(children: children),
    );
  }

  Widget _buildRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kTextGray),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: kTextGray, fontSize: 13)),
          const Spacer(),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value.isNotEmpty)
                  Flexible(
                    child: Text(
                      value,
                      style: const TextStyle(color: kTextLight, fontWeight: FontWeight.bold, fontSize: 13),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignKcsBottomSheet extends ConsumerStatefulWidget {
  final String masterAreaId;
  final List<String> currentKcsIds;
  final VoidCallback onAssigned;

  const _AssignKcsBottomSheet({required this.masterAreaId, required this.currentKcsIds, required this.onAssigned});

  @override
  ConsumerState<_AssignKcsBottomSheet> createState() => _AssignKcsBottomSheetState();
}

class _AssignKcsBottomSheetState extends ConsumerState<_AssignKcsBottomSheet> {
  List<dynamic> _kcsList = [];
  List<String> _selectedIds = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.currentKcsIds);
    _loadKcs();
  }

  Future<void> _loadKcs() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/users', queryParameters: {'roleName': 'KCS_STAFF'});
      final users = (res.data is List) ? res.data : (res.data['data'] ?? []);
      
      final kcs = <dynamic>[...users];
      
      if (mounted) {
        setState(() {
          _kcsList = kcs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/farm/master-growing-areas/${widget.masterAreaId}', data: {
        'kcsStaffIds': _selectedIds
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onAssigned();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Phân công nhân viên KCS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextLight)),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
              : _kcsList.isEmpty
                  ? const Center(child: Text('Không có nhân viên KCS nào.', style: TextStyle(color: kTextGray)))
                  : ListView.builder(
                      itemCount: _kcsList.length,
                      itemBuilder: (ctx, idx) {
                        final kcs = _kcsList[idx];
                        final id = kcs['id'] as String;
                        final isSelected = _selectedIds.contains(id);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedIds.add(id);
                              } else {
                                _selectedIds.remove(id);
                              }
                            });
                          },
                          title: Text(kcs['fullName'] ?? kcs['username'] ?? 'Unknown', style: const TextStyle(color: kTextLight)),
                          subtitle: Text(kcs['username'] ?? '', style: const TextStyle(color: kTextGray)),
                          activeColor: kPrimaryColor,
                          checkColor: Colors.white,
                          side: const BorderSide(color: kTextGray),
                        );
                      },
                    ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kTextLight, 
                    side: const BorderSide(color: kTextGray),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Đóng'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor, 
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSaving 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Lưu phân công', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _AssignLeaderBottomSheet extends ConsumerStatefulWidget {
  final String masterAreaId;
  final List<String> currentLeaderIds;
  final VoidCallback onAssigned;

  const _AssignLeaderBottomSheet({required this.masterAreaId, required this.currentLeaderIds, required this.onAssigned});

  @override
  ConsumerState<_AssignLeaderBottomSheet> createState() => _AssignLeaderBottomSheetState();
}

class _AssignLeaderBottomSheetState extends ConsumerState<_AssignLeaderBottomSheet> {
  List<dynamic> _leaderList = [];
  List<String> _selectedIds = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.currentLeaderIds);
    _loadLeaders();
  }

  Future<void> _loadLeaders() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/users', queryParameters: {'roleName': 'TEAM_LEADER'});
      final users = (res.data is List) ? res.data : (res.data['data'] ?? []);
      
      final leaders = <dynamic>[...users];
      
      if (mounted) {
        setState(() {
          _leaderList = leaders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/farm/master-growing-areas/${widget.masterAreaId}', data: {
        'leaderIds': _selectedIds
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onAssigned();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Phân công Đội trưởng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextLight)),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
              : _leaderList.isEmpty
                  ? const Center(child: Text('Không có đội trưởng nào.', style: TextStyle(color: kTextGray)))
                  : ListView.builder(
                      itemCount: _leaderList.length,
                      itemBuilder: (ctx, idx) {
                        final leader = _leaderList[idx];
                        final id = leader['id'] as String;
                        final isSelected = _selectedIds.contains(id);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedIds.add(id);
                              } else {
                                _selectedIds.remove(id);
                              }
                            });
                          },
                          title: Text(leader['fullName'] ?? leader['username'] ?? 'Unknown', style: const TextStyle(color: kTextLight)),
                          subtitle: Text(leader['username'] ?? '', style: const TextStyle(color: kTextGray)),
                          activeColor: kPrimaryColor,
                          checkColor: Colors.white,
                          side: const BorderSide(color: kTextGray),
                        );
                      },
                    ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kTextLight, 
                    side: const BorderSide(color: kTextGray),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Đóng'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor, 
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSaving 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Lưu phân công', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
