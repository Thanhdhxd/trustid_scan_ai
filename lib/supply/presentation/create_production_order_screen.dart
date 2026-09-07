import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import '../data/supply_repository.dart';

const Color _kPrimary = Color(0xFF00875A);
const Color _kPrimaryLight = Color(0xFF36B37E);
const Color _kBg = Color(0xFF0F2B46);
const Color _kSurface = Color(0xFF16325B);
const Color _kFieldBg = Color(0xFF0F2B46);
const Color _kCardBorder = Color(0x1FFFFFFF);
const Color _kText = Color(0xFFFFFFFF);
const Color _kTextSub = Color(0xFFE2E8F0);
const Color _kTextGray = Color(0xFF94A3B8);

class CreateProductionOrderScreen extends ConsumerStatefulWidget {
  const CreateProductionOrderScreen({super.key});

  @override
  ConsumerState<CreateProductionOrderScreen> createState() => _CreateProductionOrderScreenState();
}

class _CreateProductionOrderScreenState extends ConsumerState<CreateProductionOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _submitting = false;
  String? _error;

  // Master Data
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _harvestList = [];
  List<Map<String, dynamic>> _allSourceBatches = [];

  // Form State
  String? _selectedProductId;
  DateTime _plannedDate = DateTime.now();

  // Quy cách sản phẩm
  double _unitWeightKg = 1.0;
  double _packagingSpec = 40.0;

  // Checkboxes & Source Type
  bool _isBagOrder = true; // Đóng bao: Có
  bool _useExternalSource = false; // Nguyên liệu ngoài farm
  String _sourceType = 'EXTERNAL'; // 'EXTERNAL' | 'CROSS_TENANT'

  // Selected Lots
  String? _selectedFarmBatchCode;
  String? _selectedSourceBatchId;

  // Khối lượng kế hoạch & Đơn vị (kg, Yến, Tạ, Tấn)
  final _plannedWeightCtrl = TextEditingController(text: '0.0');
  String _plannedWeightUnit = 'KG'; // 'KG', 'YEN', 'TA', 'TON'

  // Thông số sản xuất
  int _sparePacketQuantity = 0;
  int _spareBagQuantity = 0;

  // Serial & Ghi chú
  final _serialPrefixCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _plannedWeightCtrl.dispose();
    _serialPrefixCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double _getUnitMultiplier(String unit) {
    switch (unit) {
      case 'TON':
        return 1000.0;
      case 'TA':
        return 100.0;
      case 'YEN':
        return 10.0;
      default:
        return 1.0;
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(supplyRepositoryProvider);
      final results = await Future.wait([
        repo.getProducts(),
        repo.getBatches(),
        repo.getExternalBatches(),
      ]);

      if (!mounted) return;

      final products = (results[0] as List).map((p) => Map<String, dynamic>.from(p)).toList();
      final allBatches = (results[1] as List).map((b) => Map<String, dynamic>.from(b)).toList();
      final extBatches = (results[2] as List).map((b) => Map<String, dynamic>.from(b)).toList();

      final harvests = allBatches.where((b) {
        final type = (b['batchType'] ?? b['batch_type'] ?? '').toString().toUpperCase();
        final code = (b['batchCode'] ?? b['batch_code'] ?? '').toString();
        return (type == 'FARM' || type == 'HARVEST') && !code.startsWith('PKG-');
      }).toList();

      setState(() {
        _products = products;
        _harvestList = harvests;
        _allSourceBatches = extBatches;
        _selectedProductId = null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Lỗi tải dữ liệu: $e';
        });
      }
    }
  }

  Map<String, dynamic>? get _selectedProduct {
    if (_selectedProductId == null) return null;
    return _products.firstWhere(
      (p) => p['id']?.toString() == _selectedProductId,
      orElse: () => <String, dynamic>{},
    );
  }

  void _onProductChanged(String? productId) {
    setState(() {
      _selectedProductId = productId;
      _selectedFarmBatchCode = null;
      _selectedSourceBatchId = null;
      _plannedWeightCtrl.text = '0.0';
      _sparePacketQuantity = 0;
      _spareBagQuantity = 0;

      if (productId != null) {
        final p = _products.firstWhere((item) => item['id']?.toString() == productId, orElse: () => {});
        if (p.isNotEmpty) {
          if (p['netWeight'] != null && (double.tryParse(p['netWeight'].toString()) ?? 0) > 0) {
            double w = double.parse(p['netWeight'].toString());
            final unit = (p['weightUnit'] ?? 'kg').toString().toLowerCase();
            if (unit == 'g' || unit == 'ml') w /= 1000;
            _unitWeightKg = w;
          } else {
            _unitWeightKg = 1.0;
          }

          if (p['defaultPackagingSpec'] != null && (double.tryParse(p['defaultPackagingSpec'].toString()) ?? 0) > 0) {
            _packagingSpec = double.parse(p['defaultPackagingSpec'].toString());
          } else {
            _packagingSpec = 40.0;
          }
        }
      }
    });
  }

  List<Map<String, dynamic>> get _filteredHarvests {
    if (_selectedProductId == null) return _harvestList;
    final prodId = _selectedProductId!;
    final prodName = (_selectedProduct?['name'] ?? '').toString().toLowerCase();

    return _harvestList.where((h) {
      final hProdId = (h['productId'] ?? h['product_id'] ?? h['product']?['id'])?.toString();
      if (hProdId != null && hProdId == prodId) return true;

      final plantType = (h['cropCycle']?['location']?['plantType'] ?? h['productName'] ?? h['product']?['name'] ?? '').toString().toLowerCase();
      if (plantType.isNotEmpty && prodName.isNotEmpty) {
        return prodName.contains(plantType) || plantType.contains(prodName);
      }
      return false;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredSourceBatches {
    if (_selectedProductId == null) {
      return _allSourceBatches.where((b) {
        final bType = (b['batchType'] ?? b['batch_type'] ?? '').toString().toUpperCase();
        if (_sourceType == 'CROSS_TENANT') {
          return bType == 'CROSS_TENANT' || bType == 'SEMI_FINISHED';
        }
        return bType == 'EXTERNAL';
      }).toList();
    }

    final prodId = _selectedProductId!;
    return _allSourceBatches.where((b) {
      final bType = (b['batchType'] ?? b['batch_type'] ?? '').toString().toUpperCase();

      if (_sourceType == 'CROSS_TENANT') {
        return bType == 'CROSS_TENANT' || bType == 'SEMI_FINISHED';
      }

      final bProdId = (b['productId'] ?? b['product_id'] ?? b['product']?['id'])?.toString();
      final isProductMatch = bProdId == prodId;
      if (!isProductMatch) return false;

      return bType == 'EXTERNAL';
    }).toList();
  }

  Map<String, dynamic>? get _selectedHarvestLotData {
    if (_selectedFarmBatchCode == null) return null;
    return _filteredHarvests.firstWhere(
      (item) => (item['batchCode'] ?? item['batch_code']) == _selectedFarmBatchCode,
      orElse: () => <String, dynamic>{},
    );
  }

  Map<String, dynamic>? get _selectedSourceLotData {
    if (_selectedSourceBatchId == null) return null;
    return _filteredSourceBatches.firstWhere(
      (item) => item['id']?.toString() == _selectedSourceBatchId,
      orElse: () => <String, dynamic>{},
    );
  }

  void _onHarvestLotSelected(String? batchCode) {
    setState(() {
      _selectedFarmBatchCode = batchCode;
      if (batchCode != null) {
        final h = _filteredHarvests.firstWhere(
          (item) => (item['batchCode'] ?? item['batch_code']) == batchCode,
          orElse: () => {},
        );
        if (h.isNotEmpty) {
          if (_selectedProductId == null) {
            final hProdId = (h['productId'] ?? h['product_id'] ?? h['product']?['id'])?.toString();
            if (hProdId != null) {
              _onProductChanged(hProdId);
              _selectedFarmBatchCode = batchCode;
            }
          }

          final remainingKg = double.tryParse((h['remainingQuantityKg'] ?? h['quantityKg'] ?? h['totalQuantity'] ?? 0).toString()) ?? 0.0;
          final mult = _getUnitMultiplier(_plannedWeightUnit);
          _plannedWeightCtrl.text = (remainingKg / mult).toStringAsFixed(1);
          _autoCalculateSpares();
        }
      } else {
        _plannedWeightCtrl.text = '0.0';
        _sparePacketQuantity = 0;
        _spareBagQuantity = 0;
      }
    });
  }

  void _onSourceLotSelected(String? batchId) {
    setState(() {
      _selectedSourceBatchId = batchId;
      if (batchId != null) {
        final b = _filteredSourceBatches.firstWhere(
          (item) => item['id']?.toString() == batchId,
          orElse: () => {},
        );
        if (b.isNotEmpty) {
          if (_selectedProductId == null) {
            final bProdId = (b['productId'] ?? b['product_id'] ?? b['product']?['id'])?.toString();
            if (bProdId != null) {
              _onProductChanged(bProdId);
              _selectedSourceBatchId = batchId;
            }
          }

          final remainingKg = double.tryParse((b['totalQuantity'] ?? b['totalUnitsExpected'] ?? b['quantity'] ?? 0).toString()) ?? 0.0;
          final mult = _getUnitMultiplier(_plannedWeightUnit);
          _plannedWeightCtrl.text = (remainingKg / mult).toStringAsFixed(1);
          _autoCalculateSpares();
        }
      } else {
        _plannedWeightCtrl.text = '0.0';
        _sparePacketQuantity = 0;
        _spareBagQuantity = 0;
      }
    });
  }

  void _autoCalculateSpares() {
    final units = _estimatedUnits;
    final bags = _estimatedBags;
    if (units > 0) {
      _sparePacketQuantity = (units * 0.1).ceil();
    } else {
      _sparePacketQuantity = 0;
    }
    if (bags > 0 && _isBagOrder) {
      _spareBagQuantity = (bags * 0.1).ceil();
    } else {
      _spareBagQuantity = 0;
    }
  }

  double get _plannedWeightRaw => double.tryParse(_plannedWeightCtrl.text.trim()) ?? 0.0;
  double get _plannedWeightKg => _plannedWeightRaw * _getUnitMultiplier(_plannedWeightUnit);

  int get _estimatedUnits {
    if (_selectedProductId == null || _plannedWeightKg <= 0 || _unitWeightKg <= 0) return 0;
    return (_plannedWeightKg / _unitWeightKg).ceil();
  }

  int get _estimatedBags {
    if (!_isBagOrder || _selectedProductId == null || _packagingSpec <= 0 || _estimatedUnits <= 0) return 0;
    return (_estimatedUnits / _packagingSpec).ceil();
  }

  String get _serialPreview {
    final prefix = _serialPrefixCtrl.text.trim().isNotEmpty ? _serialPrefixCtrl.text.trim().toUpperCase() : 'BKG';
    final year = DateTime.now().year.toString().substring(2);
    return '$prefix-$year-00001';
  }

  void _openLotPicker() {
    final isFarm = !_useExternalSource;
    final title = isFarm
        ? 'Chọn Lô Thu Hoạch Nông Trại'
        : (_sourceType == 'CROSS_TENANT' ? 'Chọn Lô Nhận B2B (Cross-Tenant)' : 'Chọn Lô Nguyên Liệu Nhập Ngoài');

    final items = isFarm ? _filteredHarvests : _filteredSourceBatches;
    final selectedKey = isFarm ? _selectedFarmBatchCode : _selectedSourceBatchId;

    showModalBottomSheet(
      context: context,
      backgroundColor: _kBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedProductId != null
                                ? 'Sản phẩm: ${_selectedProduct?['name'] ?? ''} (${items.length} lô)'
                                : 'Tất cả lô khả dụng (${items.length} lô)',
                            style: const TextStyle(color: _kTextGray, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: _kTextGray),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: _kCardBorder, height: 20),

                if (items.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.inbox_outlined, size: 48, color: _kTextGray),
                          const SizedBox(height: 12),
                          Text(
                            isFarm
                                ? 'Không có lô thu hoạch nông trại phù hợp'
                                : 'Không có lô nguyên liệu ngoài phù hợp',
                            style: const TextStyle(color: _kTextGray, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final lot = items[idx];
                        final code = (lot['batchCode'] ?? lot['batch_code'] ?? lot['code'] ?? 'Lô không tên').toString();
                        final id = lot['id']?.toString() ?? '';
                        final isSelected = isFarm ? (code == selectedKey) : (id == selectedKey);

                        final pName = lot['cropCycle']?['location']?['plantType'] ??
                            lot['productName'] ??
                            lot['product']?['name'] ??
                            lot['name'] ??
                            'Nguyên liệu';

                        final double remainingKg = isFarm
                            ? (double.tryParse((lot['remainingQuantityKg'] ?? lot['quantityKg'] ?? lot['totalQuantity'] ?? 0).toString()) ?? 0.0)
                            : (double.tryParse((lot['totalQuantity'] ?? lot['totalUnitsExpected'] ?? lot['quantity'] ?? 0).toString()) ?? 0.0);

                        final dateStr = lot['harvestDate'] ?? lot['createdAt'] ?? lot['created_at'];
                        String formattedDate = '';
                        if (dateStr != null) {
                          try {
                            final d = DateTime.parse(dateStr.toString());
                            formattedDate = DateFormat('dd/MM/yyyy').format(d);
                          } catch (_) {}
                        }

                        return InkWell(
                          onTap: () {
                            if (isFarm) {
                              _onHarvestLotSelected(code);
                            } else {
                              _onSourceLotSelected(id);
                            }
                            Navigator.pop(ctx);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? _kPrimary.withOpacity(0.15) : _kSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? _kPrimaryLight : Colors.white.withOpacity(0.08),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isSelected ? _kPrimary.withOpacity(0.3) : _kFieldBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isFarm ? Icons.agriculture_rounded : Icons.local_shipping_rounded,
                                    color: isSelected ? _kPrimaryLight : Colors.white70,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        code,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        formattedDate.isNotEmpty ? '$pName • Ngày: $formattedDate' : pName,
                                        style: const TextStyle(color: _kTextGray, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F3B5C),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.lightBlueAccent.withOpacity(0.4)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Còn lại',
                                        style: TextStyle(color: _kTextGray, fontSize: 10, fontWeight: FontWeight.w500),
                                      ),
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: remainingKg.toStringAsFixed(remainingKg.truncateToDouble() == remainingKg ? 0 : 1),
                                              style: const TextStyle(
                                                color: Colors.greenAccent,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const TextSpan(
                                              text: ' kg',
                                              style: TextStyle(color: Colors.white70, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.check_circle_rounded, color: _kPrimaryLight, size: 20),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductId == null) {
      _showToast('Vui lòng chọn sản phẩm thành phẩm!', isError: true);
      return;
    }

    final isFarm = !_useExternalSource;
    if (isFarm && (_selectedFarmBatchCode == null || _selectedFarmBatchCode!.isEmpty)) {
      _showToast('Vui lòng chọn Lô thu hoạch của nông trại!', isError: true);
      return;
    }

    if (!isFarm && (_selectedSourceBatchId == null || _selectedSourceBatchId!.isEmpty)) {
      _showToast('Vui lòng chọn Lô nguyên liệu nhập ngoài / B2B!', isError: true);
      return;
    }

    if (_plannedWeightKg <= 0) {
      _showToast('Khối lượng kế hoạch phải lớn hơn 0 kg!', isError: true);
      return;
    }

    setState(() => _submitting = true);

    try {
      final repo = ref.read(supplyRepositoryProvider);

      final payload = <String, dynamic>{
        'product_id': _selectedProductId,
        'source_type': isFarm ? 'FARM' : _sourceType,
        'planned_weight': _plannedWeightRaw,
        'planned_weight_unit': _plannedWeightUnit,
        'planned_weight_kg': _plannedWeightKg,
        'unit_weight_kg': _unitWeightKg,
        'planned_date': DateFormat('yyyy-MM-dd').format(_plannedDate),
        'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      };

      if (isFarm) {
        payload['farm_batch_code'] = _selectedFarmBatchCode;
      } else {
        payload['source_batch_id'] = _selectedSourceBatchId;
      }

      if (_isBagOrder) {
        payload['packaging_spec'] = _packagingSpec;
        payload['spare_packet_quantity'] = _sparePacketQuantity;
        payload['spare_bag_quantity'] = _spareBagQuantity;
        if (_serialPrefixCtrl.text.trim().isNotEmpty) {
          payload['serial_prefix'] = _serialPrefixCtrl.text.trim().toUpperCase();
        }

        await repo.createBagOrder(payload);
      } else {
        await repo.createProductionOrder(payload);
      }

      if (mounted) {
        setState(() => _submitting = false);
        _showToast('Tạo Lệnh Sản Xuất thành công!', isSuccess: true);
        context.pushReplacement('/manager/orders-bag-linking');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _showToast('Lỗi khi tạo Lệnh Sản Xuất: $e', isError: true);
      }
    }
  }

  void _showToast(String msg, {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: isError ? Colors.redAccent : (isSuccess ? _kPrimary : const Color(0xFF1E4976)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: isRequired ? '* ' : '',
          style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13, fontWeight: FontWeight.bold),
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(color: _kTextSub, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.normal),
      isDense: true,
      filled: true,
      fillColor: _kFieldBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kCardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kCardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kPrimary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nowStr = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final user = ref.watch(authControllerProvider).value;
    final userName = user?.fullName ?? 'Quản lý';

    final isFarm = !_useExternalSource;
    final selectedLot = isFarm ? _selectedHarvestLotData : _selectedSourceLotData;
    final hasSelectedLot = isFarm ? (_selectedFarmBatchCode != null) : (_selectedSourceBatchId != null);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tạo Lệnh Sản Xuất Mới',
              style: TextStyle(color: _kText, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              'Người tạo: $userName • Ngày: $nowStr',
              style: const TextStyle(color: _kTextGray, fontSize: 12),
            ),
          ],
        ),
        backgroundColor: _kBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kTextGray),
        actions: [
          IconButton(
            onPressed: () => context.push('/manager/orders-bag-linking'),
            icon: const Icon(Icons.list_alt_rounded, color: _kTextGray),
            tooltip: 'Danh sách lệnh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : RefreshIndicator(
              onRefresh: _loadInitialData,
              color: _kPrimary,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                            ],
                          ),
                        ),
                      ],

                      // ==================== KHỐI 1: THÔNG TIN SẢN PHẨM & LÔ KẾ HOẠCH ====================
                      _buildSectionCard(
                        title: '1. Thông Tin Sản Phẩm & Lô Kế Hoạch',
                        icon: Icons.inventory_2_outlined,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Sản phẩm thành phẩm', isRequired: true),
                            DropdownButtonFormField<String>(
                              value: _selectedProductId,
                              dropdownColor: _kSurface,
                              icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white),
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              decoration: _inputDeco('Chọn sản phẩm đóng gói...'),
                              hint: const Text(
                                'Chọn sản phẩm đóng gói...',
                                style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.normal),
                              ),
                              isExpanded: true,
                              items: _products.map((p) {
                                final name = p['name'] ?? 'Sản phẩm';
                                final sku = p['sku'] ?? p['gtin'] ?? 'Không có SKU';
                                return DropdownMenuItem<String>(
                                   value: p['id']?.toString(),
                                   child: Text('$name ($sku)', style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: _onProductChanged,
                            ),

                            if (_selectedProductId != null && _selectedProduct != null && _selectedProduct!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F3B5C),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.lightBlueAccent.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: Colors.lightBlueAccent, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: const TextStyle(color: _kTextSub, fontSize: 12),
                                          children: [
                                            const TextSpan(text: 'Quy cách sản phẩm: '),
                                            TextSpan(
                                              text: '${_unitWeightKg.toStringAsFixed(_unitWeightKg.truncateToDouble() == _unitWeightKg ? 0 : 1)} kg/gói',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.lightBlueAccent),
                                            ),
                                            if (_isBagOrder) ...[
                                              const TextSpan(text: ' | Đóng bao: '),
                                              TextSpan(
                                                text: '${_packagingSpec.toInt()} gói/bao',
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.lightBlueAccent),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 14),

                            CheckboxListTile(
                              value: _isBagOrder,
                              onChanged: (val) {
                                setState(() {
                                  _isBagOrder = val ?? true;
                                  _autoCalculateSpares();
                                });
                              },
                              title: const Text('Đóng bao (Tạo bao chứa nhiều gói)', style: TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: const Text('Tự động liên kết các gói vào từng bao theo quy cách', style: TextStyle(color: _kTextGray, fontSize: 11)),
                              activeColor: _kPrimary,
                              checkColor: Colors.white,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                            ),

                            CheckboxListTile(
                              value: _useExternalSource,
                              onChanged: (val) {
                                setState(() {
                                  _useExternalSource = val ?? false;
                                  _selectedFarmBatchCode = null;
                                  _selectedSourceBatchId = null;
                                  _plannedWeightCtrl.text = '0.0';
                                  _autoCalculateSpares();
                                });
                              },
                              title: const Text('Sử dụng nguyên liệu ngoài farm', style: TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: const Text('Chọn lô từ nguồn nhập ngoài hoặc chuyển nhượng B2B', style: TextStyle(color: _kTextGray, fontSize: 11)),
                              activeColor: _kPrimary,
                              checkColor: Colors.white,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                            ),

                            if (_useExternalSource) ...[
                              Container(
                                margin: const EdgeInsets.only(top: 4, bottom: 12),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _kFieldBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _kCardBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Loại nguồn nguyên liệu:', style: TextStyle(color: _kTextGray, fontSize: 12, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: RadioListTile<String>(
                                            value: 'EXTERNAL',
                                            groupValue: _sourceType,
                                            onChanged: (val) => setState(() {
                                              _sourceType = val!;
                                              _selectedSourceBatchId = null;
                                              _plannedWeightCtrl.text = '0.0';
                                            }),
                                            title: const Text('Nhập ngoài', style: TextStyle(color: _kText, fontSize: 12)),
                                            contentPadding: EdgeInsets.zero,
                                            activeColor: _kPrimary,
                                            dense: true,
                                          ),
                                        ),
                                        Expanded(
                                          child: RadioListTile<String>(
                                            value: 'CROSS_TENANT',
                                            groupValue: _sourceType,
                                            onChanged: (val) => setState(() {
                                              _sourceType = val!;
                                              _selectedSourceBatchId = null;
                                              _plannedWeightCtrl.text = '0.0';
                                            }),
                                            title: const Text('Nguồn B2B', style: TextStyle(color: _kText, fontSize: 12)),
                                            contentPadding: EdgeInsets.zero,
                                            activeColor: _kPrimary,
                                            dense: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 8),

                            _buildFieldLabel(isFarm ? 'Lô thu hoạch nông trại' : 'Lô nguyên liệu ngoài / B2B', isRequired: true),
                            InkWell(
                              onTap: _openLotPicker,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: _kFieldBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: hasSelectedLot ? _kPrimaryLight : _kCardBorder,
                                    width: hasSelectedLot ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isFarm ? Icons.agriculture_rounded : Icons.local_shipping_rounded,
                                      color: hasSelectedLot ? _kPrimaryLight : _kTextGray,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: hasSelectedLot && selectedLot != null && selectedLot.isNotEmpty
                                          ? Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  (selectedLot['batchCode'] ?? selectedLot['batch_code'] ?? selectedLot['code'] ?? 'Lô đã chọn').toString(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    fontFamily: 'monospace',
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  selectedLot['cropCycle']?['location']?['plantType'] ??
                                                      selectedLot['productName'] ??
                                                      selectedLot['product']?['name'] ??
                                                      selectedLot['name'] ??
                                                      'Nguyên liệu',
                                                  style: const TextStyle(color: _kTextGray, fontSize: 12),
                                                ),
                                              ],
                                            )
                                          : Text(
                                              isFarm ? 'Bấm để chọn lô thu hoạch farm...' : 'Bấm để chọn lô nguyên liệu ngoài...',
                                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                                            ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 24),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            _buildFieldLabel('Ngày kế hoạch sản xuất'),
                            InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _plannedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                  builder: (context, child) {
                                    return Theme(
                                      data: ThemeData.dark().copyWith(
                                        colorScheme: const ColorScheme.dark(
                                          primary: _kPrimary,
                                          onPrimary: Colors.white,
                                          surface: _kSurface,
                                          onSurface: Colors.white,
                                        ),
                                        dialogBackgroundColor: _kSurface,
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (d != null) setState(() => _plannedDate = d);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: _kFieldBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _kCardBorder),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormat('dd/MM/yyyy').format(_plannedDate),
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                    const Icon(Icons.calendar_today_rounded, size: 18, color: _kTextGray),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ==================== KHỐI 2: KHỐI LƯỢNG & THÔNG SỐ SẢN XUẤT ====================
                      _buildSectionCard(
                        title: '2. Khối Lượng & Thông Số Kế Hoạch',
                        icon: Icons.calculate_outlined,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Khối lượng nguyên liệu', isRequired: true),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _plannedWeightCtrl,
                                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: _inputDeco('0.0'),
                                    onChanged: (_) {
                                      setState(() {
                                        _autoCalculateSpares();
                                      });
                                    },
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return 'Vui lòng nhập khối lượng!';
                                      final n = double.tryParse(val.trim());
                                      if (n == null || n <= 0) return 'Khối lượng phải > 0!';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    value: _plannedWeightUnit,
                                    dropdownColor: _kSurface,
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white),
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                    decoration: _inputDeco('').copyWith(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'KG', child: Text('Kg', overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'YEN', child: Text('Yến (x10)', overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'TA', child: Text('Tạ (x100)', overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'TON', child: Text('Tấn (x1000)', overflow: TextOverflow.ellipsis)),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _plannedWeightUnit = val;
                                          _autoCalculateSpares();
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Quy đổi thực tế: ${_plannedWeightKg.toStringAsFixed(1)} kg nguyên liệu',
                              style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 12, fontWeight: FontWeight.w500),
                            ),

                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: _buildParamBox('Số gói ước tính', '$_estimatedUnits gói'),
                                ),
                                if (_isBagOrder) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildParamBox('Số bao ước tính', '$_estimatedBags bao'),
                                  ),
                                ],
                              ],
                            ),

                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: _buildSpinBox(
                                    'Gói bù hao hụt (Spare)',
                                    _sparePacketQuantity,
                                    (val) => setState(() => _sparePacketQuantity = val),
                                  ),
                                ),
                                if (_isBagOrder) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildSpinBox(
                                      'Bao bù hao hụt (Spare)',
                                      _spareBagQuantity,
                                      (val) => setState(() => _spareBagQuantity = val),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ==================== KHỐI 3: SERIAL & GHI CHÚ ====================
                      _buildSectionCard(
                        title: '3. Serial & Ghi Chú Kế Hoạch',
                        icon: Icons.qr_code_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Mã prefix serial'),
                            TextFormField(
                              controller: _serialPrefixCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              maxLength: 4,
                              textCapitalization: TextCapitalization.characters,
                              decoration: _inputDeco('VD: AWD').copyWith(counterText: ''),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text('${_serialPrefixCtrl.text.trim().length}/4 ký tự', style: const TextStyle(color: _kTextGray, fontSize: 11)),
                                const Text(' • ', style: TextStyle(color: _kTextGray, fontSize: 11)),
                                const Text('Mẫu: ', style: TextStyle(color: _kTextGray, fontSize: 11)),
                                Text(_serialPreview, style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                              ],
                            ),

                            const SizedBox(height: 16),

                            _buildFieldLabel('Ghi chú / Chỉ dẫn sản xuất'),
                            TextFormField(
                              controller: _notesCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              maxLines: 3,
                              decoration: _inputDeco('Nhập ghi chú hoặc yêu cầu QC...'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kSurface,
          border: const Border(top: BorderSide(color: _kCardBorder)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kTextSub,
                    side: const BorderSide(color: _kCardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Hủy', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text(
                          'Tạo Lệnh Sản Xuất',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _kPrimaryLight, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(color: _kText, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildParamBox(String label, String value, {bool isReadOnly = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _kTextGray, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: _kFieldBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kCardBorder),
          ),
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildSpinBox(String label, int value, ValueChanged<int>? onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _kTextGray, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: _kFieldBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kCardBorder),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: onChanged != null && value > 0 ? () => onChanged(value - 1) : null,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                child: Container(
                  width: 40,
                  height: double.infinity,
                  alignment: Alignment.center,
                  child: Icon(Icons.remove, size: 18, color: (onChanged != null && value > 0) ? Colors.white : Colors.white24),
                ),
              ),
              Expanded(
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              InkWell(
                onTap: onChanged != null ? () => onChanged(value + 1) : null,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                child: Container(
                  width: 40,
                  height: double.infinity,
                  alignment: Alignment.center,
                  child: Icon(Icons.add, size: 18, color: onChanged != null ? Colors.white : Colors.white24),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
