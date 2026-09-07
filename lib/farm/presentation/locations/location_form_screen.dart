import 'dart:async';
import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../data/farm_repository.dart';
import '../../domain/location.dart';
import '../../data/vietnam_units.dart';
import '../../data/province_coords.dart';
import '../../services/gps_service.dart';
import 'package:trustid_scan_ai/core/theme/app_theme.dart';
import 'package:trustid_scan_ai/core/api/dio_client.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';
import 'package:trustid_scan_ai/home/data/home_stats_repository.dart';

class LocationFormScreen extends ConsumerStatefulWidget {
  final GrowingLocation? location;
  final String? initialMasterAreaId;

  const LocationFormScreen({super.key, this.location, this.initialMasterAreaId});

  @override
  ConsumerState<LocationFormScreen> createState() => _LocationFormScreenState();
}

class _LocationFormScreenState extends ConsumerState<LocationFormScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _areaController = TextEditingController();
  final _reasonController = TextEditingController();
  final _addressController = TextEditingController();

  // Province / Ward
  String? _selectedProvince;
  String? _selectedWard;
  List<Map<String, dynamic>> _wards = [];

  final MapController _mapController = MapController();
  LatLng _selectedLocation = const LatLng(21.0285, 105.8542);
  List<LatLng> _polygonPoints = [];
  bool _isSubmitting = false;
  bool _isAreaAutoFilled = true;

  String? _initialAutoLeaderId; // Track initial auto-loaded leader for warnings

  List<dynamic> get _filteredLeaders {
    if (_selectedMasterAreaId == null) return _leaders;
    try {
      final selectedMaster = _masterAreas.firstWhere(
        (m) => m['id'] == _selectedMasterAreaId,
        orElse: () => null,
      );
      if (selectedMaster != null && selectedMaster['leaders'] != null) {
        final leaderIds = (selectedMaster['leaders'] as List).map((e) => e['id']).toSet();
        return _leaders.where((l) => leaderIds.contains(l['id'])).toList();
      }
    } catch (_) {}
    return _leaders;
  }
  double _rawAreaM2 = 0;

  // Master Area
  String? _selectedMasterAreaId;
  List<dynamic> _masterAreas = [];
  bool _isLoadingMasters = true;

  // Existing Locations from Master Area
  List<GrowingLocation> _existingLocations = [];
  bool _isLoadingExistingLocations = false;

  // Farmer selection
  String? _selectedFarmerId;
  List<dynamic> _farmers = [];
  bool _isLoadingFarmers = true;

  // Leader selection
  String? _selectedLeaderId;
  List<dynamic> _leaders = [];
  bool _isLoadingLeaders = true;

  // --- GPS Mode State ---
  bool _isGpsMode = false;
  Position? _currentGpsPosition;
  double _gpsAccuracy = 0;
  StreamSubscription<Position>? _positionSubscription;
  bool _gpsLoading = false;

  // --- Drag-to-edit State ---
  int? _draggingIndex;
  bool _isDragging = false;

  bool _showFastNavigation = false;

  // --- Pulse animation for GPS marker ---
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Theme Constants
  static const Color kPrimaryColor = Color(0xFF00875A);
  static const Color kBackgroundDark = Color(0xFF0F2B46);
  static const Color kSurfaceDark = Color(0xFF16325B);
  static const Color kTextLight = Color(0xFFE8EDF3);
  static const Color kTextGray = Color(0xFF94A3B8);
  static const Color kGpsBlue = Color(0xFF2196F3);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadMasterAreas();

    if (widget.location != null) {
      _nameController.text = widget.location!.name;
      _codeController.text = widget.location!.code ?? '';
      final activeBoundary = (widget.location!.approvalStatus == 'PENDING' && widget.location!.pendingBoundary != null)
          ? widget.location!.pendingBoundary
          : widget.location!.boundary;

      if (activeBoundary != null) {
        _polygonPoints = activeBoundary
            .map((e) => LatLng(e[1], e[0]))
            .toList();
      }

      if (_polygonPoints.isNotEmpty) {
        _rawAreaM2 = _calculatePolygonArea(_polygonPoints);
      } else {
        _rawAreaM2 = widget.location!.areaM2;
      }
      _areaController.text = NumberFormat('#,###').format(widget.location!.areaM2.round());
      _selectedLocation = LatLng(widget.location!.lat, widget.location!.long);
      _addressController.text = widget.location!.address ?? '';
      _isAreaAutoFilled = false;

      // Fit map to polygon after first frame using postFrameCallback
      if (_polygonPoints.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try {
            final bounds = LatLngBounds.fromPoints(_polygonPoints);
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

      final provinceExists =
          vietnamUnits.any((e) => e['name'] == widget.location!.province);
      if (provinceExists) {
        _selectedProvince = widget.location!.province;
        _loadWards();
        final wardExists =
            _wards.any((e) => e['name'] == widget.location!.ward);
        if (wardExists) _selectedWard = widget.location!.ward;
      }
      
      if (widget.location!.masterGrowingAreaId != null) {
        _selectedMasterAreaId = widget.location!.masterGrowingAreaId;
      } else if (widget.location!.masterGrowingArea != null && widget.location!.masterGrowingArea is Map) {
        _selectedMasterAreaId = widget.location!.masterGrowingArea['id'];
      }
      
      if (widget.location!.farmer != null) {
        if (widget.location!.farmer is Map) {
          _selectedFarmerId = widget.location!.farmer['id'];
        } else if (widget.location!.farmer is String) {
          _selectedFarmerId = widget.location!.farmer;
        }
      }
      
      if (widget.location!.leaderId != null) {
        _selectedLeaderId = widget.location!.leaderId;
      }
    } else {
      if (widget.initialMasterAreaId != null) {
        _selectedMasterAreaId = widget.initialMasterAreaId;
      }
    }

    if (_selectedMasterAreaId != null) {
      _loadExistingLocationsForMasterArea(_selectedMasterAreaId!);
    }

    // Defer reading authControllerProvider to build or next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authControllerProvider).value;
      final role = user?.role;
      if (role == 'TENANT_ADMIN' || role == 'MANAGER') {
        _loadUsers();
      } else if (role == 'TEAM_LEADER') {
        _selectedLeaderId = user?.id; // Auto bind
        _loadUsers(); // load farmers
      } else {
        // FARMER
        _selectedFarmerId = user?.id; // Auto bind
        _loadUsers(); // Always load leaders so they can pick
        
        if (widget.location == null) {
           _loadLatestLocationForFarmer();
        } else if (user?.leaderId != null && _selectedLeaderId == null) {
           _selectedLeaderId = user?.leaderId;
        }
      }
    });
  }

  Future<void> _loadLatestLocationForFarmer() async {
    try {
      final repo = ref.read(farmRepositoryProvider);
      final locations = await repo.getLocations();
      if (locations.isNotEmpty) {
        final latest = locations.first;
        if (mounted) {
          setState(() {
            if (latest.masterGrowingArea != null && _selectedMasterAreaId == null) {
              _selectedMasterAreaId = latest.masterGrowingArea!['id'];
              _loadExistingLocationsForMasterArea(_selectedMasterAreaId!);
            }
            if (latest.leaderId != null && _selectedLeaderId == null) {
              _selectedLeaderId = latest.leaderId;
              _initialAutoLeaderId = latest.leaderId;
            } else {
              // Dù Location không có leader, có thể user.leaderId có (do mới được set)
              final user = ref.read(authControllerProvider).value;
              if (user?.leaderId != null && _selectedLeaderId == null) {
                _selectedLeaderId = user?.leaderId;
                _initialAutoLeaderId = user?.leaderId;
              }
            }
          });
        }
      } else {
        // Nếu không có location nào, fallback sang user.leaderId nếu có
        final user = ref.read(authControllerProvider).value;
        if (user?.leaderId != null && _selectedLeaderId == null) {
          setState(() {
            _selectedLeaderId = user?.leaderId;
            _initialAutoLeaderId = user?.leaderId;
          });
        }
      }
    } catch (e) {
      // Ignore errors for auto-loading
    }
  }

  Future<void> _loadUsers() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/users', queryParameters: {'limit': 1000});
      final data = response.data;
      List<dynamic> allUsers = [];
      if (data is List) {
        allUsers = data;
      } else if (data is Map && data.containsKey('data')) {
        allUsers = data['data'];
      }
      if (mounted) {
        setState(() {
          final uniqueFarmers = <String, dynamic>{};
          final uniqueLeaders = <String, dynamic>{};
          for (final u in allUsers) {
            if (u['id'] == null) continue;
            final role = u['role'] is Map ? u['role']['name'] : u['roleName'];
            if (role == 'FARMER') uniqueFarmers[u['id']] = u;
            if (role == 'TEAM_LEADER') uniqueLeaders[u['id']] = u;
          }
          _farmers = uniqueFarmers.values.toList();
          _leaders = uniqueLeaders.values.toList();
          _isLoadingFarmers = false;
          _isLoadingLeaders = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _isLoadingFarmers = false;
        _isLoadingLeaders = false;
      });
    }
  }

  Future<void> _loadExistingLocationsForMasterArea(String masterAreaId) async {
    setState(() => _isLoadingExistingLocations = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/farm/locations', queryParameters: {'masterGrowingAreaId': masterAreaId});
      if (mounted) {
        setState(() {
          final allLocs = (response.data as List).map((e) => GrowingLocation.fromJson(e)).toList();
          _existingLocations = allLocs.where((loc) => loc.id != widget.location?.id).toList();
          _isLoadingExistingLocations = false;
        });
        
        // Fit camera if no current polygon points
        if (_polygonPoints.isEmpty && _existingLocations.isNotEmpty) {
          final allPoints = <LatLng>[];
          for (var loc in _existingLocations) {
            if (loc.boundary != null) {
              allPoints.addAll(loc.boundary!.map((e) => LatLng(e[1], e[0])));
            }
          }
          if (allPoints.isNotEmpty) {
            final bounds = LatLngBounds.fromPoints(allPoints);
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(50),
                maxZoom: 18.0,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingExistingLocations = false);
      }
    }
  }

  Future<void> _loadMasterAreas() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/farm/master-growing-areas');
      if (mounted) {
        setState(() {
          final uniqueMasters = <String, dynamic>{};
          for (final m in (response.data as List)) {
             if (m['id'] != null) uniqueMasters[m['id']] = m;
          }
          _masterAreas = uniqueMasters.values.toList();
          _isLoadingMasters = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMasters = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _areaController.dispose();
    _reasonController.dispose();
    _positionSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════
  // GPS Methods
  // ════════════════════════════════════════

  Future<void> _toggleGpsMode() async {
    if (_isGpsMode) {
      // Turning OFF — re-center map on polygon
      _positionSubscription?.cancel();
      _positionSubscription = null;
      setState(() {
        _isGpsMode = false;
        _currentGpsPosition = null;
      });

      // Fit map to show the polygon
      if (_polygonPoints.length >= 2) {
        final bounds = LatLngBounds.fromPoints(_polygonPoints);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(40),
            maxZoom: 18.0,
          ),
        );
      } else if (_polygonPoints.length == 1) {
        _mapController.move(_polygonPoints.first, 18.0);
      }
      return;
    }

    // Turning ON
    setState(() => _gpsLoading = true);
    final gps = ref.read(gpsServiceProvider);
    final hasPermission = await gps.checkAndRequestPermission();

    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Không có quyền GPS. Vui lòng bật định vị trong cài đặt.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      setState(() => _gpsLoading = false);
      return;
    }

    // Get initial position
    final position = await gps.getCurrentPosition();
    if (position != null && mounted) {
      setState(() {
        _currentGpsPosition = position;
        _gpsAccuracy = position.accuracy;
        _isGpsMode = true;
        _gpsLoading = false;
      });

      // Center map on GPS
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        _mapController.camera.zoom < 17.0 ? 18.0 : _mapController.camera.zoom,
      );

      // Start tracking
      gps.startTracking(distanceFilter: 2);
      _positionSubscription = gps.positionStream.listen((pos) {
        if (mounted) {
          setState(() {
            _currentGpsPosition = pos;
            _gpsAccuracy = pos.accuracy;
          });
        }
      });
    } else {
      setState(() => _gpsLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể lấy vị trí GPS. Thử lại sau.'),
          ),
        );
      }
    }
  }

  void _addGpsPoint() {
    if (_currentGpsPosition == null) return;
    final point = LatLng(
      _currentGpsPosition!.latitude,
      _currentGpsPosition!.longitude,
    );
    setState(() {
      _polygonPoints.add(point);
      _selectedLocation = point;
      _recalculateArea();
    });
  }

  void _centerOnGps() {
    if (_currentGpsPosition != null) {
      _mapController.move(
        LatLng(_currentGpsPosition!.latitude, _currentGpsPosition!.longitude),
        _mapController.camera.zoom,
      );
    }
  }

  // ════════════════════════════════════════
  // Map Tap (existing behavior)
  // ════════════════════════════════════════

  void _onMapTap(LatLng point) {
    if (_isGpsMode || _isDragging) return;

    setState(() {
      _polygonPoints.add(point);
      _selectedLocation = point;
      _recalculateArea();
    });
  }

  // ════════════════════════════════════════
  // Drag-to-Edit
  // ════════════════════════════════════════

  void _onPointDragStart(int index) {
    setState(() {
      _draggingIndex = index;
      _isDragging = true;
    });
  }

  void _onPointDragUpdate(LatLng newPosition) {
    if (_draggingIndex == null) return;
    setState(() {
      _polygonPoints[_draggingIndex!] = newPosition;
    });
  }

  void _onPointDragEnd() {
    setState(() {
      _draggingIndex = null;
      _isDragging = false;
      _recalculateArea();
    });
  }

  // ════════════════════════════════════════
  // Insert Point
  // ════════════════════════════════════════

  void _insertPoint(int afterIndex, LatLng point) {
    setState(() {
      _polygonPoints.insert(afterIndex + 1, point);
      _recalculateArea();
    });
  }

  // ════════════════════════════════════════
  // Area & Polygon Utils
  // ════════════════════════════════════════

  void _recalculateArea() {
    final area = _calculatePolygonArea(_polygonPoints);
    _rawAreaM2 = area;
    if (_isAreaAutoFilled) {
      _areaController.text = area > 0 ? area.round().toString() : '';
    }
  }

  double _calculatePolygonArea(List<LatLng> points) {
    if (points.length < 3) return 0;
    const double radius = 6378137;
    double area = 0;
    for (int i = 0; i < points.length; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      area += (_toRad(p2.longitude) - _toRad(p1.longitude)) *
          (2 + Math.sin(_toRad(p1.latitude)) + Math.sin(_toRad(p2.latitude)));
    }
    area = area * radius * radius / 2;
    return area.abs();
  }

  double _toRad(double deg) => deg * Math.pi / 180;

  void _undoPoint() {
    if (_polygonPoints.isNotEmpty) {
      setState(() {
        _polygonPoints.removeLast();
        _recalculateArea();
      });
    }
  }

  void _clearPoints() {
    setState(() {
      _polygonPoints = [];
      _rawAreaM2 = 0;
      _areaController.text = '0';
    });
  }

  void _loadWards() {
    if (_selectedProvince == null) {
      setState(() => _wards = []);
      return;
    }
    try {
      final province = vietnamUnits.firstWhere(
        (element) => element['name'] == _selectedProvince,
        orElse: () => {},
      );
      if (province.isNotEmpty && province['wards'] != null) {
        setState(
          () => _wards = List<Map<String, dynamic>>.from(province['wards']),
        );
      }
    } catch (_) {}
  }

  void _onProvinceChanged(String? val) {
    if (val == _selectedProvince) return;
    setState(() {
      _selectedProvince = val;
      _selectedWard = null;
      _wards = [];
    });

    if (val != null) {
      _loadWards();
      if (provinceCoordinates.containsKey(val)) {
        final coords = provinceCoordinates[val]!;
        final newLoc = LatLng(coords['lat']!, coords['lng']!);
        setState(() => _selectedLocation = newLoc);
        _mapController.move(newLoc, 13);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorDialog('Vui lòng kiểm tra lại các trường bắt buộc.');
      return;
    }
    if (_polygonPoints.length < 3) {
      _showErrorDialog('Vui lòng vẽ vùng trồng (ít nhất 3 điểm).');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(farmRepositoryProvider);

      final boundaryCoordinates =
          _polygonPoints.map((p) => [p.longitude, p.latitude]).toList();
      // Close the polygon loop
      if (boundaryCoordinates.isNotEmpty &&
          (boundaryCoordinates.first[0] != boundaryCoordinates.last[0] ||
              boundaryCoordinates.first[1] != boundaryCoordinates.last[1])) {
        boundaryCoordinates.add(boundaryCoordinates.first);
      }

      // Auto-compute centroid from polygon
      final centroidLat = _polygonPoints.map((p) => p.latitude).reduce((a, b) => a + b) / _polygonPoints.length;
      final centroidLng = _polygonPoints.map((p) => p.longitude).reduce((a, b) => a + b) / _polygonPoints.length;

      final double? legalArea = double.tryParse(_areaController.text.replaceAll(',', ''));
      if (legalArea == null || legalArea <= 0) {
        _showErrorDialog('Vui lòng nhập diện tích pháp lý (Sổ đỏ) hợp lệ.');
        return;
      }

      if (_rawAreaM2 > 0) {
        final diff = ((_rawAreaM2 - legalArea) / legalArea) * 100;
        if (diff > 5) {
          _showErrorDialog('Lỗi: Diện tích vẽ trên bản đồ lớn hơn Sổ đỏ! Hệ thống không cho phép lấn chiếm quá 5%. Vui lòng vẽ lại hình nhỏ gọn hơn.');
          return;
        }
        if (diff < -15) {
          _showErrorDialog('Lỗi: Hình vẽ quá nhỏ so với Sổ đỏ! Vùng trồng vẽ thiếu hụt hơn 15%. Vui lòng vẽ lại hình bao quát hơn.');
          return;
        }
      }

      final payload = {
        'name': _nameController.text,
        if (_codeController.text.trim().isNotEmpty) 'code': _codeController.text.trim(),
        'area_m2': legalArea,
        'lat': centroidLat,
        'long': centroidLng,
        // Send as flat coordinate array — backend wraps into GeoJSON
        'boundary': boundaryCoordinates,
        'updateReason': _reasonController.text,
        'masterGrowingAreaId': _selectedMasterAreaId,
        if (_selectedFarmerId != null) 'farmerId': _selectedFarmerId,
        if (_selectedLeaderId != null) 'leaderId': _selectedLeaderId,
        if (_addressController.text.trim().isNotEmpty) 'address': _addressController.text.trim(),
      };

      if (widget.location == null) {
        await repo.createLocation(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thêm vùng trồng thành công')),
          );
        }
      } else {
        await repo.updateLocation(widget.location!.id, payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Cập nhật thành công. Vui lòng đợi quản trị viên duyệt.'),
            ),
          );
        }
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceFirst('Exception: ', '');
        _showErrorDialog('Lỗi: $errorMsg');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
            SizedBox(width: 10),
            Text('Thông báo', style: TextStyle(color: kTextLight, fontSize: 18)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: kTextGray, fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đã hiểu', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final sortedProvinces =
        vietnamUnits.map((e) => e['name'].toString()).toList()..sort();
    final sortedWards =
        _wards.map((e) => e['name'].toString()).toList()..sort();
    final user = ref.read(authControllerProvider).value;
    final isAdmin = user?.role == 'TENANT_ADMIN' || user?.role == 'MANAGER';
    final isLeader = user?.role == 'TEAM_LEADER';
    final isEditMode = widget.location != null;

    return Scaffold(
      backgroundColor: kBackgroundDark,
      // ── AppBar ────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: kBackgroundDark,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditMode ? 'Sửa Vùng Trồng' : 'Thêm Vùng Trồng',
              style: const TextStyle(
                  color: kTextLight,
                  fontSize: 17,
                  fontWeight: FontWeight.bold),
            ),
            if (widget.location?.name != null || isEditMode)
              Text(
                widget.location?.name ?? '',
                style: const TextStyle(color: kTextGray, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        iconTheme: const IconThemeData(color: kTextGray),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.white.withValues(alpha: 0.06), height: 1),
        ),
      ),

      // ── Sticky bottom save button ─────────────────────────────────────
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: kSurfaceDark,
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        ),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              disabledBackgroundColor: kPrimaryColor.withValues(alpha: 0.4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Text(
                    isEditMode ? 'LƯU THAY ĐỔI' : 'TẠO VÙNG TRỒNG',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.5),
                  ),
          ),
        ),
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Mode Toggle ──────────────────────────────────────────────
            _buildModeToggle(),

            // ── Map ──────────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 320,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  _buildMap(),
                  _buildMapControls(),
                  _buildPointsInfo(),
                ],
              ),
            ),

            // ── GPS Panel ────────────────────────────────────────────────
            if (_isGpsMode) _buildGpsPanel(),

            // ── Form Sections ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme: AppTheme.darkInputDecoration,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tolerance alert
                      _buildToleranceAlert(),

                      // ── Section: Thông tin cơ bản ─────────────────────
                      _sectionHeader(Icons.info_outline, 'Thông tin cơ bản'),
                      _formCard([
                        if (!_isLoadingMasters && _masterAreas.isNotEmpty) ...[
                          _styledDropdown(
                            label: 'Vùng trồng tổng',
                            icon: Icons.account_tree_outlined,
                            isRequired: true,
                            value: _selectedMasterAreaId,
                            items: [
                              if (_selectedMasterAreaId != null &&
                                  !_masterAreas.any(
                                      (m) => m['id'] == _selectedMasterAreaId))
                                DropdownMenuItem<String>(
                                  value: _selectedMasterAreaId,
                                  child: Text('Vùng trồng hiện tại',
                                      style: const TextStyle(color: kTextLight)),
                                ),
                              ..._masterAreas.map((m) => DropdownMenuItem<String>(
                                    value: m['id'],
                                    child: Text(m['name'] ?? m['code'] ?? '',
                                        style:
                                            const TextStyle(color: kTextLight)),
                                  )),
                            ],
                            validator: (v) =>
                                v == null ? 'Không được để trống' : null,
                            onChanged: (val) {
                              setState(() {
                                _selectedMasterAreaId = val;
                                if (val != null) {
                                  _loadExistingLocationsForMasterArea(val);
                                } else {
                                  _existingLocations = [];
                                }
                                if (_selectedLeaderId != null) {
                                  if (!_filteredLeaders
                                      .any((l) => l['id'] == _selectedLeaderId)) {
                                    _selectedLeaderId = null;
                                  }
                                }
                              });
                            },
                          ),
                          const Divider(height: 1, color: Color(0xFF1E3A5F)),
                        ],
                        _styledField(
                          controller: _nameController,
                          label: 'Tên vùng trồng',
                          icon: Icons.agriculture,
                          isRequired: true,
                          validator: (v) =>
                              v!.isEmpty ? 'Không được để trống' : null,
                        ),
                        const Divider(height: 1, color: Color(0xFF1E3A5F)),
                        _styledField(
                          controller: _codeController,
                          label: 'Mã số vùng trồng',
                          icon: Icons.tag,
                          hint: 'Không bắt buộc',
                        ),
                      ]),

                      // ── Section: Người phụ trách ──────────────────────
                      if ((isAdmin || isLeader) && !_isLoadingFarmers ||
                          (isAdmin || user?.role == 'FARMER') &&
                              !_isLoadingLeaders) ...[
                        _sectionHeader(
                            Icons.people_outline, 'Người phụ trách'),
                        _formCard([
                          if ((isAdmin || isLeader) &&
                              !_isLoadingFarmers) ...[
                            _styledDropdown(
                              label: 'Nông hộ (Chủ thửa)',
                              icon: Icons.person,
                              isRequired: true,
                              value: _selectedFarmerId,
                              items: [
                                if (_selectedFarmerId != null &&
                                    !_farmers.any(
                                        (m) => m['id'] == _selectedFarmerId))
                                  DropdownMenuItem<String>(
                                    value: _selectedFarmerId,
                                    child: Text(
                                      widget.location?.farmer != null
                                          ? (widget.location!.farmer[
                                                  'fullName'] ??
                                              widget.location!.farmer[
                                                  'username'] ??
                                              'Nông dân hiện tại')
                                          : 'Nông dân hiện tại',
                                      style:
                                          const TextStyle(color: kTextLight),
                                    ),
                                  ),
                                ..._farmers.map((m) => DropdownMenuItem<String>(
                                      value: m['id'],
                                      child: Text(
                                          m['fullName'] ?? m['username'] ?? '',
                                          style: const TextStyle(
                                              color: kTextLight)),
                                    )),
                              ],
                              validator: (v) =>
                                  v == null ? 'Không được để trống' : null,
                              onChanged: (val) {
                                setState(() {
                                  _selectedFarmerId = val;
                                  if (val != null) {
                                    final farmer = _farmers.firstWhere(
                                      (f) => f['id'] == val,
                                      orElse: () => null,
                                    );
                                    if (farmer != null) {
                                      if (farmer['leaderId'] != null) {
                                        _selectedLeaderId = farmer['leaderId'];
                                      } else if (farmer['leader'] != null) {
                                        _selectedLeaderId =
                                            farmer['leader']['id'];
                                      }
                                    }
                                  }
                                });
                              },
                            ),
                            if ((isAdmin || user?.role == 'FARMER') &&
                                !_isLoadingLeaders)
                              const Divider(
                                  height: 1, color: Color(0xFF1E3A5F)),
                          ],
                          if ((isAdmin || user?.role == 'FARMER') &&
                              !_isLoadingLeaders) ...[
                            _styledDropdown(
                              label: 'Đội trưởng phụ trách',
                              icon: Icons.supervisor_account,
                              isRequired: true,
                              value: _selectedLeaderId,
                              items: [
                                if (_selectedLeaderId != null &&
                                    !_filteredLeaders.any(
                                        (m) => m['id'] == _selectedLeaderId))
                                  DropdownMenuItem<String>(
                                    value: _selectedLeaderId,
                                    child: Text('Đội trưởng hiện tại',
                                        style:
                                            const TextStyle(color: kTextLight)),
                                  ),
                                ..._filteredLeaders
                                    .map((m) => DropdownMenuItem<String>(
                                          value: m['id'],
                                          child: Text(
                                              m['fullName'] ??
                                                  m['username'] ??
                                                  '',
                                              style: const TextStyle(
                                                  color: kTextLight)),
                                        )),
                              ],
                              validator: (v) =>
                                  v == null ? 'Không được để trống' : null,
                              onChanged: (val) =>
                                  setState(() => _selectedLeaderId = val),
                            ),
                            if (user?.role == 'FARMER' &&
                                _initialAutoLeaderId != null &&
                                _selectedLeaderId != _initialAutoLeaderId)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline,
                                        color: Colors.orange, size: 14),
                                    const SizedBox(width: 6),
                                    const Flexible(
                                      child: Text(
                                        'Đang chọn Đội trưởng khác với thông tin đã gán.',
                                        style: TextStyle(
                                            color: Colors.orange, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ]),
                      ],

                      // ── Section: Địa chỉ ──────────────────────────────
                      _sectionHeader(Icons.location_on_outlined, 'Địa chỉ'),
                      _formCard([
                        _styledDropdown(
                          label: 'Tỉnh / Thành phố',
                          icon: Icons.map_outlined,
                          value: _selectedProvince,
                          items: sortedProvinces
                              .map((name) => DropdownMenuItem(
                                    value: name,
                                    child: Text(name,
                                        style: const TextStyle(
                                            color: kTextLight)),
                                  ))
                              .toList(),
                          onChanged: isEditMode || _polygonPoints.isNotEmpty
                              ? null
                              : _onProvinceChanged,
                        ),
                        const Divider(height: 1, color: Color(0xFF1E3A5F)),
                        _styledDropdown(
                          label: 'Phường / Xã',
                          icon: Icons.holiday_village_outlined,
                          value: _selectedWard,
                          items: sortedWards
                              .map((name) => DropdownMenuItem(
                                    value: name,
                                    child: Text(name,
                                        style: const TextStyle(
                                            color: kTextLight)),
                                  ))
                              .toList(),
                          onChanged: isEditMode ||
                                  _polygonPoints.isNotEmpty ||
                                  _selectedProvince == null
                              ? null
                              : (val) =>
                                  setState(() => _selectedWard = val),
                        ),
                        const Divider(height: 1, color: Color(0xFF1E3A5F)),
                        _styledField(
                          controller: _addressController,
                          label: 'Địa chỉ chi tiết',
                          icon: Icons.home_outlined,
                          isRequired: true,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Vui lòng nhập địa chỉ chi tiết';
                            if (v.trim().length < 5 || v.trim().length > 255)
                              return 'Địa chỉ phải từ 5 đến 255 ký tự';
                            return null;
                          },
                        ),
                      ]),

                      // ── Section: Diện tích & Lý do ────────────────────
                      _sectionHeader(
                          Icons.square_foot, 'Diện tích & Ghi chú'),
                      _formCard([
                        _styledField(
                          controller: _areaController,
                          label: 'Diện tích (m²)',
                          icon: Icons.crop_square,
                          isRequired: true,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Vui lòng nhập diện tích';
                            final val =
                                double.tryParse(v.replaceAll(',', ''));
                            if (val == null || val <= 0)
                              return 'Diện tích phải lớn hơn 0';
                            return null;
                          },
                          onChanged: (_) {
                            _isAreaAutoFilled = false;
                            setState(() {});
                          },
                        ),
                        if (isEditMode) ...[
                          const Divider(height: 1, color: Color(0xFF1E3A5F)),
                          _styledField(
                            controller: _reasonController,
                            label: 'Lý do thay đổi',
                            icon: Icons.edit_note,
                            isRequired: true,
                            maxLines: 3,
                            hint: 'Bắt buộc để quản trị viên phê duyệt...',
                            validator: (v) =>
                                (v == null || v.isEmpty)
                                    ? 'Vui lòng nhập lý do thay đổi'
                                    : null,
                          ),
                        ],
                      ]),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────
  Widget _sectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: kPrimaryColor, size: 16),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
                color: kTextLight,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }

  // ── Card wrapper for form groups ──────────────────────────────────────
  Widget _formCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(children: children),
    );
  }

  // ── Styled text field ─────────────────────────────────────────────────
  Widget _styledField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment:
            maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 14 : 0),
            child: Icon(icon, size: 18, color: kTextGray),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              style: const TextStyle(color: kTextLight, fontSize: 14),
              maxLines: maxLines,
              keyboardType: keyboardType,
              onChanged: onChanged,
              validator: validator,
              decoration: InputDecoration(
                labelText: isRequired ? null : label,
                label: isRequired
                    ? RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(
                                text: '* ',
                                style: TextStyle(
                                    color: Colors.red, fontSize: 14)),
                            TextSpan(
                                text: label,
                                style: const TextStyle(
                                    color: kTextGray, fontSize: 14)),
                          ],
                        ),
                      )
                    : null,
                hintText: hint,
                hintStyle:
                    const TextStyle(color: kTextGray, fontSize: 13),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Styled dropdown ───────────────────────────────────────────────────
  Widget _styledDropdown({
    required String label,
    required IconData icon,
    bool isRequired = false,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    String? Function(String?)? validator,
    void Function(String?)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kTextGray),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: value,
              style: const TextStyle(color: kTextLight, fontSize: 14),
              decoration: InputDecoration(
                labelText: isRequired ? null : label,
                label: isRequired
                    ? RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(
                                text: '* ',
                                style: TextStyle(
                                    color: Colors.red, fontSize: 14)),
                            TextSpan(
                                text: label,
                                style: const TextStyle(
                                    color: kTextGray, fontSize: 14)),
                          ],
                        ),
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
              ),
              dropdownColor: kSurfaceDark,
              isExpanded: true,
              menuMaxHeight: 300,
              validator: validator,
              items: items,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }


  // ════════════════════════════════════════
  // Widget Builders
  // ════════════════════════════════════════

  Widget _buildToleranceAlert() {
    final legalArea = double.tryParse(_areaController.text.replaceAll(',', ''));
    if (_rawAreaM2 <= 0 || legalArea == null || legalArea <= 0) {
      return const SizedBox.shrink();
    }

    final diff = ((_rawAreaM2 - legalArea) / legalArea) * 100;
    
    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    String title;
    String desc;

    if (diff > 5) {
      // POSITIVE_ERROR
      bgColor = const Color(0xFFFDE8E8);
      borderColor = const Color(0xFFF8B4B4);
      textColor = const Color(0xFF9B1C1C);
      icon = Icons.error_outline;
      title = 'Lỗi: Diện tích vẽ trên bản đồ lớn hơn Sổ đỏ!';
      desc = 'Vùng trồng được vẽ ${NumberFormat('#,###.#').format(_rawAreaM2)} m², lớn hơn Sổ đỏ khoảng ${diff.toStringAsFixed(1)}%. Hệ thống không cho phép lấn chiếm quá 5%. Vui lòng vẽ lại nhỏ gọn hơn cho khớp.';
    } else if (diff < -15) {
      // NEGATIVE_ERROR
      bgColor = const Color(0xFFFDE8E8);
      borderColor = const Color(0xFFF8B4B4);
      textColor = const Color(0xFF9B1C1C);
      icon = Icons.error_outline;
      title = 'Lỗi: Hình vẽ quá nhỏ so với Sổ đỏ!';
      desc = 'Vùng trồng được vẽ ${NumberFormat('#,###.#').format(_rawAreaM2)} m², thiếu hụt hơn ${diff.abs().toStringAsFixed(1)}% so với Sổ đỏ. Vui lòng xóa hình và khoanh vẽ lại bao quát hơn.';
    } else if (diff < -5) {
      // NEGATIVE_WARNING
      bgColor = const Color(0xFFFEF08A);
      borderColor = const Color(0xFFFDE047);
      textColor = const Color(0xFF854D0E);
      icon = Icons.warning_amber_rounded;
      title = 'Chú ý: Diện tích vẽ hơi nhỏ so với Sổ đỏ';
      desc = 'Vùng trồng được vẽ ${NumberFormat('#,###.#').format(_rawAreaM2)} m², nhỏ hơn Sổ đỏ khoảng ${diff.abs().toStringAsFixed(1)}%. Hệ thống vẫn cho phép lưu, nhưng hãy kiểm tra lại xem có vẽ thiếu không nhé.';
    } else {
      // MATCH
      bgColor = const Color(0xFFDEF7EC);
      borderColor = const Color(0xFFBCF0DA);
      textColor = const Color(0xFF03543F);
      icon = Icons.check_circle_outline;
      title = 'Diện tích bản đồ khớp với sổ đỏ (Độ lệch an toàn)';
      desc = 'Diện tích vẽ: ${NumberFormat('#,###.#').format(_rawAreaM2)} m² (Lệch: ${diff.abs().toStringAsFixed(1)}%)';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    color: textColor.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeButton(
              icon: Icons.touch_app,
              label: 'Tap bản đồ',
              isActive: !_isGpsMode,
              onTap: () {
                if (_isGpsMode) _toggleGpsMode();
              },
            ),
          ),
          Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.08)),
          Expanded(
            child: _buildModeButton(
              icon: Icons.gps_fixed,
              label: 'GPS thực địa',
              isActive: _isGpsMode,
              isLoading: _gpsLoading,
              onTap: () {
                if (!_isGpsMode) _toggleGpsMode();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required bool isActive,
    bool isLoading = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: isActive
              ? kPrimaryColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    color: kPrimaryColor, strokeWidth: 2),
              )
            else
              Icon(icon, size: 18,
                  color: isActive ? kPrimaryColor : kTextGray),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? kPrimaryColor : kTextGray,
                fontWeight:
                    isActive ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _selectedLocation,
        initialZoom: 18.0,
        minZoom: 5.0,
        cameraConstraint: CameraConstraint.contain(
          bounds: LatLngBounds(
            const LatLng(8.0, 102.0),
            const LatLng(23.5, 109.5),
          ),
        ),
        onTap: (_, point) => _onMapTap(point),
        interactionOptions: InteractionOptions(
          flags: _isDragging
              ? InteractiveFlag.none
              : InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          // Mobile: Google Maps (no CORS); Web: ESRI (CORS-safe)
          urlTemplate: kIsWeb
              ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
              : 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
          userAgentPackageName: 'zps.trustid.com.vn',
          maxZoom: 22,
          maxNativeZoom: kIsWeb ? 18 : 20,
        ),

        // GPS Accuracy Circle
        if (_isGpsMode && _currentGpsPosition != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: LatLng(
                  _currentGpsPosition!.latitude,
                  _currentGpsPosition!.longitude,
                ),
                radius: _gpsAccuracy,
                useRadiusInMeter: true,
                color: kGpsBlue.withOpacity(0.1),
                borderColor: kGpsBlue.withOpacity(0.3),
                borderStrokeWidth: 1.5,
              ),
            ],
          ),

        // Existing Polygons from Master Area (Neighboring/overlapped plots shown in green)
        if (_existingLocations.isNotEmpty)
          PolygonLayer(
            polygons: _existingLocations
                .map((loc) {
                  final activeBoundary = (loc.approvalStatus == 'PENDING' && loc.pendingBoundary != null)
                      ? loc.pendingBoundary
                      : loc.boundary;
                  if (activeBoundary == null || activeBoundary.length < 3) return null;
                  return Polygon(
                    points: activeBoundary.map((e) => LatLng(e[1], e[0])).toList(),
                    color: const Color(0xFF22C55E).withOpacity(0.25), // Green fill
                    borderColor: const Color(0xFF16A34A), // Green border
                    borderStrokeWidth: 2.0,
                  );
                })
                .whereType<Polygon>()
                .toList(),
          ),

        // Polygon fill (The current growing area: blue if approved/creating, orange if pending)
        if (_polygonPoints.length >= 3)
          PolygonLayer(
            polygons: <Polygon<Object>>[
              Polygon(
                points: _polygonPoints,
                color: (widget.location?.approvalStatus == 'PENDING' 
                        ? const Color(0xFFF59E0B) 
                        : const Color(0xFF3B82F6))
                    .withOpacity(0.25),
                borderColor: widget.location?.approvalStatus == 'PENDING' 
                    ? const Color(0xFFF59E0B) 
                    : const Color(0xFF3B82F6),
                borderStrokeWidth: 2.5,
              ),
            ],
          ),

        // Polygon edge lines (when < 3 points, show connecting lines)
        if (_polygonPoints.length >= 2 && _polygonPoints.length < 3)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _polygonPoints,
                color: widget.location?.approvalStatus == 'PENDING' 
                    ? const Color(0xFFF59E0B) 
                    : const Color(0xFF3B82F6),
                strokeWidth: 2.5,
              ),
            ],
          ),

        // Midpoint insert markers (show "+" on edges for polygon with >= 3 points)
        if (_polygonPoints.length >= 3 && !_isGpsMode)
          MarkerLayer(markers: _buildMidpointMarkers()),

        // Polygon vertex markers (draggable)
        MarkerLayer(markers: _buildVertexMarkers()),

        // GPS current position marker
        if (_isGpsMode && _currentGpsPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(
                  _currentGpsPosition!.latitude,
                  _currentGpsPosition!.longitude,
                ),
                width: 28,
                height: 28,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kGpsBlue,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color:
                                kGpsBlue.withOpacity(_pulseAnimation.value * 0.5),
                            blurRadius: 12 * _pulseAnimation.value,
                            spreadRadius: 4 * _pulseAnimation.value,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
      ],
    );
  }

  List<Marker> _buildVertexMarkers() {
    return List.generate(_polygonPoints.length, (i) {
      final point = _polygonPoints[i];
      final isBeingDragged = _draggingIndex == i;

      return Marker(
        point: point,
        width: isBeingDragged ? 28 : 18,
        height: isBeingDragged ? 28 : 18,
        child: GestureDetector(
          onPanStart: (_) => _onPointDragStart(i),
          onPanUpdate: (details) {
            final screenOffset = _mapController.camera
                .latLngToScreenOffset(point);
            final newScreenOffset = Offset(
              screenOffset.dx + details.delta.dx,
              screenOffset.dy + details.delta.dy,
            );
            final newLatLng =
                _mapController.camera.screenOffsetToLatLng(newScreenOffset);
            _onPointDragUpdate(newLatLng);
          },
          onPanEnd: (_) => _onPointDragEnd(),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isBeingDragged
                  ? Colors.orange
                  : Colors.white,
              border: Border.all(
                color: isBeingDragged
                    ? Colors.orange.shade800
                    : (widget.location?.approvalStatus == 'PENDING' 
                        ? const Color(0xFFF59E0B) 
                        : const Color(0xFF3B82F6)),
                width: 2.5,
              ),
              boxShadow: isBeingDragged
                  ? [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      );
    });
  }

  List<Marker> _buildMidpointMarkers() {
    final markers = <Marker>[];
    for (int i = 0; i < _polygonPoints.length; i++) {
      final next = (i + 1) % _polygonPoints.length;
      final mid = LatLng(
        (_polygonPoints[i].latitude + _polygonPoints[next].latitude) / 2,
        (_polygonPoints[i].longitude + _polygonPoints[next].longitude) / 2,
      );

      final activeColor = widget.location?.approvalStatus == 'PENDING' 
          ? const Color(0xFFF59E0B) 
          : const Color(0xFF3B82F6);

      markers.add(
        Marker(
          point: mid,
          width: 22,
          height: 22,
          child: GestureDetector(
            onTap: () => _insertPoint(i, mid),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activeColor.withOpacity(0.2),
                border: Border.all(
                  color: activeColor.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.add,
                size: 14,
                color: kPrimaryColor.withOpacity(0.7),
              ),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  Widget _buildMapControls() {
    return Positioned(
      top: 10,
      right: 10,
      child: Column(
        children: [
          _mapBtn(Icons.add, 'zoom_in', _zoomIn, color: kPrimaryColor),
          const SizedBox(height: 6),
          _mapBtn(Icons.remove, 'zoom_out', _zoomOut, color: kPrimaryColor),
          const SizedBox(height: 14),
          _mapBtn(Icons.undo, 'undo', _undoPoint, color: kTextGray),
          const SizedBox(height: 6),
          _mapBtn(Icons.delete_outline, 'clear', _clearPoints,
              color: Colors.redAccent),
          if (_isGpsMode) ...[
            const SizedBox(height: 6),
            _mapBtn(Icons.my_location, 'center', _centerOnGps,
                color: kGpsBlue),
          ],
        ],
      ),
    );
  }

  Widget _buildMapControlBtn(
    IconData icon,
    String tag,
    VoidCallback onTap, {
    Color color = kTextGray,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  Widget _buildPointsInfo() {
    final accuracyLevel = GpsService.getAccuracyLevel(_gpsAccuracy);
    final accuracyColor = switch (accuracyLevel) {
      GpsAccuracyLevel.high => kPrimaryColor,
      GpsAccuracyLevel.medium => Colors.orange,
      GpsAccuracyLevel.low => Colors.redAccent,
      GpsAccuracyLevel.none => kTextGray,
    };

    final hasPoints = _polygonPoints.isNotEmpty;
    final infoText = _polygonPoints.length < 3
        ? _isGpsMode
            ? 'Đi đến góc vùng trồng → nhấn "Thêm điểm"'
            : 'Tap bản đồ để vẽ ranh giới vùng trồng'
        : '${_polygonPoints.length} điểm  ·  ${NumberFormat("#,###").format(_rawAreaM2.round())} m²';

    return Positioned(
      bottom: 10,
      left: 10,
      right: _isGpsMode ? 56 : 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          color: Colors.black.withValues(alpha: 0.72),
          child: Row(
            children: [
              Icon(
                hasPoints
                    ? Icons.crop_free
                    : Icons.touch_app,
                color: hasPoints ? kPrimaryColor : kTextGray,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  infoText,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              if (_isGpsMode && _currentGpsPosition != null) ...[
                const SizedBox(width: 8),
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: accuracyColor),
                ),
                const SizedBox(width: 4),
                Text(
                  '±${_gpsAccuracy.toStringAsFixed(1)}m',
                  style: TextStyle(
                    color: accuracyColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGpsPanel() {
    final hasPosition = _currentGpsPosition != null;
    final accuracyLevel = GpsService.getAccuracyLevel(_gpsAccuracy);
    final accuracyColor = switch (accuracyLevel) {
      GpsAccuracyLevel.high => kPrimaryColor,
      GpsAccuracyLevel.medium => Colors.orange,
      GpsAccuracyLevel.low => Colors.redAccent,
      GpsAccuracyLevel.none => kTextGray,
    };
    final accuracyLabel = switch (accuracyLevel) {
      GpsAccuracyLevel.high => 'Rất tốt',
      GpsAccuracyLevel.medium => 'Tạm ổn',
      GpsAccuracyLevel.low => 'Kém',
      GpsAccuracyLevel.none => 'Đang tìm...',
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGpsBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // GPS Status
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: kGpsBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.satellite_alt, color: kGpsBlue, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: hasPosition
                      ? Text(
                          '${_currentGpsPosition!.latitude.toStringAsFixed(6)}, '
                          '${_currentGpsPosition!.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                              color: kTextLight, fontSize: 12,
                              fontFamily: 'monospace'),
                        )
                      : const Text('Đang tìm vị trí GPS...',
                          style: TextStyle(color: kTextGray, fontSize: 13)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accuracyColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: accuracyColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: accuracyColor),
                      ),
                      const SizedBox(width: 4),
                      Text(accuracyLabel,
                          style: TextStyle(
                              color: accuracyColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: hasPosition ? _addGpsPoint : null,
                icon: const Icon(Icons.add_location_alt, size: 20),
                label: const Text(
                  'THÊM ĐIỂM TẠI ĐÂY',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGpsBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: kTextGray.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper: short alias for map control buttons
  Widget _mapBtn(IconData icon, String tag, VoidCallback onTap,
      {Color color = kTextGray}) =>
      _buildMapControlBtn(icon, tag, onTap, color: color);

  InputDecoration _inputDecor(String text, {bool isRequired = false}) {
    if (!isRequired) return InputDecoration(labelText: text);
    return InputDecoration(
      label: RichText(
        text: TextSpan(
          text: '* ',
          style: const TextStyle(color: Colors.red, fontSize: 16),
          children: [
            TextSpan(
                text: text,
                style: const TextStyle(color: kTextGray, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
