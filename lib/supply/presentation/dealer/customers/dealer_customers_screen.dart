import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:trustid_scan_ai/supply/data/dealer_providers.dart';
import 'package:trustid_scan_ai/supply/data/dealer_repository.dart';
import 'package:trustid_scan_ai/core/navigation.dart';

class DealerCustomersScreen extends ConsumerStatefulWidget {
  const DealerCustomersScreen({super.key});

  @override
  ConsumerState<DealerCustomersScreen> createState() => _DealerCustomersScreenState();
}

class _DealerCustomersScreenState extends ConsumerState<DealerCustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _customers = [];
  bool _isLoading = false;
  Timer? _debounce;

  final TextEditingController _newNameController = TextEditingController();
  final TextEditingController _newPhoneController = TextEditingController();
  final TextEditingController _newAddressController = TextEditingController();
  bool _isSavingCustomer = false;

  List<dynamic> _groups = [];
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _fetchGroups();
    _fetchCustomers();
  }

  Future<void> _fetchGroups() async {
    try {
      final repo = ref.read(dealerRepositoryProvider);
      final data = await repo.getCustomerGroups();
      if (mounted) setState(() => _groups = data);
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _newNameController.dispose();
    _newPhoneController.dispose();
    _newAddressController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(dealerRepositoryProvider);
      final query = _searchController.text.trim();
      final data = await repo.getDealerCustomers(search: query);
      if (mounted) setState(() => _customers = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCustomerDialog(dynamic customer) {
    final isEditing = customer != null;
    _newNameController.text = isEditing ? (customer['name'] ?? '') : '';
    _newPhoneController.text = isEditing ? (customer['phone'] ?? '') : '';
    _newAddressController.text = isEditing ? (customer['address'] ?? '') : '';
    
    if (isEditing && customer['groupId'] != null) {
      _selectedGroupId = customer['groupId'].toString();
    } else if (isEditing && customer['group'] != null && customer['group']['id'] != null) {
      _selectedGroupId = customer['group']['id'].toString();
    } else {
      _selectedGroupId = null;
    }
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: 500,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isEditing ? 'Sửa khách hàng' : 'Thêm khách hàng', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        IconButton(icon: const Icon(Icons.close, color: Colors.redAccent), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Form(
                          key: formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Tên khách hàng', required: true),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _newNameController,
                                style: const TextStyle(color: Colors.white),
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(255),
                                ],
                                decoration: InputDecoration(
                                  hintText: 'Ví dụ: Nguyễn Văn A',
                                  hintStyle: const TextStyle(color: Colors.white54),
                                  filled: true,
                                  fillColor: const Color(0xFF16325B),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Vui lòng nhập tên khách hàng';
                                  }
                                  if (val.trim().length > 255) {
                                    return 'Tên khách hàng không được vượt quá 255 ký tự';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              _buildLabel('Số điện thoại', required: true),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _newPhoneController,
                                style: const TextStyle(color: Colors.white),
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                decoration: InputDecoration(
                                  hintText: 'Nhập số điện thoại',
                                  hintStyle: const TextStyle(color: Colors.white54),
                                  filled: true,
                                  fillColor: const Color(0xFF16325B),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Vui lòng nhập số điện thoại';
                                  }
                                  final phoneRegex = RegExp(r'^0[0-9]{9}$');
                                  if (!phoneRegex.hasMatch(val.trim())) {
                                    return 'Số điện thoại không hợp lệ (Bắt đầu bằng 0, gồm 10 chữ số)';
                                  }
                                  
                                  // Check duplicate phone number in local list
                                  final inputPhone = val.trim();
                                  final isDuplicate = _customers.any((c) {
                                    if (isEditing && c['id'].toString() == customer['id'].toString()) {
                                      return false;
                                    }
                                    final dbPhone = (c['phone'] ?? '').toString().replaceAll(RegExp(r'\s+'), '');
                                    return dbPhone == inputPhone;
                                  });
                                  
                                  if (isDuplicate) {
                                    return 'Số điện thoại này đã tồn tại trong danh sách';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              _buildLabel('Địa chỉ'),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _newAddressController,
                                style: const TextStyle(color: Colors.white),
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(255),
                                ],
                                decoration: InputDecoration(
                                  hintText: 'Số nhà, đường, phường, quận...',
                                  hintStyle: const TextStyle(color: Colors.white54),
                                  filled: true,
                                  fillColor: const Color(0xFF16325B),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                validator: (val) {
                                  if (val != null && val.trim().length > 255) {
                                    return 'Địa chỉ không được vượt quá 255 ký tự';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              const Text('Nhóm khách hàng', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16325B),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF16325B),
                                    value: _selectedGroupId,
                                    hint: const Text('Chọn nhóm (tùy chọn)', style: TextStyle(color: Colors.white54)),
                                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: '',
                                        child: Text('Không có nhóm', style: TextStyle(color: Colors.white)),
                                      ),
                                      ..._groups.map((g) {
                                        return DropdownMenuItem<String>(
                                          value: g['id'].toString(),
                                          child: Text(g['name'] ?? '', style: const TextStyle(color: Colors.white)),
                                        );
                                      }).toList(),
                                    ],
                                    onChanged: (val) {
                                      setModalState(() => _selectedGroupId = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _isSavingCustomer ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            side: const BorderSide(color: Colors.white30),
                          ),
                          child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _isSavingCustomer ? null : () async {
                            if (!formKey.currentState!.validate()) {
                              return;
                            }
                            setModalState(() => _isSavingCustomer = true);
                            try {
                              final repo = ref.read(dealerRepositoryProvider);
                              final payload = <String, dynamic>{
                                'name': _newNameController.text.trim(),
                                'phone': _newPhoneController.text.trim(),
                                'address': _newAddressController.text.trim(),
                              };
                              if (_selectedGroupId != null && _selectedGroupId != '') {
                                payload['groupId'] = _selectedGroupId;
                              } else {
                                payload['groupId'] = null;
                              }

                              if (isEditing) {
                                await repo.updateCustomer(customer['id'].toString(), payload);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật khách hàng'), backgroundColor: Colors.green));
                              } else {
                                await repo.createCustomer(payload);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm khách hàng'), backgroundColor: Colors.green));
                              }
                              
                              if (mounted) {
                                Navigator.pop(context);
                                _fetchCustomers();
                              }
                            } catch (e) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
                            } finally {
                              if (mounted) setModalState(() => _isSavingCustomer = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00875A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isSavingCustomer
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Lưu', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLabel(String text, {bool required = false}) {
    return RichText(
      text: TextSpan(
        children: [
          if (required) const TextSpan(text: '* ', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
          TextSpan(text: text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '--';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  String _formatPhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) return 'N/A';
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.length == 10 && cleaned.startsWith('0')) {
      return '${cleaned.substring(0, 4)} ${cleaned.substring(4, 7)} ${cleaned.substring(7)}';
    }
    return phone;
  }

  Color _hexToColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return Colors.blueAccent;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return Colors.blueAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Quản lý Khách hàng', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Search Bar & Add Button
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E293B),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Tìm tên hoặc SĐT...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 500), () {
                      _fetchCustomers();
                    });
                  },
                  onSubmitted: (_) => _fetchCustomers(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/dealer/customer-groups').then((_) {
                          _fetchGroups();
                          _fetchCustomers();
                        }),
                        icon: const Icon(Icons.group, size: 18),
                        label: const Text('Nhóm KH', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white30),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showCustomerDialog(null),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Thêm mới', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00875A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                    ? const Center(child: Text('Không có dữ liệu', style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _customers.length,
                        itemBuilder: (context, index) {
                          final c = _customers[index];
                          return Card(
                            color: const Color(0xFF1E293B),
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '${index + 1}. ${c['name'] ?? ''}',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          if (c['group'] != null) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: _hexToColor(c['group']['color']?.toString()), borderRadius: BorderRadius.circular(4)),
                                              child: Text(
                                                c['group']['name'] ?? 'Nhóm',
                                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ]
                                        ],
                                      ),
                                      InkWell(
                                        onTap: () => _showCustomerDialog(c),
                                        child: const Text('Sửa', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone, color: Colors.white54, size: 14),
                                      const SizedBox(width: 4),
                                      Text(_formatPhoneNumber(c['phone']), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, color: Colors.white54, size: 14),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text('${c['address'] ?? 'N/A'}', style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ),
                                  const Divider(color: Colors.white12, height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Số lần mua: ${c['totalPurchases'] ?? c['orderCount'] ?? 0}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                      Text('Ngày tạo: ${_formatDate(c['createdAt'])}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
