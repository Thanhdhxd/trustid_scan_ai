import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/material.dart';
import '../../../data/farm_repository.dart';

class MaterialFormDialog extends ConsumerStatefulWidget {
  final FarmMaterial? material;
  final VoidCallback onSaved;

  const MaterialFormDialog({super.key, this.material, required this.onSaved});

  @override
  ConsumerState<MaterialFormDialog> createState() => _MaterialFormDialogState();
}

class _MaterialFormDialogState extends ConsumerState<MaterialFormDialog> {
  static const Color kPrimaryColor = Color(0xFF00875A);
  static const Color kBackgroundDark = Color(0xFF0F2B46);
  static const Color kSurfaceDark = Color(0xFF16325B);
  static const Color kTextLight = Color(0xFFE8EDF3);
  static const Color kTextGray = Color(0xFF94A3B8);

  final _formKey = GlobalKey<FormState>();
  late String _type;
  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _unitCtrl;
  late TextEditingController _descCtrl;
  late bool _isActive;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final m = widget.material;
    _type = m?.type ?? 'FERTILIZER';
    _codeCtrl = TextEditingController(text: m?.code ?? '');
    _nameCtrl = TextEditingController(text: m?.name ?? '');
    _unitCtrl = TextEditingController(text: m?.unit ?? 'kg');
    _descCtrl = TextEditingController(text: m?.description ?? '');
    _isActive = m?.isActive ?? true;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final data = {
        'code': _codeCtrl.text,
        'name': _nameCtrl.text,
        'type': _type,
        'unit': _unitCtrl.text,
        'description': _descCtrl.text,
        'isActive': _isActive,
      };

      if (widget.material == null) {
        await ref.read(farmRepositoryProvider).createMaterial(data);
      } else {
        await ref.read(farmRepositoryProvider).updateMaterial(widget.material!.id, data);
      }

      if (mounted) {
        final actionText = widget.material == null ? 'Thêm mới' : 'Cập nhật';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$actionText vật tư thành công'),
          backgroundColor: kPrimaryColor,
          duration: const Duration(seconds: 2),
        ));
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  void _generateCode() {
    final prefix = _type == 'FERTILIZER' ? 'PB' : _type == 'SEED' ? 'G1' : 'TB';
    final randomId = DateTime.now().millisecondsSinceEpoch.toString().substring(9);
    _codeCtrl.text = '$prefix-$randomId';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: kBackgroundDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: kSurfaceDark,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory, color: kPrimaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.material == null ? 'Thêm Vật tư mới' : 'Cập nhật Vật tư',
                      style: const TextStyle(color: kTextLight, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: kTextGray, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildDropdownField('Loại *', _type, [
                              {'val': 'FERTILIZER', 'label': 'Phân bón'},
                              {'val': 'SEED', 'label': 'Giống'},
                              {'val': 'PESTICIDE', 'label': 'Thuốc BVTV'},
                              {'val': 'OTHER', 'label': 'Khác'},
                            ], (val) => setState(() => _type = val!)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField('Mã vật tư', _codeCtrl, hint: 'Auto-generated', suffixIcon: Icons.autorenew, onSuffixTap: _generateCode),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField('Tên vật tư *', _nameCtrl, hint: 'VD: Phân bón hữu cơ...', validator: (val) => (val == null || val.trim().isEmpty) ? 'Vui lòng nhập tên' : null),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTextField('Đơn vị tính *', _unitCtrl, hint: 'kg, lít, bao...', validator: (val) => (val == null || val.trim().isEmpty) ? 'Vui lòng nhập đơn vị' : null),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Trạng thái', style: TextStyle(color: kTextGray, fontSize: 13, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 8),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    children: [
                                      Text('Ngừng\ndùng', textAlign: TextAlign.right, style: TextStyle(color: _isActive ? kTextGray : Colors.orange, fontSize: 13)),
                                      Switch(
                                        value: _isActive,
                                        onChanged: (val) => setState(() => _isActive = val),
                                        activeColor: kPrimaryColor,
                                      ),
                                      Text('Đang\ndùng', textAlign: TextAlign.left, style: TextStyle(color: _isActive ? kPrimaryColor : kTextGray, fontSize: 13, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField('Mô tả', _descCtrl, hint: 'Nhập ghi chú...', maxLines: 3),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.white.withOpacity(0.1))),
                    ),
                    child: const Text('Hủy', style: TextStyle(color: kTextLight)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(widget.material == null ? 'Tạo mới' : 'Cập nhật', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequiredLabel(String text) {
    if (text.endsWith('*')) {
      final baseText = text.substring(0, text.length - 1).trim();
      return RichText(
        text: TextSpan(
          text: '* ',
          style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
          children: [
            TextSpan(text: baseText, style: const TextStyle(color: kTextGray, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }
    return Text(text, style: const TextStyle(color: kTextGray, fontSize: 13, fontWeight: FontWeight.w500));
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? hint, int maxLines = 1, IconData? suffixIcon, VoidCallback? onSuffixTap, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRequiredLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: kTextLight, fontSize: 14),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: kTextGray.withOpacity(0.5), fontSize: 14),
            filled: true,
            fillColor: Colors.black.withOpacity(0.2),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kPrimaryColor)),
            suffixIcon: suffixIcon != null ? IconButton(icon: Icon(suffixIcon, color: kTextGray), onPressed: onSuffixTap) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String value, List<Map<String, String>> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRequiredLabel(label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: kSurfaceDark,
              icon: const Icon(Icons.keyboard_arrow_down, color: kTextGray),
              style: const TextStyle(color: kTextLight, fontSize: 14),
              items: items.map((item) => DropdownMenuItem<String>(value: item['val'], child: Text(item['label']!))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
