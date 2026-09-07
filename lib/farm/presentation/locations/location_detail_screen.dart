import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:intl/intl.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';
import '../../data/farm_repository.dart';
import '../../domain/location.dart';

class LocationDetailScreen extends ConsumerStatefulWidget {
  final String locationId;
  const LocationDetailScreen({super.key, required this.locationId});

  @override
  ConsumerState<LocationDetailScreen> createState() =>
      _LocationDetailScreenState();
}

class _LocationDetailScreenState extends ConsumerState<LocationDetailScreen>
    with SingleTickerProviderStateMixin {
  GrowingLocation? _location;
  Map<String, dynamic>? _masterArea;
  bool _isLoading = true;
  Timer? _pollingTimer;
  final MapController _mapController = MapController();
  List<LatLng> _activePoints = [];
  String _farmerName = 'N/A';   // resolved from API
  String _leaderName = 'N/A';   // resolved from API
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // ── Theme ──────────────────────────────────────────────────────────────
  static const Color kPrimary = Color(0xFF00875A);
  static const Color kApprovedColor = Color(0xFF16A34A);
  static const Color kPendingColor = Color(0xFFF59E0B);
  static const Color kBg = Color(0xFF0A1929);
  static const Color kCard = Color(0xFF112240);
  static const Color kCardBorder = Color(0xFF1E3A5F);
  static const Color kTextLight = Color(0xFFE8EDF3);
  static const Color kTextGray = Color(0xFF7B95B4);
  static const Color kWarning = Colors.orange;
  static const Color kError = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fetchDetails();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Fit map ─────────────────────────────────────────────────────────────
  void _fitMapToPolygon(List<LatLng> points) {
    if (points.isEmpty) return;
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      try {
        final bounds = LatLngBounds.fromPoints(points);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(40),
            maxZoom: 18.0,
          ),
        );
      } catch (_) {}
    });
  }

  // ── Resolve leader name ─────────────────────────────────────────────────
  String _resolveLeaderName(GrowingLocation loc) {
    final l = loc.leader;
    if (l != null && l is Map) {
      return l['fullName'] ?? l['full_name'] ?? l['username'] ?? 'N/A';
    }
    return 'N/A';
  }

  // ── Resolve farmer name ──────────────────────────────────────────────────
  String _resolveFarmerName(GrowingLocation loc) {
    final f = loc.farmer;
    if (f != null && f is Map) {
      return f['fullName'] ?? f['full_name'] ?? f['username'] ?? 'N/A';
    }
    return 'N/A';
  }

  // ── Fetch users by role, find by id ─────────────────────────────────────
  Future<String> _fetchUserName(String userId, String roleName) async {
    try {
      // Mirrors web: GET /users?roleName=X&limit=1000, then find by id
      final response = await ref
          .read(farmRepositoryProvider)
          .getUsersByRole(roleName);
      final user = response.firstWhere(
        (u) => u['id'] == userId,
        orElse: () => {},
      );
      if (user.isNotEmpty) {
        return user['fullName'] ?? user['full_name'] ?? user['username'] ?? 'N/A';
      }
    } catch (_) {}
    return 'N/A';
  }

  // ── Fetch data ──────────────────────────────────────────────────────────
  Future<void> _fetchDetails() async {
    try {
      final loc =
          await ref.read(farmRepositoryProvider).getLocationById(widget.locationId);

      Map<String, dynamic>? masterArea = loc.masterGrowingArea is Map
          ? Map<String, dynamic>.from(loc.masterGrowingArea as Map)
          : null;
      if (masterArea == null && loc.masterGrowingAreaId != null) {
        try {
          masterArea = await ref
              .read(farmRepositoryProvider)
              .getMasterGrowingAreaById(loc.masterGrowingAreaId!);
        } catch (_) {}
      }

      if (mounted) {
        final isPendingLoc = loc.approvalStatus == 'PENDING';
        final rawBoundary = (isPendingLoc &&
                loc.pendingBoundary != null &&
                loc.pendingBoundary!.isNotEmpty)
            ? loc.pendingBoundary!
            : (loc.boundary ?? []);

        final pts = rawBoundary
            .map((e) => LatLng(
                  e.length > 1 ? e[1] : 0.0,
                  e.isNotEmpty ? e[0] : 0.0,
                ))
            .where((p) => p.latitude != 0.0 || p.longitude != 0.0)
            .toList();

        // Resolve farmer/leader names — from object if expanded, else fetch from API
        String farmerName = _resolveFarmerName(loc);
        String leaderName = _resolveLeaderName(loc);

        setState(() {
          _location = loc;
          _masterArea = masterArea;
          _isLoading = false;
          _activePoints = pts;
          _farmerName = farmerName;
          _leaderName = leaderName;
        });

        _fadeCtrl.forward();
        if (pts.isNotEmpty) _fitMapToPolygon(pts);

        // Fetch farmer from API if not expanded
        if (farmerName == 'N/A' && loc.farmer != null) {
          final farmerId = loc.farmer.toString();
          if (farmerId.length > 10) { // looks like a UUID
            _fetchUserName(farmerId, 'FARMER').then((name) {
              if (mounted && name != 'N/A') setState(() => _farmerName = name);
            });
          }
        }
        // Fetch leader from API if not expanded
        if (leaderName == 'N/A' && loc.leaderId != null) {
          _fetchUserName(loc.leaderId!, 'TEAM_LEADER').then((name) {
            if (mounted && name != 'N/A') setState(() => _leaderName = name);
          });
        }

        if (loc.eudrStatus == 'PENDING') {
          _startPolling();
        } else {
          _pollingTimer?.cancel();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(cleanErrorMessage(e))));
      }
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final statusData = await ref
            .read(farmRepositoryProvider)
            .getEudrStatus(widget.locationId);
        if (statusData['eudrStatus'] != 'PENDING') {
          timer.cancel();
          _fetchDetails();
        }
      } catch (_) {}
    });
  }

  Future<void> _requestCheck() async {
    try {
      await ref.read(farmRepositoryProvider).requestEudrCheck(widget.locationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Đã gửi yêu cầu kiểm định EUDR. Vui lòng đợi...')));
        _fetchDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(cleanErrorMessage(e))));
      }
    }
  }

  String _getFallback(String? v1, dynamic v2) {
    if (v1 != null && v1.trim().isNotEmpty) return v1;
    if (v2 != null && v2.toString().trim().isNotEmpty) return v2.toString();
    return 'N/A';
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(child: CircularProgressIndicator(color: kPrimary)),
      );
    }
    if (_location == null) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(
            child: Text('Không tìm thấy dữ liệu',
                style: TextStyle(color: kTextLight))),
      );
    }

    final isPending = _location!.approvalStatus == 'PENDING';
    final activePoints = _activePoints;

    // Compute centroid for initial map center
    LatLng initialCenter;
    if (activePoints.isNotEmpty) {
      final avgLat = activePoints
              .map((p) => p.latitude)
              .reduce((a, b) => a + b) /
          activePoints.length;
      final avgLng = activePoints
              .map((p) => p.longitude)
              .reduce((a, b) => a + b) /
          activePoints.length;
      initialCenter = LatLng(avgLat, avgLng);
    } else {
      initialCenter = LatLng(_location!.lat, _location!.long);
    }

    return Scaffold(
      backgroundColor: kBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            // ── SliverAppBar with embedded map ──────────────────────────
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              backgroundColor: kBg,
              foregroundColor: kTextLight,
              elevation: 0,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
                onPressed: () => context.pop(),
              ),
              actions: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_outlined,
                        color: Colors.white, size: 20),
                  ),
                  onPressed: () =>
                      context.push('/farmer/locations/edit', extra: _location),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  children: [
                    // Map
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: initialCenter,
                        initialZoom: 15.0,
                        minZoom: 5.0,
                        maxZoom: 22.0,
                        cameraConstraint: CameraConstraint.contain(
                          bounds: LatLngBounds(
                            const LatLng(8.0, 102.0),
                            const LatLng(23.5, 109.5),
                          ),
                        ),
                        onMapReady: () => _fitMapToPolygon(_activePoints),
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all,
                        ),
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
                        if (activePoints.isNotEmpty)
                          PolygonLayer(
                            polygons: [
                              Polygon(
                                points: activePoints,
                                color: (isPending ? kPendingColor : kApprovedColor)
                                    .withValues(alpha: isPending ? 0.3 : 0.2),
                                borderColor: isPending
                                    ? kPendingColor
                                    : kApprovedColor,
                                borderStrokeWidth: 3.0,
                              ),
                            ],
                          ),
                        // Location marker – always show at centroid/coordinate
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: initialCenter,
                              width: 36,
                              height: 42,
                              child: Column(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: activePoints.isEmpty
                                          ? const Color(0xFF3B82F6)  // blue pin when no boundary
                                          : kPrimary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2.5),
                                      boxShadow: const [
                                        BoxShadow(
                                            color: Colors.black45,
                                            blurRadius: 6,
                                            offset: Offset(0, 3))
                                      ],
                                    ),
                                    child: const Icon(Icons.eco,
                                        color: Colors.white, size: 15),
                                  ),
                                  // Pin tail
                                  Container(
                                    width: 2.5,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      color: activePoints.isEmpty
                                          ? const Color(0xFF3B82F6)
                                          : kPrimary,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Gradient overlay at bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [kBg, kBg.withValues(alpha: 0)],
                          ),
                        ),
                      ),
                    ),
                    // Status badge on map
                    if (activePoints.isEmpty)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_off,
                                  color: Colors.white54, size: 16),
                              SizedBox(width: 6),
                              Text('Chưa có ranh giới',
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    // Approval badge
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: _buildApprovalBadge(isPending),
                    ),
                  ],
                ),
              ),
            ),

            // ── Content ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + code
                    const SizedBox(height: 4),
                    Text(
                      _location!.name,
                      style: const TextStyle(
                        color: kTextLight,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.tag, size: 14, color: kTextGray),
                        const SizedBox(width: 4),
                        Text(
                          _getFallback(_location!.code,
                              _masterArea?['code']),
                          style: const TextStyle(
                              color: kTextGray, fontSize: 13),
                        ),
                        if (_masterArea?['name'] != null) ...[
                          const SizedBox(width: 8),
                          const Text('·',
                              style: TextStyle(color: kTextGray)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _masterArea!['name'].toString(),
                              style: const TextStyle(
                                  color: kTextGray, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Thông tin chung ──────────────────────────────────
                    _sectionLabel('Thông tin chung'),
                    const SizedBox(height: 10),
                    _infoGrid([
                      _gridCell(Icons.grass, 'Loại cây',
                          _getFallback(_location!.plantType,
                              _masterArea?['plantType'] ?? _masterArea?['plant_type'])),
                      _gridCell(Icons.square_foot, 'Diện tích',
                          '${NumberFormat('#,###').format(_location!.areaM2.round())} m²'),
                      _gridCell(Icons.manage_accounts, 'Người quản lý',
                          () {
                        final mm = _masterArea?['managerName'] ??
                            _masterArea?['manager_name'] ??
                            _masterArea?['manager'];
                        return _getFallback(_location!.manager, mm);
                      }()),
                      _gridCell(Icons.group, 'Đội trưởng', _leaderName),
                      _gridCell(Icons.person, 'Nông hộ canh tác', _farmerName),
                      _gridCell(Icons.location_on, 'Địa chỉ', () {
                        final addr = _getFallback(
                            _location!.address, _masterArea?['address']);
                        final ward = _getFallback(
                            _location!.ward, _masterArea?['ward']);
                        final prov = _getFallback(
                            _location!.province, _masterArea?['province']);
                        final parts = [addr, ward, prov]
                            .where((e) => e != 'N/A')
                            .toList();
                        return parts.isEmpty ? 'N/A' : parts.join(', ');
                      }()),
                    ]),

                    const SizedBox(height: 24),

                    // ── EUDR ─────────────────────────────────────────────
                    _sectionLabel('Kiểm định EUDR'),
                    const SizedBox(height: 10),
                    _buildEudrCard(),

                    const SizedBox(height: 24),

                    // ── Phê duyệt ranh giới ──────────────────────────────
                    _sectionLabel('Trạng thái ranh giới'),
                    const SizedBox(height: 10),
                    _buildBoundaryStatusCard(isPending),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Approval badge on map ─────────────────────────────────────────────
  Widget _buildApprovalBadge(bool isPending) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isPending
            ? kPendingColor.withValues(alpha: 0.9)
            : kApprovedColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black38, blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPending ? Icons.hourglass_top : Icons.verified,
            color: Colors.white,
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            isPending ? 'Chờ duyệt' : 'Đã duyệt',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────
  Widget _sectionLabel(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: kPrimary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: kTextLight,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ── Info grid (2-column) ──────────────────────────────────────────────
  Widget _infoGrid(List<Widget> cells) {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorder),
      ),
      child: Column(
        children: List.generate(cells.length, (i) {
          final isLast = i == cells.length - 1;
          return Column(
            children: [
              cells[i],
              if (!isLast)
                Divider(
                    height: 1,
                    color: kCardBorder.withValues(alpha: 0.5),
                    indent: 16,
                    endIndent: 16),
            ],
          );
        }),
      ),
    );
  }

  Widget _gridCell(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: kPrimary, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: kTextGray, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                      color: kTextLight,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── EUDR card ─────────────────────────────────────────────────────────
  Widget _buildEudrCard() {
    Color statusColor = kTextGray;
    String statusText = 'CHƯA KIỂM ĐỊNH';
    IconData statusIcon = Icons.help_outline;

    switch (_location!.eudrStatus) {
      case 'COMPLIANT':
        statusColor = kApprovedColor;
        statusText = 'HỢP QUY (AN TOÀN)';
        statusIcon = Icons.check_circle;
        break;
      case 'NON_COMPLIANT':
        statusColor = kError;
        statusText = 'VI PHẠM (RỦI RO)';
        statusIcon = Icons.warning_amber;
        break;
      case 'PENDING':
        statusColor = kWarning;
        statusText = 'ĐANG PHÂN TÍCH...';
        statusIcon = Icons.sync;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: 0.12),
            kCard,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(statusText,
                          style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      if (_location!.lastCheckDate != null)
                        Text(
                          'Kiểm tra: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(_location!.lastCheckDate!))}',
                          style: TextStyle(
                              color: statusColor.withValues(alpha: 0.7),
                              fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (_location!.violationRate != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _location!.violationRate! / 100,
                  minHeight: 6,
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(statusColor),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Tỷ lệ rủi ro mất rừng',
                      style: TextStyle(fontSize: 12, color: kTextGray)),
                  Text(
                      '${_location!.violationRate!.toStringAsFixed(1)}%',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: statusColor)),
                ],
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _location!.eudrStatus == 'PENDING' ? null : _requestCheck,
                icon: _location!.eudrStatus == 'PENDING'
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.search, size: 16),
                label: Text(
                  _location!.eudrStatus == 'PENDING'
                      ? 'Đang phân tích...'
                      : 'KIỂM ĐỊNH NGAY',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: statusColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: statusColor.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Boundary status card ──────────────────────────────────────────────
  Widget _buildBoundaryStatusCard(bool isPending) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isPending ? kPendingColor : kApprovedColor)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPending ? Icons.hourglass_top : Icons.verified_user,
              color: isPending ? kPendingColor : kApprovedColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPending ? 'Chờ phê duyệt ranh giới' : 'Đã phê duyệt',
                  style: TextStyle(
                      color: isPending ? kPendingColor : kApprovedColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  isPending
                      ? 'Ranh giới mới đang chờ Ban quản lý phê duyệt.'
                      : 'Ranh giới vùng trồng đã được xác nhận hợp lệ.',
                  style: const TextStyle(color: kTextGray, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
