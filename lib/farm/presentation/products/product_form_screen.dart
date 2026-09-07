import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart' hide ImageSource;
import '../../data/farm_repository.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';
import '../../domain/product.dart';

const _kPrimary = Color(0xFF00875A);
const _kSurface = Color(0xFF0F2040);
const _kSurfaceCard = Color(0xFF16325B);
const _kTextLight = Color(0xFFE8EDF3);
const _kTextGray = Color(0xFF94A3B8);

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product;
  final List<dynamic> categories;
  final VoidCallback? onSaved;

  const ProductFormScreen({
    super.key,
    this.product,
    required this.categories,
    this.onSaved,
  });

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isUploadingImage = false;

  late TextEditingController _nameController;
  late TextEditingController _gtinController;
  late TextEditingController _gpcController;
  late TextEditingController _priceController;
  late TextEditingController _netWeightController;
  late TextEditingController _weightUnitController;
  late TextEditingController _packagingController;
  late TextEditingController _expiryController;
  late TextEditingController _shortDescController;
  late TextEditingController _descController;

  String? _selectedCategoryId;
  String _expiryUnit = 'DAY';
  bool _noGtin = false;

  List<Map<String, TextEditingController>> _dynamicAttrs = [];
  List<Map<String, dynamic>> _batchTemplate = [];
  List<String> _images = [];

  final List<Map<String, dynamic>> _supportedIcons = [
    {'label': 'DNA (Sinh học)', 'value': 'Cpu', 'icon': Icons.memory},
    {'label': 'Địa điểm (Sản xuất)', 'value': 'Location', 'icon': Icons.location_on},
    {'label': 'Bảo vệ (Kiểm định)', 'value': 'Shield', 'icon': Icons.security},
    {'label': 'Hộp hàng (Sản phẩm)', 'value': 'Box', 'icon': Icons.inventory_2},
    {'label': 'Biểu đồ (Thống kê)', 'value': 'TrendCharts', 'icon': Icons.show_chart},
    {'label': 'Lịch trình (Thời gian)', 'value': 'Calendar', 'icon': Icons.calendar_today},
    {'label': 'Chứng chỉ (Danh hiệu)', 'value': 'Medal', 'icon': Icons.workspace_premium},
    {'label': 'Tài liệu (Hồ sơ)', 'value': 'Document', 'icon': Icons.description},
  ];

  final ImagePicker _imagePicker = ImagePicker();

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _gtinController = TextEditingController(text: p?.gtinCode ?? '');
    _gpcController = TextEditingController(text: p?.gpcCode ?? '');
    _priceController = TextEditingController(text: p?.price?.toString() ?? '');
    _netWeightController = TextEditingController(text: p?.netWeight ?? '');
    _weightUnitController = TextEditingController(text: p?.weightUnit ?? 'kg');
    _packagingController = TextEditingController(text: p?.defaultPackagingSpec ?? '');
    _expiryController = TextEditingController(text: p?.expiryDuration?.toString() ?? '');
    _shortDescController = TextEditingController(text: p?.shortDescription ?? '');
    _descController = TextEditingController(text: p?.description ?? '');

    _selectedCategoryId = p?.categoryId;
    _expiryUnit = p?.expiryUnit ?? 'DAY';
    if (p != null && (p.gtinCode == null || p.gtinCode!.isEmpty)) {
      _noGtin = true;
    }

    _images = List.from(p?.images ?? []);

    if (p?.attributes != null) {
      p!.attributes!.forEach((key, value) {
        if (key == 'batchTemplate' && value is List) {
          _batchTemplate = value.map((block) {
            return {
              'id': block['id'],
              'title': TextEditingController(text: block['title'] ?? ''),
              'icon': block['icon'] ?? 'Shield',
              'fields': (block['fields'] as List?)?.map((f) => {
                'key': TextEditingController(text: f['key'] ?? '')
              }).toList() ?? [],
            };
          }).toList();
        } else {
          _dynamicAttrs.add({
            'key': TextEditingController(text: key),
            'value': TextEditingController(text: value.toString()),
          });
        }
      });
    }
    if (_dynamicAttrs.isEmpty) {
      _dynamicAttrs.add({'key': TextEditingController(), 'value': TextEditingController()});
    }
  }

  @override
  void dispose() {
    for (var attr in _dynamicAttrs) {
      attr['key']?.dispose();
      attr['value']?.dispose();
    }
    for (var block in _batchTemplate) {
      (block['title'] as TextEditingController?)?.dispose();
      final fields = block['fields'] as List?;
      if (fields != null) {
        for (var f in fields) {
          (f['key'] as TextEditingController?)?.dispose();
        }
      }
    }
    _nameController.dispose();
    _gtinController.dispose();
    _gpcController.dispose();
    _priceController.dispose();
    _netWeightController.dispose();
    _weightUnitController.dispose();
    _packagingController.dispose();
    _expiryController.dispose();
    _shortDescController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(farmRepositoryProvider);

      final attrObject = <String, dynamic>{};
      for (var attr in _dynamicAttrs) {
        final k = attr['key']?.text.trim() ?? '';
        final v = attr['value']?.text.trim() ?? '';
        if (k.isNotEmpty) attrObject[k] = v;
      }

      if (_batchTemplate.isNotEmpty) {
        final cleanTemplate = _batchTemplate.map((block) {
          return {
            'id': block['id'],
            'title': (block['title'] as TextEditingController).text.trim(),
            'icon': block['icon'],
            'fields': (block['fields'] as List).map((f) {
              return {'key': (f['key'] as TextEditingController).text.trim()};
            }).where((f) => f['key']!.isNotEmpty).toList(),
          };
        }).where((block) => (block['title'] as String).isNotEmpty).toList();

        if (cleanTemplate.isNotEmpty) {
          attrObject['batchTemplate'] = cleanTemplate;
        }
      }

      final data = {
        'name': _nameController.text.trim(),
        if (!_noGtin && _gtinController.text.trim().isNotEmpty) 'gtinCode': _gtinController.text.trim(),
        if (_gpcController.text.trim().isNotEmpty) 'gpcCode': _gpcController.text.trim(),
        if (_priceController.text.trim().isNotEmpty) 'price': num.tryParse(_priceController.text.trim()),
        if (_netWeightController.text.trim().isNotEmpty) 'netWeight': num.tryParse(_netWeightController.text.trim()),
        'weightUnit': _weightUnitController.text.trim(),
        if (_packagingController.text.trim().isNotEmpty) 'defaultPackagingSpec': num.tryParse(_packagingController.text.trim()),
        if (_expiryController.text.trim().isNotEmpty) 'expiryDuration': num.tryParse(_expiryController.text.trim()),
        'expiryUnit': _expiryUnit,
        if (_shortDescController.text.trim().isNotEmpty) 'shortDescription': _shortDescController.text.trim(),
        if (_descController.text.trim().isNotEmpty) 'description': _descController.text.trim(),
        if (_selectedCategoryId != null) 'categoryId': _selectedCategoryId,
        if (attrObject.isNotEmpty) 'attributes': attrObject,
        'images': _images,
      };

      if (_isEditing) {
        await repo.updateProduct(widget.product!.id, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cập nhật sản phẩm thành công'), backgroundColor: _kPrimary),
          );
        }
      } else {
        await repo.createProduct(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thêm sản phẩm thành công'), backgroundColor: _kPrimary),
          );
        }
      }

      if (mounted) {
        widget.onSaved?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleanErrorMessage(e)), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
      );
      if (file == null) return;

      setState(() => _isUploadingImage = true);
      final bytes = await file.readAsBytes();
      final repo = ref.read(farmRepositoryProvider);
      final url = await repo.uploadImage(bytes, file.name);
      if (url.isNotEmpty) {
        setState(() => _images.add(url));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã tải ảnh lên thành công'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleanErrorMessage(e)), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  String _getCategoryName(String? id, List<dynamic> list) {
    if (id == null) return '--- Chọn ---';
    for (var c in list) {
      if (c['id'] == id) return c['name'] ?? 'Unknown';
      if (c['children'] != null && c['children'] is List && c['children'].isNotEmpty) {
        final childResult = _getCategoryName(id, c['children']);
        if (childResult != '--- Chọn ---') return childResult;
      }
    }
    return '--- Chọn ---';
  }

  void _showCategoryOverlay(BuildContext buttonContext) {
    final RenderBox renderBox = buttonContext.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        return Stack(
          children: [
            Positioned(
              left: position.dx,
              top: position.dy + size.height + 4,
              width: size.width,
              child: Material(
                elevation: 8,
                color: _kSurfaceCard,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        dense: true,
                        title: const Text('--- Chọn ---', style: TextStyle(color: _kTextLight)),
                        onTap: () {
                          setState(() => _selectedCategoryId = null);
                          Navigator.pop(ctx);
                        },
                      ),
                      ...widget.categories.map((c) => _buildCategoryNode(ctx, c, 0)).toList(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryNode(BuildContext ctx, dynamic category, int level) {
    final hasChildren = category['children'] != null &&
        category['children'] is List &&
        category['children'].isNotEmpty;

    if (hasChildren) {
      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: Colors.blueAccent,
          collapsedIconColor: _kTextGray,
          tilePadding: EdgeInsets.only(left: 16.0 + level * 16.0, right: 16.0),
          title: Text(category['name'] ?? 'Unknown', style: const TextStyle(color: _kTextLight, fontSize: 13)),
          children: (category['children'] as List).map((child) => _buildCategoryNode(ctx, child, level + 1)).toList(),
        ),
      );
    }

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.only(left: 16.0 + level * 16.0, right: 16.0),
      title: Text(category['name'] ?? 'Unknown', style: const TextStyle(color: _kTextLight, fontSize: 13)),
      onTap: () {
        setState(() => _selectedCategoryId = category['id']);
        Navigator.pop(ctx);
      },
    );
  }

  void _addTemplateBlock() {
    setState(() {
      _batchTemplate.add({
        'id': 'block_${DateTime.now().millisecondsSinceEpoch}',
        'title': TextEditingController(),
        'icon': 'Shield',
        'fields': [
          {'key': TextEditingController()}
        ],
      });
    });
  }

  void _removeTemplateBlock(int index) {
    setState(() => _batchTemplate.removeAt(index));
  }

  void _addTemplateField(int blockIndex) {
    setState(() => (_batchTemplate[blockIndex]['fields'] as List).add({'key': TextEditingController()}));
  }

  void _removeTemplateField(int blockIndex, int fieldIndex) {
    setState(() => (_batchTemplate[blockIndex]['fields'] as List).removeAt(fieldIndex));
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kSurfaceCard,
        title: const Text('Chọn nguồn ảnh', style: TextStyle(color: _kTextLight)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blueAccent),
              title: const Text('Chụp ảnh', style: TextStyle(color: _kTextLight)),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blueAccent),
              title: const Text('Thư viện', style: TextStyle(color: _kTextLight)),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(width: 3, height: 16, decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: Colors.blueAccent, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    int maxLines = 1,
    String? suffix,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      style: TextStyle(color: enabled ? _kTextLight : _kTextGray.withOpacity(0.5)),
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _kTextGray, fontSize: 13),
        alignLabelWithHint: maxLines > 1,
        suffixText: suffix,
        suffixStyle: TextStyle(color: _kTextGray.withOpacity(0.5)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _kPrimary),
          borderRadius: BorderRadius.circular(10),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(10),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.redAccent),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.redAccent),
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: enabled ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.02),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kSurfaceCard.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: _kSurfaceCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _kTextLight, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Sửa sản phẩm' : 'Thêm sản phẩm mới',
          style: const TextStyle(color: _kTextLight, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white.withOpacity(0.08)),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Thông tin cơ bản ──
              _buildSectionTitle('Thông tin cơ bản'),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      'Tên sản phẩm *',
                      _nameController,
                      validator: (v) => v!.trim().isEmpty ? 'Không được để trống' : null,
                    ),
                    const SizedBox(height: 14),

                    // Danh mục
                    Builder(
                      builder: (btnCtx) => InkWell(
                        onTap: () => _showCategoryOverlay(btnCtx),
                        borderRadius: BorderRadius.circular(10),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Danh mục',
                            labelStyle: const TextStyle(color: _kTextGray, fontSize: 13),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.04),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _getCategoryName(_selectedCategoryId, widget.categories),
                                  style: TextStyle(color: _selectedCategoryId != null ? _kTextLight : _kTextGray),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: _kTextGray),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // GTIN
                    Row(
                      children: [
                        Checkbox(
                          value: _noGtin,
                          onChanged: (v) => setState(() => _noGtin = v ?? false),
                          fillColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected) ? _kPrimary : Colors.white24,
                          ),
                        ),
                        const Text('Không có mã GTIN', style: TextStyle(color: _kTextGray, fontSize: 13)),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildTextField('Mã GTIN', _gtinController, enabled: !_noGtin),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _buildTextField('GPC Code', _gpcController),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Thông số & Quy cách ──
              _buildSectionTitle('Thông số & Quy cách'),
              _buildCard(
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildTextField('Giá bán (VNĐ)', _priceController, isNumber: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField('Quy cách đóng bao', _packagingController, isNumber: true, suffix: 'gói')),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildTextField('Trọng lượng', _netWeightController, isNumber: true)),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: _buildTextField('Đơn vị KL', _weightUnitController)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildTextField('Hạn sử dụng', _expiryController, isNumber: true)),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _expiryUnit,
                            decoration: InputDecoration(
                              labelText: 'Đơn vị',
                              labelStyle: const TextStyle(color: _kTextGray, fontSize: 13),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: _kPrimary),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.04),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            ),
                            dropdownColor: _kSurfaceCard,
                            style: const TextStyle(color: _kTextLight, fontSize: 14),
                            items: const [
                              DropdownMenuItem(value: 'DAY', child: Text('Ngày')),
                              DropdownMenuItem(value: 'MONTH', child: Text('Tháng')),
                              DropdownMenuItem(value: 'YEAR', child: Text('Năm')),
                            ],
                            onChanged: (val) => setState(() => _expiryUnit = val!),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Mô tả ──
              _buildSectionTitle('Mô tả sản phẩm'),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField('Mô tả ngắn', _shortDescController, maxLines: 3),
                    if (_descController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text('Mô tả chi tiết', style: TextStyle(color: _kTextGray, fontSize: 12)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: HtmlWidget(
                          _descController.text,
                          textStyle: const TextStyle(color: _kTextLight),
                          customStylesBuilder: (element) {
                            if (element.localName == 'a') {
                              return {'color': '#60a5fa', 'text-decoration': 'underline'};
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Thuộc tính bổ sung ──
              _buildSectionTitle('Thuộc tính bổ sung'),
              _buildCard(
                child: Column(
                  children: [
                    ..._dynamicAttrs.asMap().entries.map((entry) {
                      final index = entry.key;
                      final attr = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildTextField('Key', attr['key']!)),
                            const SizedBox(width: 10),
                            Expanded(child: _buildTextField('Value', attr['value']!)),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                                onPressed: () => setState(() => _dynamicAttrs.removeAt(index)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _dynamicAttrs.add(
                            {'key': TextEditingController(), 'value': TextEditingController()})),
                        icon: const Icon(Icons.add, size: 16, color: Colors.blueAccent),
                        label: const Text('Thêm thuộc tính', style: TextStyle(color: Colors.blueAccent)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.blueAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Mẫu khung lô sản xuất ──
              Row(
                children: [
                  const Icon(Icons.link, color: Colors.blueAccent, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Mẫu khung thuộc tính lô sản xuất',
                      style: TextStyle(color: Colors.blueAccent, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addTemplateBlock,
                    icon: const Icon(Icons.add, size: 16, color: Colors.blueAccent),
                    label: const Text('Thêm Khối', style: TextStyle(color: Colors.blueAccent, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_batchTemplate.isEmpty)
                _buildCard(
                  child: const Center(
                    child: Text(
                      'Chưa cấu hình mẫu khối nào. Lô hàng sẽ dùng thuộc tính phẳng mặc định.',
                      style: TextStyle(color: _kTextGray, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ..._batchTemplate.asMap().entries.map((blockEntry) {
                  final bIndex = blockEntry.key;
                  final block = blockEntry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kSurfaceCard,
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: _buildTextField('Tên khối (VD: Dữ liệu Kiểm định)', block['title']),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                value: block['icon'],
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Biểu tượng',
                                  labelStyle: const TextStyle(color: _kTextGray, fontSize: 12),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: Colors.blueAccent),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.04),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                                ),
                                dropdownColor: _kSurfaceCard,
                                style: const TextStyle(color: _kTextLight, fontSize: 13),
                                items: _supportedIcons.map((ico) => DropdownMenuItem<String>(
                                  value: ico['value'],
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(ico['icon'] as IconData, size: 16, color: _kTextGray),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          ico['label'] as String,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                )).toList(),
                                onChanged: (val) => setState(() => block['icon'] = val!),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                                onPressed: () => _removeTemplateBlock(bIndex),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.only(left: 12),
                          decoration: const BoxDecoration(
                            border: Border(left: BorderSide(color: Colors.blueAccent, width: 2)),
                          ),
                          child: Column(
                            children: [
                              ...(block['fields'] as List).asMap().entries.map((fieldEntry) {
                                final fIndex = fieldEntry.key;
                                final field = fieldEntry.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _buildTextField('Tên trường (VD: Tỷ lệ nảy mầm)', field['key']),
                                      ),
                                      const SizedBox(width: 4),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                                          onPressed: () => _removeTemplateField(bIndex, fIndex),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton.icon(
                                  onPressed: () => _addTemplateField(bIndex),
                                  icon: const Icon(Icons.add, size: 16, color: Colors.blueAccent),
                                  label: const Text('Thêm trường dữ liệu', style: TextStyle(color: Colors.blueAccent)),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.blueAccent.withOpacity(0.08),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 20),

              // ── Hình ảnh sản phẩm ──
              _buildSectionTitle('Hình ảnh sản phẩm'),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ..._images.asMap().entries.map((entry) {
                          final index = entry.key;
                          final img = entry.value;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white24),
                                  borderRadius: BorderRadius.circular(10),
                                  image: DecorationImage(
                                    image: NetworkImage(
                                      img.startsWith('http') ? img : 'https://api.trustid.com.vn$img',
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: -5,
                                top: -5,
                                child: GestureDetector(
                                  onTap: () => setState(() => _images.removeAt(index)),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, size: 13, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                        InkWell(
                          onTap: _isUploadingImage ? null : _showImageSourceDialog,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white24, style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white.withOpacity(0.04),
                            ),
                            child: _isUploadingImage
                                ? const Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 2),
                                    ),
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate_outlined, color: _kTextGray, size: 28),
                                      SizedBox(height: 4),
                                      Text('Thêm ảnh', style: TextStyle(color: _kTextGray, fontSize: 11)),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
          color: _kSurfaceCard,
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kTextGray,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Hủy bỏ', style: TextStyle(fontSize: 15)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _save,
                icon: _isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(_isEditing ? Icons.save_outlined : Icons.add_circle_outline, size: 18),
                label: Text(
                  _isEditing ? 'Lưu thay đổi' : 'Tạo sản phẩm mới',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _kPrimary.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
