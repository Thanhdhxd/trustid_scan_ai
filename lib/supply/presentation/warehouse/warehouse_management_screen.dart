import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:trustid_scan_ai/supply/data/supply_repository.dart';
import 'package:trustid_scan_ai/farm/data/vietnam_units.dart';
import 'package:trustid_scan_ai/farm/data/province_coords.dart';
import 'package:trustid_scan_ai/dashboard/data/tenant_repository.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';
import 'warehouse_stock_screen.dart';

const List<Map<String, String>> kWarehouseTypes = [
  {'value': 'PRODUCTION', 'label': 'Kho Sản xuất'},
  {'value': 'FINISHED_GOODS', 'label': 'Kho Thành phẩm'},
  {'value': 'RAW_MATERIAL', 'label': 'Kho Nguyên liệu'},
  {'value': 'TEMPORARY', 'label': 'Kho Tạm'},
];

class WarehouseManagementScreen extends ConsumerStatefulWidget {
  const WarehouseManagementScreen({super.key});

  @override
  ConsumerState<WarehouseManagementScreen> createState() => _WarehouseManagementScreenState();
}

class _WarehouseManagementScreenState extends ConsumerState<WarehouseManagementScreen> {
  static const Color kPrimaryColor = Color(0xFF00875A);
  static const Color kBackgroundDark = Color(0xFF0F2B46);
  static const Color kSurfaceDark = Color(0xFF16325B);
  static const Color kTextLight = Color(0xFFE8EDF3);
  static const Color kTextGray = Color(0xFF94A3B8);

  bool _isLoading = true;
  List<dynamic> _warehouses = [];
  bool _isFetchingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 1;
  final int _limit = 15;
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchWarehouses(isRefresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_isFetchingMore != true && _hasMoreData == true && _isLoading != true) {
        _fetchWarehouses();
      }
    }
  }

  Future<void> _fetchWarehouses({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _hasMoreData = true;
        _isLoading = true;
      });
    } else {
      setState(() => _isFetchingMore = true);
    }

    try {
      final list = await ref.read(supplyRepositoryProvider).getWarehouses(
        page: _currentPage,
        limit: _limit,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      if (mounted) {
        setState(() {
          if (isRefresh) {
            _warehouses = list;
          } else {
            _warehouses.addAll(list);
          }
          _currentPage++;
          if (list.length < _limit) {
            _hasMoreData = false;
          }
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải danh sách kho: $e')));
      }
    }
  }

  void _showWarehouseForm({Map<String, dynamic>? warehouse}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WarehouseForm(
        warehouse: warehouse,
        onSaved: () {
          Navigator.pop(context);
          _fetchWarehouses(isRefresh: true);
        },
      ),
    );
  }

  Future<void> _deleteWarehouse(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurfaceDark,
        title: const Text('Xác nhận xóa', style: TextStyle(color: kTextLight)),
        content: const Text('Bạn có chắc chắn muốn xóa kho này?', style: TextStyle(color: kTextGray)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy', style: TextStyle(color: kTextGray))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(supplyRepositoryProvider).deleteWarehouse(id);
        _fetchWarehouses(isRefresh: true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      appBar: AppBar(
        title: const Text('Quản Lý Kho', style: TextStyle(color: kTextLight, fontWeight: FontWeight.bold)),
        backgroundColor: kBackgroundDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextLight),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: kSurfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: TextField(
                style: const TextStyle(color: kTextLight),
                decoration: const InputDecoration(
                  icon: Icon(Icons.search, color: kTextGray, size: 20),
                  hintText: 'Tìm kiếm kho...',
                  hintStyle: TextStyle(color: kTextGray, fontSize: 14),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  _searchQuery = val;
                  if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
                  _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                    _fetchWarehouses(isRefresh: true);
                  });
                },
              ),
            ),
          ),
          Expanded(
            child: _isLoading == true
              ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
              : _warehouses.isEmpty == true
                  ? const Center(child: Text('Không có dữ liệu kho', style: TextStyle(color: kTextGray)))
                  : RefreshIndicator(
                      onRefresh: () => _fetchWarehouses(isRefresh: true),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _warehouses.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _warehouses.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: _hasMoreData == true
                                    ? const CircularProgressIndicator(color: kPrimaryColor)
                                    : const Text('Đã hiển thị hết', style: TextStyle(color: Colors.grey)),
                              ),
                            );
                          }
                          final w = _warehouses[index];
                          return _buildWarehouseCard(w);
                        },
                      ),
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showWarehouseForm(),
        backgroundColor: kPrimaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildWarehouseCard(Map<String, dynamic> w) {
    final typeVal = w['type'] ?? 'UNKNOWN';
    String typeLabel = typeVal;
    try {
      typeLabel = kWarehouseTypes.firstWhere((t) => t['value'] == typeVal, orElse: () => {'label': typeVal})['label'] ?? typeVal;
    } catch (_) {}

    final isDefault = w['isDefault'] ?? w['is_default'] ?? false;

    String managerName = 'Chưa gán';
    final mgr = w['manager'] ?? w['managerInfo'];
    if (mgr is Map) {
      managerName = mgr['fullName'] ?? mgr['full_name'] ?? mgr['name'] ?? mgr['email'] ?? 'Chưa gán';
    } else {
      final mn = w['managerName'] ?? w['manager_name'];
      if (mn != null && mn.toString().isNotEmpty) {
        managerName = mn.toString();
      }
    }

    Color typeColor = Colors.blueAccent;
    if (typeVal == 'FINISHED_GOODS') typeColor = Colors.purple;
    if (typeVal == 'RAW_MATERIAL') typeColor = Colors.teal;
    if (typeVal == 'TEMPORARY') typeColor = Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => WarehouseStockScreen(warehouseId: w['id']?.toString() ?? '')),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.warehouse_rounded, color: kPrimaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          w['name'] ?? 'Warehouse',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextLight),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          w['address'] ?? 'Chưa có địa chỉ',
                          style: const TextStyle(color: kTextGray, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildActionBtn(
                        icon: Icons.edit_rounded,
                        color: kPrimaryColor,
                        onTap: () => _showWarehouseForm(warehouse: w),
                      ),
                      const SizedBox(width: 8),
                      _buildActionBtn(
                        icon: Icons.delete_rounded,
                        color: Colors.redAccent,
                        onTap: () => _deleteWarehouse(w['id']),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildBadge(typeLabel, typeColor),
                  if (isDefault == true)
                    _buildBadge('Mặc định', Colors.amber),
                  _buildBadge(
                    '👤 $managerName',
                    const Color(0xFF94A3B8),
                  ),
                  _buildBadge('● Đang hoạt động', const Color(0xFF00875A)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}

class _WarehouseForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? warehouse;
  final VoidCallback onSaved;

  const _WarehouseForm({this.warehouse, required this.onSaved});

  @override
  ConsumerState<_WarehouseForm> createState() => _WarehouseFormState();
}

class _WarehouseFormState extends ConsumerState<_WarehouseForm> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  String? _selectedType = 'PRODUCTION';
  bool _isDefault = false;
  String? _selectedUser;
  List<dynamic> _users = [];
  String? _selectedProvince;
  String? _selectedWard;
  LatLng _selectedLocation = const LatLng(21.0285, 105.8542);
  final MapController _mapController = MapController();
  bool _isSaving = false;

  String? _nameError;
  String? _provinceError;

  Future<void> _fetchUsers() async {
    try {
      final list = await ref.read(tenantRepositoryProvider).getTenantUsers(limit: 100);
      if (mounted) {
        setState(() {
          _users = list;
        });
      }
    } catch (e) {
      debugPrint('Failed to load users: $e');
    }
  }

  List<String> get _provinces => vietnamUnits.map((e) => e['name'].toString()).toList();
  List<String> get _wards {
    if (_selectedProvince == null) return [];
    final province = vietnamUnits.firstWhere((p) => p['name'] == _selectedProvince, orElse: () => <String, dynamic>{});
    if (province.isEmpty || province['wards'] == null) return [];
    final list = (province['wards'] as List).map((w) => w['name'].toString()).toList();
    list.sort();
    return list;
  }

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    
    if (widget.warehouse != null) {
      _nameController.text = widget.warehouse!['name'] ?? '';
      _addressController.text = widget.warehouse!['address'] ?? '';
      _selectedType = widget.warehouse!['type'] ?? 'PRODUCTION';
      
      if (!kWarehouseTypes.any((t) => t['value'] == _selectedType)) {
        if (_selectedType != 'PRODUCTION') _selectedType = 'PRODUCTION';
      }
      
      _isDefault = widget.warehouse!['isDefault'] ?? widget.warehouse!['is_default'] ?? false;
      
      final managerId = widget.warehouse!['managerId'] ?? widget.warehouse!['manager_id'];
      if (managerId != null) {
        _selectedUser = managerId.toString();
      }
      
      final pInfo = widget.warehouse!['projectedInfo'] ?? widget.warehouse!['projected_info'];
      if (pInfo != null && pInfo is Map) {
        final pv = pInfo['province']?.toString();
        final wd = pInfo['ward']?.toString();
        if (pv != null && pv.isNotEmpty && _provinces.contains(pv)) {
           _selectedProvince = pv;
           if (wd != null && wd.isNotEmpty && _wards.contains(wd)) {
             _selectedWard = wd;
           }
        }
      }
      if (widget.warehouse!['lat'] != null && widget.warehouse!['long'] != null) {
        try {
          _selectedLocation = LatLng(
            (widget.warehouse!['lat'] as num).toDouble(),
            (widget.warehouse!['long'] as num).toDouble(),
          );
        } catch (_) {}
      } else if (widget.warehouse!['coordinate'] is Map) {
        final coords = widget.warehouse!['coordinate']['coordinates'];
        if (coords is List && coords.length >= 2) {
          try {
            _selectedLocation = LatLng(
              (coords[1] as num).toDouble(),
              (coords[0] as num).toDouble(),
            );
          } catch (_) {}
        }
      }
    }
  }

  Future<void> _save() async {
    bool hasError = false;
    setState(() {
      _nameError = _nameController.text.trim().isEmpty ? 'Vui lòng nhập Tên kho' : null;
      _provinceError = (_selectedProvince == null || _selectedProvince!.isEmpty) ? 'Vui lòng chọn Tỉnh/Thành phố' : null;

      if (_nameError != null || _provinceError != null) {
        hasError = true;
      }
    });

    if (hasError) return;
    
    setState(() => _isSaving = true);
    try {
      final data = {
        'name': _nameController.text,
        'address': _addressController.text,
        'type': _selectedType,
        'isDefault': _isDefault,
        'managerId': _selectedUser,
        'lat': _selectedLocation.latitude,
        'long': _selectedLocation.longitude,
        'projectedInfo': {
          'province': _selectedProvince,
          'ward': _selectedWard,
        }
      };

      if (widget.warehouse == null) {
        await ref.read(supplyRepositoryProvider).createWarehouse(data);
      } else {
        await ref.read(supplyRepositoryProvider).updateWarehouse(widget.warehouse!['id'], data);
      }
      widget.onSaved();
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi lưu: $e')));
    }
  }

  InputDecoration _darkInput({String? labelText, Widget? label, String? errorText}) {
    const borderColor = Color(0xFF334155);
    const focusedColor = Color(0xFF00875A);
    return InputDecoration(
      labelText: labelText,
      label: label,
      errorText: errorText,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
      floatingLabelStyle: const TextStyle(color: focusedColor),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: focusedColor, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.redAccent)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const kBg = Color(0xFF0F172A);
    const kSurface = Color(0xFF1E293B);
    const kText = Color(0xFFE2E8F0);
    const kSubText = Color(0xFF94A3B8);
    const kGreen = Color(0xFF00875A);

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: Color(0xFF334155))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: kGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.warehouse_rounded, color: kGreen, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.warehouse == null ? 'Thêm Kho Mới' : 'Cập Nhật Kho',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kText),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: kSubText),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          style: const TextStyle(color: kText),
                          decoration: _darkInput(
                            label: RichText(text: const TextSpan(children: [
                              TextSpan(text: '* ', style: TextStyle(color: Colors.redAccent)),
                              TextSpan(text: 'Tên kho', style: TextStyle(color: Color(0xFF94A3B8))),
                            ])),
                            errorText: _nameError,
                          ),
                          onChanged: (v) { if (_nameError != null) setState(() => _nameError = null); },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Theme(
                          data: Theme.of(context).copyWith(canvasColor: kSurface),
                          child: DropdownButtonFormField<String>(
                            value: _selectedType,
                            dropdownColor: kSurface,
                            style: const TextStyle(color: kText),
                            decoration: _darkInput(labelText: 'Phân loại'),
                            items: kWarehouseTypes.map((t) => DropdownMenuItem<String>(
                              value: t['value'],
                              child: Text(t['label']!, style: const TextStyle(color: kText), overflow: TextOverflow.ellipsis),
                            )).toList(),
                            onChanged: (val) => setState(() => _selectedType = val),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Theme(
                          data: Theme.of(context).copyWith(canvasColor: kSurface),
                          child: DropdownButtonFormField<String>(
                            value: _users.any((u) => (u is Map ? u['id']?.toString() : (u is User ? u.id : u.toString())) == _selectedUser) ? _selectedUser : null,
                            dropdownColor: kSurface,
                            style: const TextStyle(color: kText),
                            decoration: _darkInput(labelText: 'Thủ kho'),
                            items: _users.map<DropdownMenuItem<String>>((u) {
                              final uid = (u is Map ? u['id'] : (u is User ? u.id : u.toString()))?.toString() ?? '';
                              final name = (u is Map ? (u['fullName'] ?? u['name'] ?? u['email']) : (u is User ? u.fullName : u.toString()))?.toString() ?? 'User';
                              return DropdownMenuItem<String>(
                                value: uid,
                                child: Text(name, style: const TextStyle(color: kText), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedUser = val),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: kSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Kho mặc định', style: TextStyle(color: kSubText, fontSize: 11)),
                              Row(
                                children: [
                                  const Text('Tắt', style: TextStyle(color: kSubText, fontSize: 12)),
                                  Switch(
                                    value: _isDefault,
                                    activeColor: kGreen,
                                    onChanged: (v) => setState(() => _isDefault = v),
                                  ),
                                  const Text('Bật', style: TextStyle(color: kSubText, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Theme(
                          data: Theme.of(context).copyWith(canvasColor: kSurface),
                          child: DropdownButtonFormField<String>(
                            value: _selectedProvince,
                            dropdownColor: kSurface,
                            style: const TextStyle(color: kText),
                            isExpanded: true,
                            menuMaxHeight: 300,
                            decoration: _darkInput(
                              label: RichText(text: const TextSpan(children: [
                                TextSpan(text: '* ', style: TextStyle(color: Colors.redAccent)),
                                TextSpan(text: 'Tỉnh/Thành phố', style: TextStyle(color: Color(0xFF94A3B8))),
                              ])),
                              errorText: _provinceError,
                            ),
                            items: _provinces.map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p, style: const TextStyle(color: kText), overflow: TextOverflow.ellipsis),
                            )).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedProvince = val;
                                _selectedWard = null;
                                if (_provinceError != null) _provinceError = null;
                              });
                              if (val != null && provinceCoordinates.containsKey(val)) {
                                final c = provinceCoordinates[val]!;
                                final loc = LatLng(c['lat']!, c['lng']!);
                                setState(() => _selectedLocation = loc);
                                _mapController.move(loc, 13);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Theme(
                          data: Theme.of(context).copyWith(canvasColor: kSurface),
                          child: DropdownButtonFormField<String>(
                            value: _selectedWard,
                            dropdownColor: kSurface,
                            style: const TextStyle(color: kText),
                            isExpanded: true,
                            menuMaxHeight: 300,
                            decoration: _darkInput(labelText: 'Phường/Xã'),
                            items: _wards.map((w) => DropdownMenuItem(
                              value: w,
                              child: Text(w, style: const TextStyle(color: kText), overflow: TextOverflow.ellipsis),
                            )).toList(),
                            onChanged: (val) => setState(() => _selectedWard = val),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _addressController,
                    style: const TextStyle(color: kText),
                    decoration: _darkInput(labelText: 'Địa chỉ chi tiết (Số nhà, đường)'),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.map_outlined, color: Color(0xFF94A3B8), size: 16),
                      SizedBox(width: 6),
                      Text('Vị trí trên bản đồ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 220,
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _selectedLocation,
                          initialZoom: 13,
                          onTap: (_, latLng) {
                            setState(() => _selectedLocation = latLng);
                          },
                        ),
                        children: [
                          TileLayer(urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}'),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _selectedLocation,
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.location_on, color: Colors.redAccent, size: 40),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('LƯU THÔNG TIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
