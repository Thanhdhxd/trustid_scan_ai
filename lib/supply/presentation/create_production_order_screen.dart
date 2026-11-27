import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:intl/intl.dart';
import 'package:trustid_scan_ai/core/services/plan_entitlement_provider.dart';
import 'package:trustid_scan_ai/core/utils/app_toast.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';
import 'package:trustid_scan_ai/farm/data/farm_repository.dart';
import '../data/supply_repository.dart';
import '../data/surplus_repository.dart';
import '../domain/surplus_pool.dart';
import 'order_list_screen.dart';
import 'production_order/constants/prod_order_constants.dart';
import 'production_order/constants/prod_order_helpers.dart';
import 'production_order/dialogs/prod_order_lot_picker_sheet.dart';
import 'production_order/dialogs/prod_order_surplus_picker_sheet.dart';
import 'production_order/widgets/prod_order_step1_materials_card.dart';
import 'production_order/widgets/prod_order_step2_params_card.dart';
import 'production_order/widgets/prod_order_step3_serial_notes_card.dart';

class CreateProductionOrderScreen extends ConsumerStatefulWidget {
  final String? initialSurplusPoolId;
  const CreateProductionOrderScreen({super.key, this.initialSurplusPoolId});

  static void clearStaticCache() {
    _CreateProductionOrderScreenState.clearStaticCache();
  }

  @override
  ConsumerState<CreateProductionOrderScreen> createState() =>
      _CreateProductionOrderScreenState();
}

class _CreateProductionOrderScreenState
    extends ConsumerState<CreateProductionOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  static List<Map<String, dynamic>>? _cachedStaticProducts;
  static List<Map<String, dynamic>>? _cachedStaticWarehouses;
  static List<SurplusPool>? _cachedStaticSurplusPools;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheTtl = Duration(minutes: 15);

  static void clearStaticCache() {
    _cachedStaticProducts = null;
    _cachedStaticWarehouses = null;
    _cachedStaticSurplusPools = null;
    _cacheTimestamp = null;
  }

  bool _loading = true;
  bool _submitting = false;
  bool _previewing = false;
  String? _error;

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<SurplusPool> _surplusPools = [];

  // Form State
  String? _selectedProductId;
  String? _selectedWarehouseId;
  DateTime _plannedDate = DateTime.now();
  DateTime? _expiryDate;

  double _unitWeightKg = 1.0;
  double _packagingSpec = 40.0;

  bool _isBagOrder = true; // true = BAG_PACKAGING, false = STANDARD
  String _sourceType = 'EXTERNAL'; // FARM | EXTERNAL | CROSS_TENANT | SEMI_FINISHED | SURPLUS

  Map<String, dynamic>? _selectedLot;
  String? _selectedSurplusPoolId;

  final _plannedWeightCtrl = TextEditingController(text: '0.0');
  String _plannedWeightUnit = 'KG';

  int _sparePacketQuantity = 0;
  int _spareBagQuantity = 0;

  final _serialPrefixCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final hasFarm = ref.read(hasPlanFeatureProvider('FN-FAR-06'));
    if (hasFarm) {
      _sourceType = 'FARM';
    }
    final isCacheValid = _cachedStaticProducts != null &&
        _cachedStaticProducts!.isNotEmpty &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheTtl;

    if (isCacheValid) {
      _products = List.from(_cachedStaticProducts!);
      _warehouses = List.from(_cachedStaticWarehouses ?? []);
      _surplusPools = List.from(_cachedStaticSurplusPools ?? []);
      _pickDefaultWarehouse();
      _loading = false;
    }
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

  void _pickDefaultWarehouse() {
    if (_selectedWarehouseId != null || _warehouses.isEmpty) return;
    final activeList = _warehouses
        .where((w) => (w['status'] ?? 'ACTIVE').toString().toUpperCase() == 'ACTIVE')
        .toList();
    final candidates = activeList.isNotEmpty ? activeList : _warehouses;
    final def = candidates.firstWhere(
      (w) => w['isDefault'] == true || w['is_default'] == true,
      orElse: () => candidates.first,
    );
    _selectedWarehouseId = def['id']?.toString();
  }

  Future<void> _loadInitialData() async {
    if (_products.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final repo = ref.read(supplyRepositoryProvider);
      final surplusRepo = ref.read(surplusRepositoryProvider);

      final results = await Future.wait([
        repo.getProducts(),
        repo.getWarehouses(limit: 100).catchError((_) => <dynamic>[]),
        surplusRepo.listPools().catchError((_) => <SurplusPool>[]),
      ]);

      if (!mounted) return;

      final products = results[0]
          .whereType<Map>()
          .map((p) => Map<String, dynamic>.from(p))
          .where((p) => (p['status'] ?? 'ACTIVE').toString().toUpperCase() == 'ACTIVE')
          .toList();
      final warehouses = results[1]
          .whereType<Map>()
          .map((w) => Map<String, dynamic>.from(w))
          .toList();
      final surplusPools = results[2] as List<SurplusPool>;

      SurplusPool? preselectedPool;
      if (widget.initialSurplusPoolId != null && widget.initialSurplusPoolId!.isNotEmpty) {
        preselectedPool = surplusPools.cast<SurplusPool?>().firstWhere(
              (p) => p?.id == widget.initialSurplusPoolId,
              orElse: () => null,
            );
      }

      setState(() {
        _products = products;
        _warehouses = warehouses;
        _surplusPools = surplusPools;
        _pickDefaultWarehouse();

        if (preselectedPool != null) {
          _sourceType = 'SURPLUS';
          _selectedSurplusPoolId = preselectedPool.id;
          if (preselectedPool.productId.isNotEmpty) {
            _applyProductSelection(preselectedPool.productId);
            _selectedSurplusPoolId = preselectedPool.id;
          }
          final mult = _getUnitMultiplier(_plannedWeightUnit);
          _plannedWeightCtrl.text =
              (preselectedPool.availableWeightKg / mult).toStringAsFixed(1);
          _autoCalculateSpares();
        }
        _loading = false;
      });

      _cachedStaticProducts = products;
      _cachedStaticWarehouses = warehouses;
      _cachedStaticSurplusPools = surplusPools;
      _cacheTimestamp = DateTime.now();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Lỗi tải dữ liệu: ${parseSupplyHttpError(e).message}';
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

  SurplusPool? get _selectedSurplusPool {
    if (_selectedSurplusPoolId == null) return null;
    return _surplusPools.cast<SurplusPool?>().firstWhere(
          (p) => p?.id == _selectedSurplusPoolId,
          orElse: () => null,
        );
  }

  List<SurplusPool> get _filteredSurplusPools {
    if (_selectedProductId == null) return [];
    return _surplusPools
        .where((p) => p.availableWeightKg > 0.001 && p.productId == _selectedProductId)
        .toList();
  }

  void _applyProductSelection(String? productId) {
    _selectedProductId = productId;
    _selectedLot = null;
    _selectedSurplusPoolId = null;
    _plannedWeightCtrl.text = '0.0';
    _sparePacketQuantity = 0;
    _spareBagQuantity = 0;

    if (productId == null) {
      _expiryDate = null;
      return;
    }

    final p = _products.firstWhere(
      (item) => item['id']?.toString() == productId,
      orElse: () => {},
    );
    if (p.isNotEmpty) {
      if (p['netWeight'] != null &&
          (double.tryParse(p['netWeight'].toString()) ?? 0) > 0) {
        double w = double.parse(p['netWeight'].toString());
        final unit = (p['weightUnit'] ?? 'kg').toString().toLowerCase();
        if (unit == 'g' || unit == 'ml') w /= 1000;
        _unitWeightKg = w;
      } else {
        _unitWeightKg = 1.0;
      }

      if (p['defaultPackagingSpec'] != null &&
          (double.tryParse(p['defaultPackagingSpec'].toString()) ?? 0) > 0) {
        _packagingSpec = double.parse(p['defaultPackagingSpec'].toString());
      } else {
        _packagingSpec = 0.0;
      }

      _expiryDate = computeDefaultExpiryDate(_plannedDate, p);
    } else {
      _expiryDate = null;
    }
  }

  void _onProductChanged(String? productId) {
    setState(() => _applyProductSelection(productId));
  }

  void _onPlannedDateChanged(DateTime date) {
    setState(() {
      _plannedDate = date;
      final p = _selectedProduct;
      if (hasProductExpiryConfig(p)) {
        _expiryDate = computeDefaultExpiryDate(date, p);
      } else if (_expiryDate != null && _expiryDate!.isBefore(date)) {
        _expiryDate = null;
      }
    });
  }

  void _onSourceTypeChanged(String nextType) {
    setState(() {
      _sourceType = nextType;
      _selectedLot = null;
      _selectedSurplusPoolId = null;
      _plannedWeightCtrl.text = '0.0';
      _sparePacketQuantity = 0;
      _spareBagQuantity = 0;
    });
  }

  String _effectiveSourceType([bool? hasFarm]) {
    final bool allowedFarm = hasFarm ?? ref.read(hasPlanFeatureProvider('FN-FAR-06'));
    if (!allowedFarm && _sourceType == 'FARM') return 'EXTERNAL';
    return _sourceType;
  }

  double _extractLotRemainingKg(Map<String, dynamic> lot) {
    final raw = _effectiveSourceType() == 'FARM'
        ? (lot['remainingQuantityKg'] ?? lot['quantityKg'] ?? lot['totalQuantity'] ?? 0)
        : (lot['availableQuantity'] ??
            lot['remainingQuantityKg'] ??
            lot['totalQuantity'] ??
            lot['totalUnitsExpected'] ??
            lot['quantity'] ??
            0);
    return double.tryParse(raw.toString()) ?? 0.0;
  }

  void _onLotSelected(Map<String, dynamic> lot) {
    final rem = _extractLotRemainingKg(lot);
    final mult = _getUnitMultiplier(_plannedWeightUnit);
    setState(() {
      _selectedLot = lot;
      _plannedWeightCtrl.text = (rem / mult).toStringAsFixed(1);
      _autoCalculateSpares();
    });
  }

  void _onSurplusPoolSelected(String? poolId) {
    setState(() {
      _selectedSurplusPoolId = poolId;
      if (poolId == null) {
        _plannedWeightCtrl.text = '0.0';
        _sparePacketQuantity = 0;
        _spareBagQuantity = 0;
        return;
      }
      final pool = _surplusPools.cast<SurplusPool?>().firstWhere(
            (p) => p?.id == poolId,
            orElse: () => null,
          );
      if (pool != null) {
        if (_selectedProductId == null && pool.productId.isNotEmpty) {
          _applyProductSelection(pool.productId);
          _selectedSurplusPoolId = poolId;
        }
        final mult = _getUnitMultiplier(_plannedWeightUnit);
        _plannedWeightCtrl.text = (pool.availableWeightKg / mult).toStringAsFixed(1);
        _autoCalculateSpares();
      }
    });
  }

  void _autoCalculateSpares() {
    final units = _estimatedUnits;
    final bags = _estimatedBags;
    _sparePacketQuantity = units > 0 ? (units * 0.1).ceil() : 0;
    _spareBagQuantity = (bags > 0 && _isBagOrder) ? (bags * 0.1).ceil() : 0;
  }

  double get _plannedWeightRaw =>
      double.tryParse(_plannedWeightCtrl.text.trim()) ?? 0.0;
  double get _plannedWeightKg =>
      _plannedWeightRaw * _getUnitMultiplier(_plannedWeightUnit);

  int get _estimatedUnits {
    if (_selectedProductId == null || _plannedWeightKg <= 0 || _unitWeightKg <= 0) {
      return 0;
    }
    return (_plannedWeightKg / _unitWeightKg).ceil();
  }

  int get _estimatedBags {
    if (!_isBagOrder ||
        _selectedProductId == null ||
        _packagingSpec <= 0 ||
        _estimatedUnits <= 0) {
      return 0;
    }
    return (_estimatedUnits / _packagingSpec).ceil();
  }

  String get _serialPreview {
    final prefix = _serialPrefixCtrl.text.trim().isNotEmpty
        ? _serialPrefixCtrl.text.trim().toUpperCase()
        : 'BKG';
    final year = DateTime.now().year.toString().substring(2);
    return '$prefix-$year-00001';
  }

  void _openLotPicker() {
    if (_selectedProductId == null) {
      AppToast.error(context, 'Vui lòng chọn sản phẩm thành phẩm trước!');
      return;
    }

    final srcType = _effectiveSourceType();
    if (srcType == 'SURPLUS') {
      ProdOrderSurplusPickerSheet.show(
        context: context,
        items: _filteredSurplusPools,
        selectedKey: _selectedSurplusPoolId,
        productName: _selectedProduct?['name'] ?? '',
        onSelect: _onSurplusPoolSelected,
      );
      return;
    }

    final isFarm = srcType == 'FARM';
    final selectedKey = isFarm
        ? (_selectedLot?['batchCode'] ?? _selectedLot?['batch_code'])?.toString()
        : _selectedLot?['id']?.toString();

    final title = switch (srcType) {
      'FARM' => 'Chọn Lô Thu Hoạch Nông Trại',
      'CROSS_TENANT' => 'Chọn Lô Nhận B2B (Cross-Tenant)',
      'SEMI_FINISHED' => 'Chọn Lô Bán Thành Phẩm (BTP)',
      _ => 'Chọn Lô Nguyên Liệu Nhập Ngoài',
    };

    ProdOrderLotPickerSheet.show(
      context: context,
      isFarm: isFarm,
      title: title,
      productName: _selectedProduct?['name'] ?? '',
      selectedKey: selectedKey,
      onFetchLots: (search) {
        if (isFarm) {
          return ref.read(farmRepositoryProvider).getHarvestSourceOptions(
                productId: _selectedProductId,
                search: search,
                limit: 20,
              );
        }
        return ref.read(supplyRepositoryProvider).getExternalBatchSourceOptions(
              sourceType: srcType,
              productId: srcType == 'EXTERNAL' ? _selectedProductId : null,
              search: search,
              hideEmptyStock: true,
              limit: 20,
            );
      },
      onSelect: _onLotSelected,
    );
  }

  Future<void> _prepareConfirmation() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductId == null) {
      AppToast.error(context, 'Vui lòng chọn sản phẩm thành phẩm!');
      return;
    }
    if (_selectedWarehouseId == null || _selectedWarehouseId!.isEmpty) {
      AppToast.error(context, 'Vui lòng chọn kho nhập thành phẩm!');
      return;
    }
    if (_isBagOrder && _packagingSpec <= 0) {
      AppToast.error(context, 'Sản phẩm chưa có quy cách đóng bao.');
      return;
    }

    final hasExpConfig = hasProductExpiryConfig(_selectedProduct);
    if (!hasExpConfig && _expiryDate == null) {
      AppToast.error(context, 'Sản phẩm chưa có HSD mặc định — vui lòng chọn HSD dự kiến.');
      return;
    }
    if (_expiryDate != null &&
        DateTime(_expiryDate!.year, _expiryDate!.month, _expiryDate!.day).isBefore(
          DateTime(_plannedDate.year, _plannedDate.month, _plannedDate.day),
        )) {
      AppToast.error(context, 'Hạn sử dụng không được nhỏ hơn ngày thực hiện.');
      return;
    }

    final srcType = _effectiveSourceType();
    if (srcType == 'SURPLUS') {
      if (_selectedSurplusPoolId == null || _selectedSurplusPoolId!.isEmpty) {
        AppToast.error(context, 'Vui lòng chọn Kho dư BTP!');
        return;
      }
      final availableKg = _selectedSurplusPool?.availableWeightKg ?? 0.0;
      if (_plannedWeightKg > availableKg && availableKg > 0) {
        AppToast.error(
          context,
          'Khối lượng (${_plannedWeightKg.toStringAsFixed(1)} kg) vượt quá số dư khả dụng (${availableKg.toStringAsFixed(1)} kg)!',
        );
        return;
      }
    } else if (_selectedLot == null) {
      AppToast.error(context, 'Vui lòng chọn lô nguyên liệu nguồn!');
      return;
    } else {
      final rem = _extractLotRemainingKg(_selectedLot!);
      if (_plannedWeightKg > rem + 0.001) {
        AppToast.error(
          context,
          'Khối lượng (${_plannedWeightKg.toStringAsFixed(1)} kg) vượt quá tồn khả dụng (${rem.toStringAsFixed(1)} kg)!',
        );
        return;
      }
    }

    if (_plannedWeightKg <= 0) {
      AppToast.error(context, 'Khối lượng kế hoạch phải lớn hơn 0 kg!');
      return;
    }

    Map<String, dynamic>? preview;
    if (_isBagOrder) {
      setState(() => _previewing = true);
      try {
        preview = await ref.read(supplyRepositoryProvider).previewBagOrder(
              productId: _selectedProductId!,
              plannedWeightKg: _plannedWeightKg,
              quantity: _estimatedUnits,
              unitWeightKg: _unitWeightKg,
              packagingSpec: _packagingSpec.toInt(),
              sparePacketQuantity: _sparePacketQuantity,
              spareBagQuantity: _spareBagQuantity,
              sourceType: srcType,
              farmBatchCode: srcType == 'FARM'
                  ? ((_selectedLot?['batchCode'] ?? _selectedLot?['batch_code'])?.toString())
                  : null,
              sourceBatchId: srcType != 'FARM'
                  ? (_selectedLot == null ? null : _selectedLot!['id']?.toString())
                  : null,
            );
      } catch (_) {
        preview = null;
      } finally {
        if (mounted) setState(() => _previewing = false);
      }
    }

    if (!mounted) return;
    final confirmed = await _showConfirmCreateDialog(preview);
    if (confirmed == true) {
      await _submit();
    }
  }

  Future<bool?> _showConfirmCreateDialog(Map<String, dynamic>? preview) {
    final whName = _warehouses
            .firstWhere(
              (w) => w['id']?.toString() == _selectedWarehouseId,
              orElse: () => {'name': '—'},
            )['name']
            ?.toString() ??
        '—';
    final hasEnoughQuota = preview == null ? true : (preview['hasEnoughQuota'] != false);
    final totalCodesNeeded = preview?['totalCodesNeeded'] ??
        (_estimatedUnits +
            _sparePacketQuantity +
            (_isBagOrder ? _estimatedBags + _spareBagQuantity : 0));

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: kProdOrderSurface,
        title: const Text(
          'Xác nhận tạo Lệnh Sản Xuất',
          style: TextStyle(color: kProdOrderText, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _confirmRow('Sản phẩm', (_selectedProduct?['name'] ?? '—').toString()),
              _confirmRow('Loại lệnh', _isBagOrder ? 'Đóng bao (BAG_PACKAGING)' : 'Tiêu chuẩn (STANDARD)'),
              _confirmRow('Nguồn NL', prodOrderSourceLabel(_effectiveSourceType())),
              _confirmRow('Kho nhập', whName),
              _confirmRow('Khối lượng', '${_plannedWeightKg.toStringAsFixed(1)} kg (~$_estimatedUnits gói)'),
              _confirmRow('NSX / HSD dự kiến', '${formatProdOrderDate(_plannedDate)} → ${formatProdOrderDate(_expiryDate)}'),
              _confirmRow('Tổng mã QR sẽ sinh', '$totalCodesNeeded mã'),
              if (preview != null && preview['currentCodeQuota'] != null)
                _confirmRow('Hạn mức mã còn', '${preview['currentCodeQuota']} mã'),
              const SizedBox(height: 10),
              if (!hasEnoughQuota)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: const Text(
                    'Hạn mức mã QR không đủ để tạo lệnh này.',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kProdOrderAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kProdOrderAmber.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'Lệnh sẽ bắt đầu ngay khi xác nhận và không hỗ trợ sửa thông tin sau khi tạo.',
                  style: TextStyle(color: kProdOrderTextSub, fontSize: 12, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kiểm tra lại', style: TextStyle(color: kProdOrderTextGray)),
          ),
          ElevatedButton(
            onPressed: hasEnoughQuota ? () => Navigator.pop(ctx, true) : null,
            style: ElevatedButton.styleFrom(backgroundColor: kProdOrderPrimary),
            child: const Text('Xác nhận tạo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text('$label:', style: const TextStyle(color: kProdOrderTextGray, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    try {
      final repo = ref.read(supplyRepositoryProvider);
      final srcType = _effectiveSourceType();
      final isSurplus = srcType == 'SURPLUS';
      final isFarm = srcType == 'FARM';

      final payload = <String, dynamic>{
        'product_id': _selectedProductId,
        'warehouse_id': _selectedWarehouseId,
        'source_type': srcType,
        'planned_weight_kg': _plannedWeightKg,
        'unit_weight_kg': _unitWeightKg,
        'planned_date': formatProdOrderDateIso(_plannedDate),
        'mfg_date': formatProdOrderDateIso(_plannedDate),
        if (_expiryDate != null) 'expiry_date': formatProdOrderDateIso(_expiryDate!),
        'spare_packet_quantity': _sparePacketQuantity,
        'generate_codes_immediately': true,
        'include_link': true,
        if (_serialPrefixCtrl.text.trim().isNotEmpty)
          'serial_prefix': _serialPrefixCtrl.text.trim().toUpperCase(),
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      };

      if (isSurplus) {
        payload['source_batch_id'] = _selectedSurplusPoolId;
        payload['surplus_pool_id'] = _selectedSurplusPoolId;
      } else if (isFarm) {
        payload['farm_batch_code'] =
            (_selectedLot?['batchCode'] ?? _selectedLot?['batch_code'])?.toString();
      } else {
        payload['source_batch_id'] = _selectedLot?['id']?.toString();
      }

      Map<String, dynamic> createdResp;
      if (_isBagOrder) {
        payload['quantity'] = _estimatedUnits;
        payload['packaging_spec'] = _packagingSpec.toInt();
        payload['spare_bag_quantity'] = _spareBagQuantity;
        try {
          createdResp = await repo.createBagOrder(payload);
        } catch (e) {
          if (isSurplus) {
            createdResp = await _fallbackCreateFromSurplus();
          } else {
            rethrow;
          }
        }
      } else {
        try {
          createdResp = await repo.createProductionOrder(payload);
        } catch (e) {
          if (isSurplus) {
            createdResp = await _fallbackCreateFromSurplus();
          } else {
            rethrow;
          }
        }
      }

      final createdData = createdResp['data'] is Map
          ? Map<String, dynamic>.from(createdResp['data'] as Map)
          : createdResp;
      final newOrderId = createdData['id']?.toString() ?? '';

      OrderListScreen.clearStaticCache();
      if (mounted) {
        setState(() => _submitting = false);
        AppToast.success(context, 'Tạo Lệnh Sản Xuất thành công!');
        if (newOrderId.isNotEmpty) {
          context.pushReplacement('/manager/production-orders/$newOrderId');
        } else if (context.canPop()) {
          context.pop(true);
        } else {
          context.go('/manager/orders-bag-linking');
        }
      }
    } catch (e) {
      final parsed = parseSupplyHttpError(e);
      if (parsed.isPlanLocked) {
        ref.read(planEntitlementProvider.notifier).refreshThrottled();
      }
      if (mounted) {
        setState(() => _submitting = false);
        AppToast.error(context, parsed.message, title: 'Lỗi tạo Lệnh Sản Xuất');
      }
    }
  }

  Future<Map<String, dynamic>> _fallbackCreateFromSurplus() async {
    final surplusRepo = ref.read(surplusRepositoryProvider);
    var pool = _selectedSurplusPool;
    if (pool == null || pool.entries.isEmpty) {
      pool = await surplusRepo.getPoolDetail(_selectedSurplusPoolId!);
    }
    final poolEntries = pool.entries
        .where((e) => e.status == 'AVAILABLE')
        .map((e) => e.id)
        .toList();
    if (poolEntries.isEmpty) {
      throw Exception('Kho dư BTP không còn mẻ dư khả dụng.');
    }
    return surplusRepo.createOrderFromSurplus(
      poolId: _selectedSurplusPoolId!,
      entryIds: poolEntries,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nowStr = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final userName = ref.watch(authControllerProvider).value?.fullName ?? 'Quản lý';
    final hasFarmFeature = ref.watch(hasPlanFeatureProvider('FN-FAR-06'));

    final effectiveSourceType = (!hasFarmFeature && _sourceType == 'FARM')
        ? 'EXTERNAL'
        : _sourceType;
    final hasSelectedLot = effectiveSourceType == 'SURPLUS'
        ? _selectedSurplusPoolId != null
        : _selectedLot != null;

    return Scaffold(
      backgroundColor: kProdOrderBg,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Tạo Lệnh Sản Xuất Mới',
                style: TextStyle(color: kProdOrderText, fontSize: 16.5, fontWeight: FontWeight.bold),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Người tạo: $userName • Ngày: $nowStr',
                style: const TextStyle(color: kProdOrderTextGray, fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: kProdOrderBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: kProdOrderTextGray),
      ),
      body: Column(
        children: [
          if (_loading)
            const LinearProgressIndicator(
              minHeight: 2.5,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(kProdOrderPrimary),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadInitialData,
              color: kProdOrderPrimary,
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      ProdOrderStep1MaterialsCard(
                        selectedProductId: _selectedProductId,
                        products: _products,
                        onProductChanged: _onProductChanged,
                        selectedProduct: _selectedProduct,
                        selectedWarehouseId: _selectedWarehouseId,
                        warehouses: _warehouses,
                        onWarehouseChanged: (w) => setState(() => _selectedWarehouseId = w),
                        unitWeightKg: _unitWeightKg,
                        isBagOrder: _isBagOrder,
                        packagingSpec: _packagingSpec,
                        onIsBagOrderChanged: (v) {
                          setState(() {
                            _isBagOrder = v;
                            _autoCalculateSpares();
                          });
                        },
                        plannedDate: _plannedDate,
                        onPlannedDateChanged: _onPlannedDateChanged,
                        expiryDate: _expiryDate,
                        hasProductExpiry: hasProductExpiryConfig(_selectedProduct),
                        onExpiryDateChanged: (d) => setState(() => _expiryDate = d),
                        hasFarmFeature: hasFarmFeature,
                        sourceType: effectiveSourceType,
                        onSourceTypeChanged: _onSourceTypeChanged,
                        filteredSurplusPools: _filteredSurplusPools,
                        hasSelectedLot: hasSelectedLot,
                        selectedLot: _selectedLot,
                        selectedSurplusPool: _selectedSurplusPool,
                        onOpenLotPicker: _openLotPicker,
                        plannedWeightCtrl: _plannedWeightCtrl,
                        plannedWeightUnit: _plannedWeightUnit,
                        onPlannedWeightUnitChanged: (val) {
                          setState(() {
                            _plannedWeightUnit = val;
                            _autoCalculateSpares();
                          });
                        },
                        onPlannedWeightChanged: () {
                          setState(() => _autoCalculateSpares());
                        },
                      ),

                      const SizedBox(height: 14),

                      ProdOrderStep2ParamsCard(
                        estimatedUnits: _estimatedUnits,
                        estimatedBags: _estimatedBags,
                        isBagOrder: _isBagOrder,
                        sparePacketQuantity: _sparePacketQuantity,
                        spareBagQuantity: _spareBagQuantity,
                        onSparePacketQuantityChanged: (v) =>
                            setState(() => _sparePacketQuantity = v),
                        onSpareBagQuantityChanged: _isBagOrder
                            ? (v) => setState(() => _spareBagQuantity = v)
                            : null,
                      ),

                      const SizedBox(height: 14),

                      ProdOrderStep3SerialNotesCard(
                        serialPrefixCtrl: _serialPrefixCtrl,
                        serialPreview: _serialPreview,
                        onSerialPrefixChanged: () => setState(() {}),
                        notesCtrl: _notesCtrl,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: MediaQuery.of(context).viewInsets.bottom > 0
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kProdOrderSurface,
                border: const Border(top: BorderSide(color: kProdOrderCardBorder)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
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
                          foregroundColor: kProdOrderTextSub,
                          side: const BorderSide(color: kProdOrderCardBorder),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed:
                            (_submitting || _previewing) ? null : _prepareConfirmation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kProdOrderPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: (_submitting || _previewing)
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Tạo Lệnh Sản Xuất',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
