import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/supply/data/dealer_providers.dart';
import 'package:trustid_scan_ai/supply/data/dealer_repository.dart';

class DealerCustomerGroupsScreen extends ConsumerStatefulWidget {
  const DealerCustomerGroupsScreen({super.key});

  @override
  ConsumerState<DealerCustomerGroupsScreen> createState() => _DealerCustomerGroupsScreenState();
}

class _DealerCustomerGroupsScreenState extends ConsumerState<DealerCustomerGroupsScreen> {
  List<dynamic> _groups = [];
  bool _isLoading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  bool _isSaving = false;
  String _selectedColor = '#1e88e5'; // Default blue

  final List<String> _colorOptions = [
    '#1e88e5', '#43a047', '#fb8c00', '#e53935', '#8e24aa', '#ffb300', '#00acc1', '#546e7a'
  ];

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(dealerRepositoryProvider);
      final data = await repo.getCustomerGroups();
      if (mounted) setState(() => _groups = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  void _showGroupDialog(dynamic group) {
    final isEditing = group != null;
    _nameController.text = isEditing ? (group['name'] ?? '') : '';
    _descController.text = isEditing ? (group['description'] ?? '') : '';
    _discountController.text = isEditing ? (group['discountPercent']?.toString() ?? '0') : '0';
    _selectedColor = isEditing ? (group['color'] ?? '#1e88e5') : '#1e88e5';

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isEditing ? 'Sửa Nhóm KH' : 'Thêm Nhóm KH', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        IconButton(icon: const Icon(Icons.close, color: Colors.redAccent), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      'Tên nhóm', 
                      _nameController, 
                      hint: 'VD: Khách VIP, Đại lý cấp 2...', 
                      required: true,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(255),
                      ],
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập tên nhóm';
                        }
                        if (val.trim().length > 255) {
                          return 'Tên nhóm không được vượt quá 255 ký tự';
                        }
                        
                        // Check duplicate group name in local list
                        final inputName = val.trim().toLowerCase();
                        final isDuplicate = _groups.any((g) {
                          if (isEditing && g['id'].toString() == group['id'].toString()) {
                            return false;
                          }
                          return (g['name'] ?? '').toString().trim().toLowerCase() == inputName;
                        });
                        
                        if (isDuplicate) {
                          return 'Tên nhóm đã tồn tại';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Mô tả', 
                      _descController, 
                      hint: 'Mô tả ngắn về nhóm...', 
                      maxLines: 3,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(255),
                      ],
                      validator: (val) {
                        if (val != null && val.trim().length > 255) {
                          return 'Mô tả không được vượt quá 255 ký tự';
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 16),
                  _buildLabel('Chiết khấu mặc định (%)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _discountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
                    ],
                    decoration: InputDecoration(
                      hintText: '0.0',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF16325B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      prefixIcon: IconButton(
                        icon: const Icon(Icons.remove, size: 20, color: Colors.white54),
                        onPressed: () {
                          double current = double.tryParse(_discountController.text) ?? 0.0;
                          if (current > 0) {
                            _discountController.text = (current - 1).toStringAsFixed(1);
                          }
                        },
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add, size: 20, color: Colors.white54),
                        onPressed: () {
                          double current = double.tryParse(_discountController.text) ?? 0.0;
                          if (current < 100) {
                            _discountController.text = (current + 1).toStringAsFixed(1);
                          }
                        },
                      ),
                    ),
                    textAlign: TextAlign.center,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return null; // Mặc định là 0% khi lưu nếu trống
                      }
                      final number = double.tryParse(val.trim());
                      if (number == null) {
                        return 'Giá trị không hợp lệ';
                      }
                      if (number < 0 || number > 100) {
                        return 'Chiết khấu phải từ 0% đến 100%';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Màu nhãn'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _colorOptions.map((colorHex) {
                      final isSelected = _selectedColor == colorHex;
                      return GestureDetector(
                        onTap: () => setDialogState(() => _selectedColor = colorHex),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _hexToColor(colorHex),
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _isSaving ? null : () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: const BorderSide(color: Colors.white30),
                        ),
                        child: const Text('Hủy', style: TextStyle(color: Colors.white70)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSaving ? null : () {
                          if (formKey.currentState!.validate()) {
                            _saveGroup(group, ctx);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Lưu'),
                      ),
                    ],
                  ),
                ],
              ),
              ),
            ),
          );
        }
      ),
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

  Widget _buildTextField(
    String label, 
    TextEditingController controller, 
    {
      String? hint, 
      bool required = false, 
      int maxLines = 1,
      List<TextInputFormatter>? inputFormatters,
      String? Function(String?)? validator,
    }
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, required: required),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: const Color(0xFF16325B),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Future<void> _saveGroup(dynamic group, BuildContext dialogContext) async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(dealerRepositoryProvider);
      final data = {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'discountPercent': double.tryParse(_discountController.text.trim()) ?? 0.0,
        'color': _selectedColor,
      };

      if (group != null) {
        await repo.updateCustomerGroup(group['id'].toString(), data);
      } else {
        await repo.createCustomerGroup(data);
      }
      
      if (mounted) {
        Navigator.pop(dialogContext);
        _fetchGroups();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi lưu: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteGroup(dynamic group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Xác nhận xóa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx, false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Xóa nhóm "${group['name']}"? Tất cả KH thuộc nhóm này sẽ trở về không có nhóm.',
                      style: const TextStyle(fontSize: 15, color: Colors.white70),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      side: const BorderSide(color: Colors.white30),
                    ),
                    child: const Text('Hủy', style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00875A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Xóa', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(dealerRepositoryProvider);
      await repo.deleteCustomerGroup(group['id'].toString());
      _fetchGroups();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi xóa: $e'), backgroundColor: Colors.red));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Nhóm Khách Hàng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.people_outline, size: 16),
                    label: const Text('Quản lý KH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                    onPressed: () => _showGroupDialog(null),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Thêm nhóm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _groups.isEmpty
                    ? const Center(child: Text('Không có nhóm khách hàng', style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groups.length,
                  itemBuilder: (context, index) {
                    final group = _groups[index];
                    return Card(
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _hexToColor(group['color'] ?? '#1e88e5'),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        group['name'] ?? '',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF16325B),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${group['customerCount'] ?? 0} KH',
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Chiết khấu: ${group['discountPercent'] ?? 0}%',
                                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            if (group['description'] != null && group['description'].toString().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                group['description'],
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                            const Divider(color: Colors.white12, height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                InkWell(
                                  onTap: () => _showGroupDialog(group),
                                  child: const Text('Sửa', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                                ),
                                const SizedBox(width: 24),
                                InkWell(
                                  onTap: () => context.push('/dealer/pricing'),
                                  child: const Text('Bảng giá', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                                ),
                                const SizedBox(width: 24),
                                InkWell(
                                  onTap: () => _deleteGroup(group),
                                  child: const Text('Xóa', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                                ),
                              ],
                            ),
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
