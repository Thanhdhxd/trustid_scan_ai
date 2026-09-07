import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/api/dio_client.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';
import '../../domain/master_growing_area.dart';
import '../../data/vietnam_units.dart';
import 'widgets/multi_select_dropdown.dart';
import 'widgets/quick_add_user_dialog.dart';
import 'package:trustid_scan_ai/home/data/home_stats_repository.dart';

const Color kPrimaryColor = Color(0xFF00875A);
const Color kBackgroundDark = Color(0xFF0F2B46);
const Color kSurfaceDark = Color(0xFF16325B);
const Color kTextLight = Color(0xFFE8EDF3);
const Color kTextGray = Color(0xFF94A3B8);

class MasterAreaFormScreen extends ConsumerStatefulWidget {
  final MasterGrowingArea? masterArea;

  const MasterAreaFormScreen({super.key, this.masterArea});

  @override
  ConsumerState<MasterAreaFormScreen> createState() => _MasterAreaFormScreenState();
}

class _MasterAreaFormScreenState extends ConsumerState<MasterAreaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _codeCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _managerCtrl;
  late TextEditingController _ownerCtrl;
  late TextEditingController _plantTypeCtrl;
  late TextEditingController _addressCtrl;

  String? _selectedProvince;
  String? _selectedWard;
  List<Map<String, dynamic>> _wards = [];

  List<dynamic> _leaders = [];
  List<dynamic> _kcs = [];
  List<String> _selectedLeaderIds = [];
  List<String> _selectedKcsIds = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.masterArea?.name ?? '');
    _codeCtrl = TextEditingController(text: widget.masterArea?.code ?? '');
    _areaCtrl = TextEditingController(text: widget.masterArea?.maxAreaM2.toString() ?? '');
    _managerCtrl = TextEditingController(text: widget.masterArea?.managerName ?? '');
    _ownerCtrl = TextEditingController(text: widget.masterArea?.ownerName ?? '');
    _plantTypeCtrl = TextEditingController(text: widget.masterArea?.plantType ?? '');
    _addressCtrl = TextEditingController(text: widget.masterArea?.address ?? '');

    if (widget.masterArea != null) {
      final provinceExists = vietnamUnits.any((e) => e['name'] == widget.masterArea!.province);
      if (provinceExists) {
        _selectedProvince = widget.masterArea!.province;
        _loadWards();
        final wardExists = _wards.any((e) => e['name'] == widget.masterArea!.ward);
        if (wardExists) _selectedWard = widget.masterArea!.ward;
      }
      
      // Load current selections from masterArea if available
      if (widget.masterArea?.leaders != null) {
        _selectedLeaderIds = widget.masterArea!.leaders!.map((e) => e['id'] as String).toList();
      }
      if (widget.masterArea?.kcsStaffs != null) {
        _selectedKcsIds = widget.masterArea!.kcsStaffs!.map((e) => e['id'] as String).toList();
      }
    }
    
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final dio = ref.read(dioProvider);
      
      // Fetch leaders
      final resLeaders = await dio.get('/users', queryParameters: {'roleName': 'TEAM_LEADER'});
      final leaders = (resLeaders.data is List) ? resLeaders.data : (resLeaders.data['data'] ?? []);
      
      // Fetch KCS
      final resKcs = await dio.get('/users', queryParameters: {'roleName': 'KCS_STAFF'});
      final kcs = (resKcs.data is List) ? resKcs.data : (resKcs.data['data'] ?? []);
      
      if (mounted) {
        setState(() {
          _leaders = List.from(leaders);
          _kcs = List.from(kcs);
        });
      }
    } catch (e) {
      debugPrint('Failed to load users: $e');
    }
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
        setState(() => _wards = List<Map<String, dynamic>>.from(province['wards']));
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
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _areaCtrl.dispose();
    _managerCtrl.dispose();
    _ownerCtrl.dispose();
    _plantTypeCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final dio = ref.read(dioProvider);
      final payload = {
        'name': _nameCtrl.text.trim(),
        'code': _codeCtrl.text.trim(),
        'maxAreaM2': double.tryParse(_areaCtrl.text.trim()) ?? 0,
        'managerName': _managerCtrl.text.trim(),
        'ownerName': _ownerCtrl.text.trim(),
        'plantType': _plantTypeCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'province': _selectedProvince,
        'ward': _selectedWard,
        'leaderIds': _selectedLeaderIds,
        'kcsStaffIds': _selectedKcsIds,
      };

      if (widget.masterArea == null) {
        await dio.post('/farm/master-growing-areas', data: payload);
      } else {
        await dio.patch('/farm/master-growing-areas/${widget.masterArea!.id}', data: payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lưu thành công'), backgroundColor: kPrimaryColor),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.masterArea != null;
    final sortedProvinces = vietnamUnits.map((e) => e['name'].toString()).toList()..sort();
    final sortedWards = _wards.map((e) => e['name'].toString()).toList()..sort();

    return Scaffold(
      backgroundColor: kBackgroundDark,
      appBar: AppBar(
        title: Text(isEdit ? 'Sửa Mã vùng trồng lớn' : 'Thêm Mã vùng trồng nhanh', style: const TextStyle(color: kTextLight, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: kBackgroundDark,
        iconTheme: const IconThemeData(color: kTextLight),
        centerTitle: true,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _codeCtrl,
                    label: '* Mã vùng trồng',
                    hintText: 'VD: MVT-01',
                    required: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _nameCtrl,
                    label: '* Tên vùng trồng',
                    hintText: 'VD: Vùng Trồng Vải',
                    required: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    value: _selectedProvince,
                    label: 'Tỉnh / Thành phố',
                    hintText: 'Chọn Tỉnh',
                    items: sortedProvinces,
                    onChanged: _onProvinceChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    value: _selectedWard,
                    label: 'Phường / Xã',
                    hintText: 'Chọn Xã',
                    items: sortedWards,
                    onChanged: _selectedProvince == null ? null : (val) => setState(() => _selectedWard = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _addressCtrl,
              label: 'Địa chỉ chi tiết',
              hintText: 'Thôn, Xóm, Số nhà',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _ownerCtrl,
                    label: 'Đơn vị sở hữu',
                    hintText: 'Tên đơn vị, HTX...',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _managerCtrl,
                    label: 'Người quản lý',
                    hintText: 'Tên người quản lý chung',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _plantTypeCtrl,
                    label: 'Loại cây trồng',
                    hintText: 'VD: Lúa, Vải',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAreaField(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: MultiSelectDropdown(
                    label: 'Danh sách Đội trưởng',
                    hintText: 'Chọn Đội trưởng phụ trách',
                    items: _leaders,
                    selectedIds: _selectedLeaderIds,
                    idMapper: (item) => item['id'],
                    titleMapper: (item) => item['fullName'] ?? item['username'],
                    subtitleMapper: (item) => item['username'],
                    onChanged: (val) {
                      setState(() => _selectedLeaderIds = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final newUser = await showDialog(
                        context: context,
                        builder: (_) => const QuickAddUserDialog(roleName: 'TEAM_LEADER'),
                      );
                      if (newUser != null) {
                        setState(() {
                          _leaders.add(newUser);
                          _selectedLeaderIds.add(newUser['id']);
                        });
                      }
                    },
                    icon: const Icon(Icons.add, color: kPrimaryColor, size: 18),
                    label: const Text('Thêm Nhanh', style: TextStyle(color: kPrimaryColor)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kPrimaryColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            MultiSelectDropdown(
              label: 'Danh sách Nhân viên KCS',
              hintText: 'Chọn Nhân viên KCS phụ trách (Tùy chọn)',
              items: _kcs,
              selectedIds: _selectedKcsIds,
              idMapper: (item) => item['id'],
              titleMapper: (item) => item['fullName'] ?? item['username'],
              subtitleMapper: (item) => item['username'],
              onChanged: (val) {
                setState(() => _selectedKcsIds = val);
              },
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(isEdit ? 'LƯU THÔNG TIN' : 'TẠO MỚI', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Giới hạn diện tích (m2)', style: TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: kSurfaceDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () {
                  int val = int.tryParse(_areaCtrl.text.replaceAll(',', '')) ?? 100000;
                  if (val > 1000) setState(() => _areaCtrl.text = (val - 1000).toString());
                },
                child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.remove, color: kTextGray, size: 20)),
              ),
              Expanded(
                child: TextFormField(
                  controller: _areaCtrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kTextLight, fontSize: 15),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true),
                ),
              ),
              InkWell(
                onTap: () {
                  int val = int.tryParse(_areaCtrl.text.replaceAll(',', '')) ?? 100000;
                  setState(() => _areaCtrl.text = (val + 1000).toString());
                },
                child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.add, color: kTextGray, size: 20)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text('Mặc định: 100,000 m2 (10ha)', style: TextStyle(color: kTextGray, fontSize: 11)),
      ],
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String label,
    required String hintText,
    required List<String> items,
    required void Function(String?)? onChanged,
    bool hideLabel = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hideLabel) ...[
          Text(label, style: const TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
        ],
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          style: const TextStyle(color: kTextLight, fontSize: 14),
          dropdownColor: kSurfaceDark,
          icon: const Icon(Icons.keyboard_arrow_down, color: kTextGray),
          hint: Text(hintText, style: const TextStyle(color: Colors.white54, fontSize: 14)),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kPrimaryColor),
            ),
            filled: true,
            fillColor: kSurfaceDark,
          ),
          items: items.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              if (required) const TextSpan(text: '* ', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              TextSpan(text: label.replaceAll('* ', ''), style: const TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: kTextLight, fontSize: 14),
          keyboardType: keyboardType,
          validator: (val) {
            if (required && (val == null || val.trim().isEmpty)) {
              return 'Không để trống';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kPrimaryColor),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            filled: true,
            fillColor: kSurfaceDark,
          ),
        ),
      ],
    );
  }
}
