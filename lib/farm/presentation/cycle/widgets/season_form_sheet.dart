import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:trustid_scan_ai/core/theme/app_colors.dart';
import '../../../data/farm_repository.dart';
import '../../../domain/crop_cycle.dart';
import '../../../domain/location.dart';
import '../../../domain/template.dart';

class SeasonFormSheet extends ConsumerStatefulWidget {
  final CropCycle? cycle;
  final VoidCallback onSaved;

  const SeasonFormSheet({super.key, this.cycle, required this.onSaved});

  @override
  ConsumerState<SeasonFormSheet> createState() => _SeasonFormSheetState();
}

class _SeasonFormSheetState extends ConsumerState<SeasonFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  
  String? _selectedLocationId;
  String? _selectedTemplateId;
  DateTime _startDate = DateTime.now();
  bool _isSubmitting = false;

  List<GrowingLocation> _locations = [];
  List<ProcessTemplate> _templates = [];
  List<Map<String, dynamic>> _products = [];
  List<String> _selectedProductIds = [];
  bool _isLoadingDropdowns = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.cycle?.name ?? '');
    _startDate = widget.cycle?.startDate ?? DateTime.now();
    _selectedLocationId = widget.cycle?.locationId;
    _selectedTemplateId = widget.cycle?.templateId;
    _selectedProductIds = widget.cycle?.productIds.toList() ?? [];

    _fetchDropdowns();
  }

  Future<void> _fetchDropdowns() async {
    try {
      final repo = ref.read(farmRepositoryProvider);
      
      List<GrowingLocation> locs = [];
      try {
        locs = await repo.getLocations();
      } catch (e) {
        debugPrint('Error getLocations: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi tải vùng trồng: $e'), backgroundColor: Colors.red),
          );
        }
      }

      List<ProcessTemplate> tpls = [];
      try {
        tpls = await repo.getTemplates();
      } catch (e) {
        debugPrint('Error getTemplates: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi tải quy trình mẫu: $e'), backgroundColor: Colors.red),
          );
        }
      }
      
      List<Map<String, dynamic>> prods = [];
      try {
        prods = await repo.getFarmProducts();
      } catch (e) {
        debugPrint('Error getFarmProducts: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi tải sản phẩm: $e'), backgroundColor: Colors.red),
          );
        }
      }

      if (mounted) {
        setState(() {
          _locations = locs;
          _templates = tpls;
          _products = prods;
          _isLoadingDropdowns = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDropdowns = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(farmRepositoryProvider);
      final data = {
        'name': _nameController.text.trim(),
        'location_id': _selectedLocationId,
        'template_id': _selectedTemplateId,
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
        'product_ids': _selectedProductIds,
      };

      if (widget.cycle != null) {
        await repo.updateCycle(widget.cycle!.id, data);
        
        final originalProductIds = widget.cycle!.productIds;
        final added = _selectedProductIds.where((id) => !originalProductIds.contains(id)).toList();
        final removed = originalProductIds.where((id) => !_selectedProductIds.contains(id)).toList();

        if (added.isNotEmpty) {
            await repo.addCycleProducts(widget.cycle!.id, added);
        }
        if (removed.isNotEmpty) {
            for (var pid in removed) {
                await repo.removeCycleProduct(widget.cycle!.id, pid);
            }
        }

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật vụ mùa thành công!')));
      } else {
        await repo.startCycle(data);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Khởi tạo vụ mùa thành công!')));
      }

      if (mounted) {
        widget.onSaved();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildRequiredLabel(String text) {
    return RichText(
      text: TextSpan(
        text: '* ',
        style: const TextStyle(color: Colors.red, fontSize: 13),
        children: [
          TextSpan(text: text, style: const TextStyle(color: kTextGray, fontSize: 13)),
        ],
      ),
    );
  }

  void _showProductSelectModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('Chọn sản phẩm dự kiến', style: TextStyle(color: kTextLight, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(color: Colors.white24),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final p = _products[index];
                        final pId = p['id'].toString();
                        final isSelected = _selectedProductIds.contains(pId);
                        return CheckboxListTile(
                          title: Text(p['name']?.toString() ?? '', style: const TextStyle(color: kTextLight)),
                          value: isSelected,
                          activeColor: kPrimaryColor,
                          checkColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                _selectedProductIds.add(pId);
                              } else {
                                _selectedProductIds.remove(pId);
                              }
                            });
                            setState(() {}); // Cập nhật lại UI ở form chính
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Xác nhận', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kBackgroundDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: _isLoadingDropdowns 
            ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
            : Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.cycle != null ? 'Cập nhật Vụ mùa' : 'Khởi tạo Vụ mùa mới',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextLight),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: kTextGray),
                        onPressed: () => Navigator.of(context).pop(),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Tên vụ mùa
                  _buildRequiredLabel('Tên vụ mùa'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: kTextLight),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: kSurfaceDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      hintText: 'VD: Vụ Lúa CT01 2026',
                      hintStyle: const TextStyle(color: kTextGray),
                    ),
                    validator: (v) => v!.isEmpty ? 'Nhập tên vụ mùa' : null,
                  ),
                  const SizedBox(height: 16),

                  // Vùng trồng
                  _buildRequiredLabel('Chọn Vùng trồng'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedLocationId,
                    dropdownColor: kSurfaceDark,
                    style: const TextStyle(color: kTextLight),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: kSurfaceDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    validator: (v) => v == null ? 'Vui lòng chọn vùng trồng' : null,
                    items: _locations.map((loc) => DropdownMenuItem(
                      value: loc.id,
                      child: Text(loc.name, style: const TextStyle(color: kTextLight, overflow: TextOverflow.ellipsis)),
                    )).toList(),
                    onChanged: widget.cycle != null ? null : (val) => setState(() => _selectedLocationId = val),
                    hint: const Text('Chọn vùng trồng', style: TextStyle(color: kTextGray, overflow: TextOverflow.ellipsis)),
                  ),
                  const SizedBox(height: 16),

                  // Quy trình mẫu
                  _buildRequiredLabel('Áp dụng Quy trình mẫu'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedTemplateId,
                    dropdownColor: kSurfaceDark,
                    style: const TextStyle(color: kTextLight),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: kSurfaceDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    validator: (v) => v == null ? 'Vui lòng chọn quy trình mẫu' : null,
                    items: _templates.map((tpl) => DropdownMenuItem(
                      value: tpl.id,
                      child: Text('${tpl.name} (${tpl.product})', style: const TextStyle(color: kTextLight, overflow: TextOverflow.ellipsis)),
                    )).toList(),
                    onChanged: widget.cycle != null ? null : (val) => setState(() => _selectedTemplateId = val),
                    hint: const Text('Chọn quy trình', style: TextStyle(color: kTextGray, overflow: TextOverflow.ellipsis)),
                  ),
                  if (widget.cycle == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text('Hệ thống sẽ tự động sinh các đầu việc hàng ngày dựa trên ngày bắt đầu.', style: TextStyle(color: kTextGray, fontSize: 12, fontStyle: FontStyle.italic)),
                    ),
                  const SizedBox(height: 16),

                  // Ngày bắt đầu
                  _buildRequiredLabel('Ngày bắt đầu (Xuống giống)'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _startDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: kSurfaceDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd/MM/yyyy').format(_startDate), style: const TextStyle(color: kTextLight)),
                          const Icon(Icons.calendar_today, color: kTextGray, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sản phẩm dự kiến
                  const Text('Sản phẩm dự kiến (Có thể chọn nhiều)', style: TextStyle(color: kTextGray, fontSize: 13)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _products.isEmpty ? null : _showProductSelectModal,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: kSurfaceDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _products.isEmpty 
                        ? const Text('Đang tải hoặc chưa có sản phẩm nào', style: TextStyle(color: kTextGray))
                        : Row(
                            children: [
                              Expanded(
                                child: _selectedProductIds.isEmpty 
                                  ? const Text('Chọn sản phẩm...', style: TextStyle(color: kTextGray))
                                  : Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: _selectedProductIds.map((id) {
                                        final prod = _products.firstWhere((p) => p['id'].toString() == id, orElse: () => {});
                                        return Container(
                                          padding: const EdgeInsets.only(left: 8, right: 4, top: 4, bottom: 4),
                                          decoration: BoxDecoration(
                                            color: kPrimaryColor.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(prod['name']?.toString() ?? '', style: const TextStyle(color: kPrimaryColor, fontSize: 12)),
                                              const SizedBox(width: 4),
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedProductIds.remove(id);
                                                  });
                                                },
                                                child: const Padding(
                                                  padding: EdgeInsets.all(2.0),
                                                  child: Icon(Icons.close, color: kPrimaryColor, size: 14),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                              ),
                              const Icon(Icons.expand_more, color: kTextGray, size: 20),
                            ],
                          ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text('Sản phẩm sẽ được gợi ý khi thu hoạch. Có thể thay đổi sau.', style: TextStyle(color: kTextGray, fontSize: 12, fontStyle: FontStyle.italic)),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSubmitting 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(widget.cycle != null ? 'Cập nhật' : 'Bắt đầu ngay', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
