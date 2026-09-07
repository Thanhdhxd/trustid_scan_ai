import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';
import 'package:dio/dio.dart';
import '../../data/supply_repository.dart';
import '../../data/vietnam_provinces_code.dart';
import '../widgets/qr_scan_input.dart';
import '../widgets/stat_box_row.dart';
import '../widgets/province_selector.dart';
import 'package:trustid_scan_ai/scan/scanner_screen.dart';
import 'package:trustid_scan_ai/core/widgets/skeleton_loader.dart';
const Color _kPrimary = Color(0xFF00875A);
const Color _kBg = Color(0xFF0F2B46);
const Color _kSurface = Color(0xFF16325B);
const Color _kText = Color(0xFFE8EDF3);
const Color _kGray = Color(0xFF94A3B8);
const _kDraftKey = 'sf_draft_serials';

class SemiFinishedPackagingScreen extends ConsumerStatefulWidget {
  const SemiFinishedPackagingScreen({super.key});

  @override
  ConsumerState<SemiFinishedPackagingScreen> createState() =>
      _SemiFinishedPackagingScreenState();
}

class _SemiFinishedPackagingScreenState
    extends ConsumerState<SemiFinishedPackagingScreen> {
  // Data
  List<Map<String, dynamic>> _batches = [];
  List<Map<String, dynamic>> _externalBatches = [];
  List<Map<String, dynamic>> _warehouses = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Step 1: Source batch
  String _sourceBatchId = '';

  // Step 2: Quantities
  double _inputWeight = 0;
  double _packageWeight = 50;
  int _bagCount = 0;
  double _actualSurplus = 0;

  // Step 3: Info
  String? _selectedProvinceName;
  String? _selectedProvinceCode;
  String _warehouseId = '';
  String _expectedBatchCode = '';
  bool _customBatchCode = false;
  final _batchCodeCtrl = TextEditingController();

  // Step 4: Serials
  bool _scanMode = false;
  List<Map<String, dynamic>> _serialRows = [];
  final FocusNode _scanFocus = FocusNode();
  final _manualSerialController = TextEditingController();
  bool _isCollapsed = false;

  // Step 5: Pallet linking
  bool _linkToPallet = false;
  Map<String, dynamic>? _selectedPallet;

  final _packageWeightOptions = [5, 10, 25, 50];

  final _inputCtrl = TextEditingController();
  final _bagCtrl = TextEditingController();
  final _surplusCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _restoreDraft();
  }

  @override
  void dispose() {
    _scanFocus.dispose();
    _inputCtrl.dispose();
    _bagCtrl.dispose();
    _surplusCtrl.dispose();
    _batchCodeCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _sourceBatch {
    final all = [..._batches, ..._externalBatches];
    return all.cast<Map<String, dynamic>?>().firstWhere(
      (b) => b!['id'] == _sourceBatchId,
      orElse: () => null,
    );
  }

  double get _sourceAvailable {
    final b = _sourceBatch;
    if (b == null) return 0;
    return _toDouble(
      b['availableQuantity'] ??
          b['available_quantity'] ??
          b['totalQuantity'] ??
          b['total_quantity'],
    );
  }

  double get _outputWeight => _packageWeight * _bagCount;
  double get _computedSurplus => (_inputWeight - _outputWeight).clamp(0.0, double.infinity);
  double get _lossPercent => _inputWeight > 0
      ? (((_inputWeight - _outputWeight - _actualSurplus) / _inputWeight) * 100).clamp(0.0, 100.0)
      : 0.0;

  void _recalculateSurplus({bool updateController = true}) {
    final computed = _computedSurplus;
    _actualSurplus = computed;
    if (updateController) {
      _surplusCtrl.text = _actualSurplus.toStringAsFixed(_actualSurplus == _actualSurplus.roundToDouble() ? 0 : 1);
    }
  }

  Future<void> _loadData() async {
    try {
      final repo = ref.read(supplyRepositoryProvider);
      final results = await Future.wait([
        repo.getBatches(),
        repo.getExternalBatches(),
        repo.getWarehouses(),
      ]);
      if (!mounted) return;

      final allBatches = (results[0] as List)
          .where((b) {
            final type = (b['batchType'] ?? b['batch_type'] ?? '')
                .toString()
                .toUpperCase();
            return ['FARM', 'EXTERNAL'].contains(type) &&
                _toDouble(
                      b['availableQuantity'] ??
                          b['available_quantity'] ??
                          b['totalQuantity'] ??
                          b['total_quantity'],
                    ) >
                    0.001;
          })
          .map((b) => Map<String, dynamic>.from(b))
          .toList();

      final ext = (results[1] as List)
          .where((b) {
            return _toDouble(
                  b['availableQuantity'] ??
                      b['available_quantity'] ??
                      b['totalQuantity'] ??
                      b['total_quantity'],
                ) >
                0.001;
          })
          .map((b) => Map<String, dynamic>.from(b))
          .toList();

      final whs = (results[2] as List)
          .map((w) => Map<String, dynamic>.from(w))
          .toList();

      setState(() {
        _batches = allBatches;
        _externalBatches = ext;
        // Deduplicate warehouses by ID
        final uniqueWhs = <String, Map<String, dynamic>>{};
        for (final w in whs) {
          final id = w['id']?.toString() ?? '';
          if (id.isNotEmpty) uniqueWhs[id] = w;
        }
        _warehouses = uniqueWhs.values.toList();

        _loading = false;
        if (_warehouses.isNotEmpty) {
          _warehouseId =
              _warehouses.firstWhere(
                (w) => w['isDefault'] == true,
                orElse: () => _warehouses.first,
              )['id'] ??
              '';
        }
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_kDraftKey);
      if (json != null && json.isNotEmpty) {
        final list = (jsonDecode(json) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (mounted && list.isNotEmpty) {
          setState(() {
            _serialRows = list;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDraftKey, jsonEncode(_serialRows));
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kDraftKey);
    } catch (_) {}
  }

  void _onSourceChanged(String? id) {
    setState(() {
      _sourceBatchId = id ?? '';
      final b = _sourceBatch;
      if (b != null) {
        _inputWeight = _sourceAvailable;
        _bagCount = (_inputWeight / _packageWeight).floor();
        _inputCtrl.text = _inputWeight.toString();
        _bagCtrl.text = _bagCount.toString();
        _recalculateSurplus();
      }
    });
    _fetchBatchCode();
  }

  Future<void> _fetchBatchCode() async {
    final addr =
        _selectedProvinceCode ??
        _sourceBatch?['sourceInfo']?['production_address'] ??
        '';
    try {
      final code = await ref
          .read(supplyRepositoryProvider)
          .getNextSemiFinishedBatchCode(addr);
      if (mounted) {
        setState(() => _expectedBatchCode = code);
        if (!_customBatchCode) {
          _batchCodeCtrl.text = code;
        }
      }
    } catch (_) {}
  }

  void _showError(String msg) {
    setState(() => _error = msg);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _onSerialScanned(String code) async {
    final serialCode = _extractCode(code);
    setState(() => _error = null);

    if (_linkToPallet && _selectedPallet == null) {
      if (serialCode.toUpperCase().startsWith('PLT') || serialCode.toUpperCase().startsWith('SFPLT')) {
        try {
          final pallets = await ref.read(supplyRepositoryProvider).getSFPallets(search: serialCode);
          if (pallets.isEmpty) {
            _showError('Không tìm thấy Pallet: $serialCode');
            return;
          }
          setState(() {
            _selectedPallet = Map<String, dynamic>.from(pallets.first);
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã chọn Pallet: ${_selectedPallet!['palletCode'] ?? serialCode}'), backgroundColor: _kPrimary));
        } catch (e) {
          _showError('Lỗi tìm pallet: $e');
        }
      } else {
        _showError('Vui lòng quét hoặc nhập mã Pallet trước.');
      }
      return;
    }

    if (_bagCount <= 0) {
      _showError('Vui lòng nhập số bao trước.');
      return;
    }
    if (_serialRows.length >= _bagCount) {
      _showError('Đã đủ $_bagCount bao. Không thể thêm thêm.');
      return;
    }
    if (_serialRows.any((r) => r['serialNumber'] == serialCode)) {
      _showError('Mã $serialCode đã có trong danh sách.');
      return;
    }

    setState(() => _error = null);

    try {
      final results = await ref.read(supplyRepositoryProvider).lookupSerials([
        serialCode,
      ]);
      if (results.isEmpty) {
        _showError('Mã không tồn tại trong kho mã.');
        return;
      }
      final item = Map<String, dynamic>.from(results.first);
      if (item['status'] != 'AVAILABLE') {
        String statusVi = item['status']?.toString() ?? 'không rõ';
        switch (statusVi) {
          case 'SOLD': statusVi = 'đã bán'; break;
          case 'IN_STOCK': statusVi = 'đang lưu kho'; break;
          case 'PACKAGED': statusVi = 'đã đóng gói'; break;
          case 'EXPORTED': statusVi = 'đã xuất kho'; break;
          case 'DESTROYED': statusVi = 'đã hủy'; break;
        }
        _showError('Mã ${item['serialNumber']} không khả dụng. Trạng thái hiện tại: $statusVi');
        return;
      }
      if (_serialRows.any((r) => r['serialNumber'] == item['serialNumber'])) {
        _showError('Mã ${item['serialNumber']} đã có trong danh sách.');
        return;
      }

      setState(() {
        _serialRows.insert(0, item);
        if (_serialRows.length == _bagCount) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã quét đủ số bao'),
              backgroundColor: _kPrimary,
            ),
          );
        }
      });
      _saveDraft();
    } catch (e) {
      _showError('Lỗi kiểm tra mã: $e');
    }
  }

  void _removeSerial(String serial) {
    setState(() => _serialRows.removeWhere((r) => r['serialNumber'] == serial));
    _saveDraft();
  }

  Future<void> _submit() async {
    final batch = _sourceBatch;
    if (batch == null) return _setError('Chọn lô nguồn.');
    if (batch['productId'] == null && batch['product_id'] == null)
      return _setError('Lô nguồn chưa có sản phẩm.');
    if (_warehouseId.isEmpty) return _setError('Chọn kho lưu trữ.');
    if (_inputWeight <= 0 || _inputWeight > _sourceAvailable)
      return _setError('Khối lượng trích xuất không hợp lệ.');
    if (_outputWeight <= 0 || _outputWeight > _inputWeight)
      return _setError('Khối lượng đầu ra không hợp lệ.');
    if (_actualSurplus < 0 || (_computedSurplus > 0 && _actualSurplus > _computedSurplus))
      return _setError('Khối lượng dư thừa thực tế không hợp lệ.');
    if (_serialRows.length != _bagCount)
      return _setError(
        'Số mã (${_serialRows.length}) chưa khớp số bao ($_bagCount).',
      );

    setState(() {
      _saving = true;
      _error = null;
    });

    final authState = ref.read(authControllerProvider);
    final user = authState.value;

    try {
      await ref.read(supplyRepositoryProvider).refineSemiFinished({
        'source_batch_code': batch['batchCode'] ?? batch['batch_code'],
        'product_id': batch['productId'] ?? batch['product_id'],
        'input_weight': _inputWeight,
        'output_weight': _outputWeight,
        'production_address': _selectedProvinceCode ?? '',
        'serials': _serialRows.map((r) => r['serialNumber']).toList(),
        'expected_code': _expectedBatchCode,
        'custom_batch_code': _customBatchCode ? _batchCodeCtrl.text : null,
        'packer': user?.fullName ?? user?.username ?? '',
        'warehouse_id': _warehouseId,
        'packaging_date': DateTime.now().toIso8601String(),
        'package_weight': _packageWeight,
        'actual_surplus_kg': _computedSurplus > 0 ? _actualSurplus : null,
      });

      if (_linkToPallet && _selectedPallet != null) {
        final palletId = _selectedPallet!['id'].toString();
        int successCount = 0;
        for (final row in _serialRows) {
          try {
            await ref.read(supplyRepositoryProvider).linkBagToSFPallet(
              palletId,
              row['serialNumber'],
            );
            successCount++;
          } catch (e) {
            print('Error linking ${row['serialNumber']}: $e');
          }
        }
        if (successCount < _serialRows.length) {
          _setError('Tạo lô thành công, nhưng lỗi liên kết pallet một số bao.');
        }
      }

      await _clearDraft();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đóng gói thành công'),
            backgroundColor: _kPrimary,
          ),
        );
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      final msg = e.response?.data['message'] ?? e.response?.data['error'] ?? e.toString();
      _setError(msg.toString());
    } catch (e) {
      _setError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _setError(String msg) => setState(() => _error = msg);

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _fmtKg(double v) =>
      '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)} kg';

  String _extractCode(String raw) {
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasQuery) {
      final code = uri.queryParameters['Code'] ?? uri.queryParameters['code'];
      if (code != null && code.trim().isNotEmpty) return code.trim();
    }
    if (trimmed.contains('=')) {
      return trimmed.substring(trimmed.lastIndexOf('=') + 1).trim();
    }
    return trimmed;
  }

  String _batchLabel(Map<String, dynamic> b) {
    final code = b['batchCode'] ?? b['batch_code'] ?? '';
    final product = b['product']?['name'] ?? '';
    return '$code${product.isNotEmpty ? ' - $product' : ''}';
  }

  Future<bool> _handleBack() async {
    if (_serialRows.isEmpty) return true;

    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        title: const Text(
          'Hủy bỏ đóng gói?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'Dữ liệu đã quét sẽ bị xóa. Bạn có chắc chắn muốn thoát?',
          style: TextStyle(color: _kGray, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tiếp tục quét', style: TextStyle(color: _kGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hủy & Thoát'),
          ),
        ],
      ),
    );

    if (discard == true) {
      await _clearDraft();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBack();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          title: const Text(
            'Đóng gói Bán thành phẩm',
            style: TextStyle(
              color: _kText,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          backgroundColor: _kBg,
          elevation: 0,
          iconTheme: const IconThemeData(color: _kGray),
        ),
        body: _loading
            ? const SkeletonForm()
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) _ErrorBox(message: _error!),

                    // === STEP 1-3: Config (Collapsible) ===
                    if (!_isCollapsed) ...[
                      _SectionHeader(step: 1, title: 'Lô nguồn'),
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              value:
                                  (_sourceBatchId.isNotEmpty &&
                                      [
                                        ..._batches,
                                        ..._externalBatches,
                                      ].any((b) => b['id'] == _sourceBatchId))
                                  ? _sourceBatchId
                                  : null,
                              decoration: _inputDeco('Chọn lô nguồn'),
                              dropdownColor: _kSurface,
                              style: const TextStyle(
                                color: _kText,
                                fontSize: 14,
                              ),
                              isExpanded: true,
                              menuMaxHeight: 300,
                              items: (() {
                                final unique = <String, Map<String, dynamic>>{};
                                for (final b in [
                                  ..._batches,
                                  ..._externalBatches,
                                ]) {
                                  final id = b['id']?.toString() ?? '';
                                  if (id.isNotEmpty) unique[id] = b;
                                }
                                return unique.values
                                    .map(
                                      (b) => DropdownMenuItem(
                                        value: b['id'] as String,
                                        child: Text(
                                          _batchLabel(b),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList();
                              })(),
                              onChanged: _onSourceChanged,
                            ),
                            if (_sourceBatch != null) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _Badge(
                                    'Tồn: ${_fmtKg(_sourceAvailable)}',
                                    _kPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  if (_expectedBatchCode.isNotEmpty)
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: _batchCodeCtrl,
                                              style: const TextStyle(
                                                color: _kText,
                                                fontFamily: 'monospace',
                                                fontSize: 13,
                                              ),
                                              decoration: _inputDeco('Mã lô').copyWith(
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                              ),
                                              onChanged: (v) {
                                                _customBatchCode = v != _expectedBatchCode;
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          InkWell(
                                            onTap: () {
                                              _customBatchCode = false;
                                              _fetchBatchCode();
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: _kBg,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                                              ),
                                              child: const Icon(Icons.autorenew, color: _kPrimary, size: 18),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      _SectionHeader(step: 2, title: 'Định lượng'),
                      _Card(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _NumberField(
                                    label: 'Khối lượng trích xuất (kg)',
                                    controller: _inputCtrl,
                                    onChanged: (v) => setState(() {
                                      _inputWeight = v;
                                      _bagCount =
                                          (_inputWeight / _packageWeight)
                                              .floor();
                                      _bagCtrl.text = _bagCount.toString();
                                      _recalculateSurplus();
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Quy cách (kg/bao)',
                                        style: TextStyle(
                                          color: _kGray,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<int>(
                                        value: _packageWeight.toInt(),
                                        decoration: _inputDeco(null),
                                        dropdownColor: _kSurface,
                                        style: const TextStyle(
                                          color: _kText,
                                          fontSize: 14,
                                        ),
                                        items: _packageWeightOptions
                                            .map(
                                              (w) => DropdownMenuItem(
                                                value: w,
                                                child: Text('$w kg'),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (v) => setState(() {
                                          _packageWeight = (v ?? 50).toDouble();
                                          _bagCount =
                                              (_inputWeight / _packageWeight)
                                                  .floor();
                                          _bagCtrl.text = _bagCount.toString();
                                          _recalculateSurplus();
                                        }),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _NumberField(
                                    label: 'Số bao',
                                    controller: _bagCtrl,
                                    isInt: true,
                                    onChanged: (v) =>
                                        setState(() {
                                          _bagCount = v.toInt();
                                          _recalculateSurplus();
                                        }),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Output',
                                        style: TextStyle(
                                          color: _kGray,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _kBg,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.1,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          _fmtKg(_outputWeight),
                                          style: const TextStyle(
                                            color: _kText,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (_computedSurplus > 0) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.amber.withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline,
                                          color: Colors.amber,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'KHỐI LƯỢNG DƯ THỬA SAU SƠ CHẾ',
                                          style: TextStyle(
                                            color: Colors.amber,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Tự động tính = Input - Output',
                                            style: TextStyle(
                                              color: Colors.amber,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final isWide = constraints.maxWidth > 550;
                                        
                                        final col1 = Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'KL dư (tự tính)',
                                              style: TextStyle(
                                                color: _kGray,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.amber.withOpacity(0.2)),
                                              ),
                                              child: Text(
                                                _fmtKg(_computedSurplus),
                                                style: const TextStyle(
                                                  color: Colors.amber,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );

                                        final col2 = _NumberField(
                                          label: 'KL dư thực tế (kg)',
                                          controller: _surplusCtrl,
                                          onChanged: (v) => setState(() {
                                            _actualSurplus = v;
                                          }),
                                        );

                                        final col3 = Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Hao hụt sơ chế',
                                              style: TextStyle(
                                                color: _kGray,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent.withOpacity(0.05),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                                              ),
                                              child: Text(
                                                '${_fmtKg((_computedSurplus - _actualSurplus).clamp(0.0, double.infinity))} (${_lossPercent.toStringAsFixed(2)}%)',
                                                style: const TextStyle(
                                                  color: Colors.redAccent,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );

                                        if (isWide) {
                                          return Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(child: col1),
                                              const SizedBox(width: 10),
                                              Expanded(child: col2),
                                              const SizedBox(width: 10),
                                              Expanded(child: col3),
                                            ],
                                          );
                                        } else {
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              col1,
                                              const SizedBox(height: 10),
                                              col2,
                                              const SizedBox(height: 10),
                                              col3,
                                            ],
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '* KL dư thực tế sẽ được ghi nhận vào "Kho dư" để có thể tái sử dụng cho lần đóng gói tiếp theo. Phần chênh lệch = hao hụt sơ chế.',
                                      style: TextStyle(
                                        color: Colors.amber.shade700,
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            StatBoxRow(
                              items: [
                                StatItem(
                                  label: 'QUY ĐỔI',
                                  value: _fmtKg(_inputWeight),
                                ),
                                StatItem(
                                  label: 'OUTPUT',
                                  value: _fmtKg(_outputWeight),
                                ),
                                StatItem(
                                  label: 'DƯ THỬA',
                                  value: _fmtKg(_actualSurplus),
                                  color: Colors.amber,
                                ),
                                StatItem(
                                  label: 'HAO HỤT',
                                  value: '${_lossPercent.toStringAsFixed(2)}%',
                                  color: _lossPercent > 5
                                      ? Colors.redAccent
                                      : _kPrimary,
                                ),
                                StatItem(
                                  label: 'TỔNG BAO',
                                  value: '$_bagCount bao',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      _SectionHeader(step: 3, title: 'Thông tin đóng gói'),
                      _Card(
                        child: Column(
                          children: [
                            ProvinceSelector(
                              selectedProvinceName: _selectedProvinceName,
                              onSelected: (p) {
                                setState(() {
                                  _selectedProvinceName = p.name;
                                  _selectedProvinceCode = p.code;
                                });
                                _fetchBatchCode();
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value:
                                  (_warehouseId.isNotEmpty &&
                                      _warehouses.any(
                                        (w) => w['id'] == _warehouseId,
                                      ))
                                  ? _warehouseId
                                  : null,
                              decoration: _inputDeco('Kho lưu trữ'),
                              dropdownColor: _kSurface,
                              style: const TextStyle(
                                color: _kText,
                                fontSize: 14,
                              ),
                              isExpanded: true,
                              menuMaxHeight: 300,
                              items: _warehouses
                                  .map(
                                    (w) => DropdownMenuItem(
                                      value: w['id'] as String,
                                      child: Text(
                                        w['name'] ?? '',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _warehouseId = v ?? ''),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Summary when collapsed
                      _Card(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _sourceBatch != null
                                            ? _batchLabel(_sourceBatch!)
                                            : 'Chưa chọn lô',
                                        style: const TextStyle(
                                          color: _kText,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_expectedBatchCode.isEmpty ? 'Mã dự kiến' : _expectedBatchCode} | ${_fmtKg(_outputWeight)} ($_bagCount bao)',
                                        style: const TextStyle(
                                          color: _kGray,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () =>
                                      setState(() => _isCollapsed = false),
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: _kPrimary,
                                  ),
                                  label: const Text(
                                    'Sửa',
                                    style: TextStyle(
                                      color: _kPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    // === Pallet Linking Toggle ===
                    const SizedBox(height: 12),
                    _Card(
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Gắn Pallet khi đóng gói', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        subtitle: const Text('Liên kết bao với Pallet trong lúc quét', style: TextStyle(color: _kGray, fontSize: 12)),
                        value: _linkToPallet,
                        activeColor: _kPrimary,
                        checkColor: Colors.white,
                        onChanged: (v) {
                          setState(() {
                            _linkToPallet = v ?? false;
                            if (!_linkToPallet) _selectedPallet = null;
                          });
                        },
                        secondary: const Icon(Icons.settings, color: _kGray),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    if (_linkToPallet)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _selectedPallet == null ? Colors.transparent : _kSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _selectedPallet == null ? Colors.redAccent : _kPrimary,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Pallet hoạt động', style: TextStyle(color: _kGray, fontSize: 12, fontWeight: FontWeight.w600)),
                                if (_selectedPallet != null)
                                  Text('${_serialRows.length} / ${_selectedPallet!['capacity'] ?? '10'} bao', style: const TextStyle(color: _kPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_selectedPallet == null)
                              Row(
                                children: [
                                  const Icon(Icons.warning, color: Colors.amber, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'CHƯA CHỌN PALLET. QUÉT MÃ PALLET TRƯỚC.',
                                      style: TextStyle(color: Colors.red[300], fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, fontSize: 12),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedPallet!['palletCode'] ?? _selectedPallet!['pallet_code'] ?? '',
                                      style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => setState(() => _selectedPallet = null),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _kText,
                                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                    child: const Text('Đổi'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),

                    // === STEP 4: Serial Assignment ===
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Serial bao',
                                style: TextStyle(
                                  color: _kText,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              _Badge(
                                '${_serialRows.length}/$_bagCount',
                                _serialRows.length == _bagCount && _bagCount > 0
                                    ? _kPrimary
                                    : _serialRows.length > _bagCount
                                    ? Colors.redAccent
                                    : Colors.orange,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _manualSerialController,
                                  focusNode: _scanFocus,
                                  enabled: true,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: (_linkToPallet && _selectedPallet == null) ? '⚠️ QUÉT MÃ PALLET TRƯỚC' : 'Nhập/Quét serial bao',
                                    hintStyle: TextStyle(color: (_linkToPallet && _selectedPallet == null) ? Colors.red[300] : _kGray),
                                    filled: true,
                                    fillColor: _kBg,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: (_linkToPallet && _selectedPallet == null) ? Colors.redAccent : Colors.transparent,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: (_linkToPallet && _selectedPallet == null) ? Colors.redAccent : Colors.transparent,
                                      ),
                                    ),
                                  ),
                                  onFieldSubmitted: (val) {
                                    if (val.trim().isNotEmpty) {
                                      _onSerialScanned(val.trim());
                                      _manualSerialController.clear();
                                      _scanFocus.requestFocus();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  final val = _manualSerialController.text.trim();
                                  if (val.isNotEmpty) {
                                    _onSerialScanned(val);
                                    _manualSerialController.clear();
                                    _scanFocus.requestFocus();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _kPrimary.withOpacity(0.2),
                                  foregroundColor: _kPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: (_linkToPallet && _selectedPallet == null) ? Colors.redAccent.withOpacity(0.5) : _kPrimary),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                child: Text('Thêm', style: TextStyle(fontWeight: FontWeight.bold, color: (_linkToPallet && _selectedPallet == null) ? Colors.grey : _kPrimary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Serial list
                          if (_serialRows.isNotEmpty) ...[
                            if (_serialRows.length > _bagCount)
                              Container(
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.redAccent.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  'Đang vượt ${_serialRows.length - _bagCount} mã. Xóa bớt trước khi lưu.',
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ..._serialRows
                                .take(50)
                                .map(
                                  (r) => Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _kBg,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.06),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                r['serialNumber'] ?? '',
                                                style: const TextStyle(
                                                  color: _kText,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              if (r['fullQrCode'] != null)
                                                Text(
                                                  r['fullQrCode'],
                                                  style: const TextStyle(
                                                    color: _kGray,
                                                    fontSize: 10,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () =>
                                              _removeSerial(r['serialNumber']),
                                          icon: const Icon(
                                            Icons.close,
                                            color: Colors.redAccent,
                                            size: 18,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          ],
                        ],
                      ),
                    ),
                    
                    if (_selectedPallet != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 12, bottom: 20),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _kBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _kPrimary.withOpacity(0.5)),
                        ),
                        child: Text(
                          'Đã chọn pallet BTP ${_selectedPallet!['palletCode'] ?? _selectedPallet!['pallet_code'] ?? ''}',
                          style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      
                    const SizedBox(height: 20),
                  ],
                ),
              ),
        bottomNavigationBar: _loading
            ? null
            : Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  MediaQuery.of(context).padding.bottom + 10,
                ),
                decoration: BoxDecoration(
                  color: _kBg,
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                ),
                child: Row(
                  children: [
                    // Quay lại
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _kText,
                            side: const BorderSide(color: _kPrimary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Quay lại', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Quét bao
                    Expanded(
                      flex: 5,
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => _openCameraScanner(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 8,
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_scanner, size: 20),
                              SizedBox(height: 2),
                              Text('Quét bao', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Lưu lại
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Lưu lại', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  InputDecoration _inputDeco(String? label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: _kGray),
    filled: true,
    fillColor: _kBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _kPrimary),
    ),
  );

  Future<void> _openCameraScanner() async {
    final String? result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const ScannerScreen(
          title: 'Quét mã bao',
          returnCode: true,
        ),
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      _onSerialScanned(result);
    }
  }
}

class _CameraScannerSheet extends StatefulWidget {
  final ValueChanged<String> onDetect;
  const _CameraScannerSheet({required this.onDetect});

  @override
  State<_CameraScannerSheet> createState() => _CameraScannerSheetState();
}

class _CameraScannerSheetState extends State<_CameraScannerSheet> {
  bool _detected = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Stack(
          children: [
            MobileScanner(
              onDetect: (capture) {
                if (_detected) return;
                final barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                  _detected = true;
                  widget.onDetect(barcodes.first.rawValue!);
                }
              },
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const Center(
              child: CustomPaint(
                size: Size(250, 250),
                painter: ScannerOverlayPainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  const ScannerOverlayPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    final path = Path();
    final double w = size.width;
    final double h = size.height;
    final double l = 30.0;
    path.moveTo(0, l);
    path.lineTo(0, 0);
    path.lineTo(l, 0);
    path.moveTo(w - l, 0);
    path.lineTo(w, 0);
    path.lineTo(w, l);
    path.moveTo(w, h - l);
    path.lineTo(w, h);
    path.lineTo(w - l, h);
    path.moveTo(l, h);
    path.lineTo(0, h);
    path.lineTo(0, h - l);
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- Shared helper widgets ---

class _SectionHeader extends StatelessWidget {
  final int step;
  final String title;
  const _SectionHeader({required this.step, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _kPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$step',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: _kText,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: child,
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isInt;
  final ValueChanged<double> onChanged;

  const _NumberField({
    required this.label,
    required this.controller,
    this.isInt = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _kGray,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
          style: const TextStyle(color: _kText, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: _kBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kPrimary),
            ),
          ),
          onChanged: (v) => onChanged(double.tryParse(v) ?? 0),
        ),
      ],
    );
  }
}
