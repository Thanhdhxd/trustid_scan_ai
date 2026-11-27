import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trustid_scan_ai/core/utils/app_toast.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';
import 'package:trustid_scan_ai/core/utils/scan_feedback_helper.dart';
import 'package:trustid_scan_ai/scan/scanner_screen.dart';
import '../data/supply_repository.dart';
import '../domain/production_order.dart';
import '../domain/production_ticket.dart';
import 'order_list_screen.dart';
import 'production_order/constants/prod_order_constants.dart';
import 'production_order/constants/prod_order_helpers.dart';
import 'production_order/dialogs/standard_ticket_dialogs.dart';

/// Màn hình thực thi Đóng gói Tiêu chuẩn theo Lệnh Sản Xuất (`STANDARD` — `ProductionTicket`).
/// Không sử dụng Offline Queue: mọi lượt quét đồng bộ trực tiếp lên Backend để nhiều công nhân quét song song an toàn.
class StandardPackagingScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String? initialTicketId;

  const StandardPackagingScreen({
    super.key,
    required this.orderId,
    this.initialTicketId,
  });

  @override
  ConsumerState<StandardPackagingScreen> createState() =>
      _StandardPackagingScreenState();
}

class _StandardPackagingScreenState
    extends ConsumerState<StandardPackagingScreen> {
  static const int _pageWindowSize = 30;

  final _scanController = TextEditingController();
  late final FocusNode _scanFocusNode;

  ProductionOrder? _order;
  ProductionTicket? _ticket;
  List<ProductionTicketScan> _scans = [];
  int _scannedCount = 0;
  double _scannedWeightKg = 0.0;
  int _visibleLimit = _pageWindowSize;

  bool _isLoading = true;
  bool _isScanning = false;
  bool _isSubmittingAction = false;
  bool _hideKeyboard = false;
  Timer? _pdaDebounceTimer;

  bool get _isEditable {
    final tStatus = _ticket?.status ?? '';
    final oStatus = _order?.status ?? 'IN_PROGRESS';
    return (tStatus == 'OPEN' || tStatus == 'IN_PROGRESS') &&
        (oStatus == 'CODES_READY' || oStatus == 'IN_PROGRESS' || oStatus == 'APPROVED');
  }

  @override
  void initState() {
    super.initState();
    _scanFocusNode = FocusNode(
      debugLabel: 'standardScanFocusNode',
      onKeyEvent: (node, event) {
        if (!_hideKeyboard || event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
          if (_scanController.text.trim().isNotEmpty) {
            _handleTextScan();
          }
          return KeyEventResult.handled;
        } else if (key == LogicalKeyboardKey.backspace) {
          if (_scanController.text.isNotEmpty) {
            final next = _scanController.text.substring(0, _scanController.text.length - 1);
            _scanController.value = TextEditingValue(
              text: next,
              selection: TextSelection.collapsed(offset: next.length),
            );
          }
          return KeyEventResult.handled;
        } else if (event.character != null && event.character!.isNotEmpty) {
          if (event.character == '\n' || event.character == '\r') {
            if (_scanController.text.trim().isNotEmpty) {
              _handleTextScan();
            }
          } else {
            final next = _scanController.text + event.character!;
            _scanController.value = TextEditingValue(
              text: next,
              selection: TextSelection.collapsed(offset: next.length),
            );
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );
    _scanFocusNode.addListener(_onFocusChange);
    _loadPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadInitialData();
    });
  }

  @override
  void dispose() {
    _scanFocusNode.removeListener(_onFocusChange);
    _pdaDebounceTimer?.cancel();
    _scanController.dispose();
    _scanFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_hideKeyboard) return;
    if (_scanFocusNode.hasFocus) {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      return;
    }
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted &&
            _hideKeyboard &&
            !_scanFocusNode.hasFocus &&
            _scanFocusNode.canRequestFocus) {
          if (route.isCurrent && _isEditable) {
            _scanFocusNode.requestFocus();
            SystemChannels.textInput.invokeMethod('TextInput.hide');
          }
        }
      });
    }
  }

  void _refocus() {
    if (!_hideKeyboard) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _hideKeyboard && _isEditable && _scanFocusNode.canRequestFocus) {
        _scanFocusNode.requestFocus();
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      }
    });
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() => _hideKeyboard = prefs.getBool('hide_keyboard_pda') ?? false);
      }
    } catch (_) {}
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final repo = ref.read(supplyRepositoryProvider);
    try {
      String? targetTicketId = widget.initialTicketId;
      Map<String, dynamic>? ticketMap;
      Map<String, dynamic>? orderMap;

      if (targetTicketId == null || targetTicketId.isEmpty) {
        final res = await repo.getOrCreateProductionTicket(widget.orderId);
        if (res['ticket'] is Map) {
          ticketMap = Map<String, dynamic>.from(res['ticket'] as Map);
          targetTicketId = ticketMap['id']?.toString();
        } else if (res['id'] != null) {
          ticketMap = res;
          targetTicketId = res['id'].toString();
        }
        if (res['order'] is Map) {
          orderMap = Map<String, dynamic>.from(res['order'] as Map);
        }
      }

      if (targetTicketId != null && targetTicketId.isNotEmpty) {
        final results = await Future.wait([
          repo.getTicketDetail(targetTicketId),
          repo.getProductionOrderDetail(widget.orderId).catchError((_) => orderMap ?? <String, dynamic>{}),
        ]);
        ticketMap = results[0];
        if (results[1].isNotEmpty) {
          orderMap = results[1];
        }
      }

      if (!mounted) return;
      if (ticketMap == null || ticketMap.isEmpty) {
        AppToast.error(context, 'Không tải được thông tin phiếu đóng gói.');
        Navigator.of(context).pop();
        return;
      }

      _applyTicketAndOrder(ticketMap, orderMap);
      setState(() => _isLoading = false);
      _refocus();
    } catch (e) {
      final err = parseSupplyHttpError(e);
      if (!mounted) return;
      if (err.isForbidden) {
        AppToast.error(
          context,
          err.message.isNotEmpty
              ? err.message
              : 'Chưa có phiếu đang mở, liên hệ quản lý tạo phiếu.',
        );
        Navigator.of(context).pop();
        return;
      }
      setState(() => _isLoading = false);
      AppToast.error(context, err.message);
      if (err.isNotFound) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _syncTicketAndOrder() async {
    final ticketId = _ticket?.id ?? widget.initialTicketId;
    if (ticketId == null || ticketId.isEmpty) return;
    try {
      final repo = ref.read(supplyRepositoryProvider);
      final results = await Future.wait([
        repo.getTicketDetail(ticketId),
        repo.getProductionOrderDetail(widget.orderId).catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      setState(() {
        _applyTicketAndOrder(
          results[0],
          results[1].isNotEmpty ? results[1] : null,
        );
      });
    } catch (_) {}
  }

  void _applyTicketAndOrder(
    Map<String, dynamic> ticketJson,
    Map<String, dynamic>? orderJson,
  ) {
    final parsedTicket = ProductionTicket.fromJson(ticketJson);
    final embeddedOrder = ticketJson['order'] is Map
        ? Map<String, dynamic>.from(ticketJson['order'] as Map)
        : null;
    final resolvedOrderMap = orderJson ?? embeddedOrder;
    final parsedOrder =
        resolvedOrderMap != null ? ProductionOrder.fromJson(resolvedOrderMap) : _order;

    final sortedScans = List<ProductionTicketScan>.from(parsedTicket.scannedSerials)
      ..sort((a, b) => (b.scannedAt ?? DateTime(0)).compareTo(a.scannedAt ?? DateTime(0)));

    final unitW = parsedOrder?.unitWeightKg ?? 1.0;
    _ticket = parsedTicket;
    _order = parsedOrder;
    _scans = sortedScans;
    _scannedCount = parsedTicket.scannedUnits > 0 ? parsedTicket.scannedUnits : sortedScans.length;
    _scannedWeightKg = parsedTicket.scannedWeightKg > 0
        ? parsedTicket.scannedWeightKg
        : (_scannedCount * unitW);
  }

  Future<void> _handleTextScan() async {
    if (_isScanning || !_isEditable) return;
    _pdaDebounceTimer?.cancel();

    final raw = _scanController.text.trim();
    if (raw.isEmpty) return;

    final tokens = raw
        .split(RegExp(r'[\s,]+'))
        .map(extractSerialCodeFromQr)
        .where((e) => e.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return;

    _scanController.clear();
    if (tokens.length == 1) {
      await _processSingleScan(tokens.first);
    } else {
      await _processBatchScans(tokens);
    }
    _refocus();
  }

  Future<void> _processSingleScan(String code) async {
    final ticketId = _ticket?.id;
    if (ticketId == null || ticketId.isEmpty || _isScanning || !_isEditable) return;

    setState(() => _isScanning = true);
    try {
      final res = await ref.read(supplyRepositoryProvider).scanTicketSerial(ticketId, code);
      ScanFeedbackHelper.playSuccess();

      if (!mounted) return;
      final scanMap = res['scan'] is Map ? Map<String, dynamic>.from(res['scan'] as Map) : null;
      setState(() {
        if (scanMap != null) {
          final newScan = ProductionTicketScan.fromJson(scanMap);
          _scans.removeWhere((s) => s.serialNumber == newScan.serialNumber);
          _scans.insert(0, newScan);
        }
        final unitW = _order?.unitWeightKg ?? 1.0;
        _scannedCount = int.tryParse(res['scannedCount']?.toString() ?? '') ?? _scans.length;
        _scannedWeightKg =
            double.tryParse(res['scannedWeightKg']?.toString() ?? '') ?? (_scannedCount * unitW);
        if (res['ticketStatus'] != null && _ticket != null) {
          _ticket = ProductionTicket(
            id: _ticket!.id,
            ticketCode: _ticket!.ticketCode,
            orderId: _ticket!.orderId,
            ticketType: _ticket!.ticketType,
            status: res['ticketStatus'].toString().toUpperCase(),
            operatorId: _ticket!.operatorId,
            operatorName: _ticket!.operatorName,
            plannedWeightKg: _ticket!.plannedWeightKg,
            actualWeightKg: _ticket!.actualWeightKg,
            actualUnits: _ticket!.actualUnits,
            scannedUnits: _scannedCount,
            scannedWeightKg: _scannedWeightKg,
            outputBatchId: _ticket!.outputBatchId,
            mfgDate: _ticket!.mfgDate,
            expiryDate: _ticket!.expiryDate,
            createdAt: _ticket!.createdAt,
            scannedSerials: _scans,
          );
        }
      });

      AppToast.success(context, 'Đã quét mã $code ($_scannedCount gói)');
    } catch (e) {
      ScanFeedbackHelper.playError();
      final err = parseSupplyHttpError(e);
      if (!mounted) return;

      AppToast.error(context, err.message);

      if (err.isBadRequest || err.isNotFound || err.isConflict) {
        await _syncTicketAndOrder();
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _processBatchScans(List<String> codes) async {
    final ticketId = _ticket?.id;
    if (ticketId == null || ticketId.isEmpty) return;
    setState(() => _isScanning = true);
    int added = 0;
    try {
      final repo = ref.read(supplyRepositoryProvider);
      for (final code in codes) {
        await repo.scanTicketSerial(ticketId, code);
        added++;
      }
      ScanFeedbackHelper.playSuccess();
      if (mounted) {
        AppToast.success(context, 'Đã quét $added mã gói.');
      }
    } catch (e) {
      ScanFeedbackHelper.playError();
      if (mounted) {
        AppToast.error(
          context,
          added > 0
              ? 'Đã thêm $added mã trước khi gặp lỗi: ${parseSupplyHttpError(e).message}'
              : parseSupplyHttpError(e).message,
        );
      }
    } finally {
      await _syncTicketAndOrder();
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _unscanSerial(ProductionTicketScan scan) async {
    final ticketId = _ticket?.id;
    if (ticketId == null || !_isEditable) return;
    try {
      await ref
          .read(supplyRepositoryProvider)
          .unscanTicketSerial(ticketId, scan.serialNumber);
      if (!mounted) return;
      final unitW = _order?.unitWeightKg ?? 1.0;
      setState(() {
        _scans.removeWhere((s) => s.serialNumber == scan.serialNumber);
        _scannedCount = _scans.length;
        _scannedWeightKg = _scannedCount * unitW;
      });
      AppToast.info(context, 'Đã gỡ mã ${scan.serialNumber}.');
    } catch (e) {
      final err = parseSupplyHttpError(e);
      if (mounted) AppToast.error(context, err.message);
      await _syncTicketAndOrder();
    }
  }

  Future<void> _onTapComplete() async {
    final ticket = _ticket;
    if (ticket == null) return;
    if (_scans.isEmpty && _scannedCount == 0) {
      AppToast.warning(context, 'Phiếu chưa có mã gói. Vui lòng quét ít nhất 1 mã.');
      return;
    }

    setState(() => _isSubmittingAction = true);
    await _syncTicketAndOrder();
    if (!mounted) return;
    setState(() => _isSubmittingAction = false);

    final order = _order;
    final unitW = order?.unitWeightKg ?? 1.0;
    final totalActive = order?.summary?.activeScannedPackets ?? _scannedCount;
    final otherPackets = math.max(0, totalActive - _scannedCount);
    final otherWeightKg = otherPackets * unitW;

    final maxAllowedWeight = (order != null && order.plannedWeightKg > 0)
        ? math.max(0.1, order.plannedWeightKg - order.actualWeightKg - otherWeightKg)
        : 999999.0;
    final estimatedWeight =
        _scannedWeightKg > 0 ? _scannedWeightKg : (_scannedCount * unitW);

    final input = await showCompleteStandardTicketDialog(
      context,
      ticketCode: ticket.ticketCode,
      packetCount: _scannedCount,
      unitWeightKg: unitW,
      initialWeightKg: math.min(estimatedWeight, maxAllowedWeight),
      maxAllowedWeightKg: maxAllowedWeight,
      warehouseName: order?.warehouseName ?? 'Theo kho Lệnh SX',
      batchCode: order?.outputBatchCode ?? order?.orderCode ?? '—',
      initialMfgDate: order?.mfgDate ?? order?.plannedDate,
      initialExpiryDate: order?.expiryDate,
    );
    if (input == null || !mounted) return;

    setState(() => _isSubmittingAction = true);
    try {
      final payload = <String, dynamic>{
        'actual_weight_kg': input.actualWeightKg,
        'serials': _scans.map((s) => s.serialNumber).toList(),
        if (input.mfgDate != null) 'mfg_date': formatProdOrderDateIso(input.mfgDate!),
        if (input.expiryDate != null)
          'expiry_date': formatProdOrderDateIso(input.expiryDate!),
      };
      await ref.read(supplyRepositoryProvider).completeTicket(ticket.id, payload);
      OrderListScreen.clearStaticCache();
      if (!mounted) return;
      AppToast.success(context, 'Đã lưu phiếu đóng gói và nhập kho.');
      Navigator.of(context).pop(true);
    } catch (e) {
      final err = parseSupplyHttpError(e);
      if (mounted) {
        setState(() => _isSubmittingAction = false);
        AppToast.error(context, err.message);
        if (err.isBadRequest || err.isConflict || err.isNotFound) {
          await _syncTicketAndOrder();
        }
      }
    }
  }

  Future<void> _onTapReject() async {
    final ticket = _ticket;
    if (ticket == null) return;
    final reason = await showRejectStandardTicketDialog(
      context,
      ticketCode: ticket.ticketCode,
    );
    if (reason == null || !mounted) return;

    setState(() => _isSubmittingAction = true);
    try {
      await ref.read(supplyRepositoryProvider).rejectTicket(ticket.id, reason);
      OrderListScreen.clearStaticCache();
      if (!mounted) return;
      AppToast.warning(context, 'Đã hủy phiếu ${ticket.ticketCode}.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingAction = false);
        AppToast.error(context, parseSupplyHttpError(e).message);
      }
    }
  }

  Future<void> _showCameraScanner() async {
    if (!_isEditable) return;
    final String? result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const ScannerScreen(
          title: 'Quét mã gói',
          isWarehouseMode: true,
        ),
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      final code = extractSerialCodeFromQr(result);
      if (code.isNotEmpty) {
        await _processSingleScan(code);
      }
    }
    _refocus();
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;
    final order = _order;

    return Scaffold(
      backgroundColor: kProdOrderBg,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                ticket != null ? 'Đóng gói • ${ticket.ticketCode}' : 'Đóng gói Tiêu chuẩn',
                style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold),
              ),
            ),
            if (order != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${order.orderCode} — ${order.productName ?? ''}',
                  style: const TextStyle(color: kProdOrderTextGray, fontSize: 12),
                ),
              ),
          ],
        ),
        backgroundColor: kProdOrderBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: kProdOrderTextGray),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kProdOrderTextGray),
            onPressed: _syncTicketAndOrder,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kProdOrderPrimary))
          : Column(
              children: [
                _buildTicketSummaryHeader(),
                if (_isEditable) _buildScanInputCard(),
                Expanded(child: _buildScannedList()),
              ],
            ),
      bottomNavigationBar: MediaQuery.of(context).viewInsets.bottom > 0 || !_isEditable
          ? null
          : _buildBottomBar(),
    );
  }

  Widget _buildTicketSummaryHeader() {
    final statusColor = prodOrderStatusColor(_ticket?.status ?? 'OPEN');
    final plannedUnits = _order?.plannedUnits ?? 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kProdOrderSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đã quét: $_scannedCount${plannedUnits > 0 ? ' / $plannedUnits' : ''} gói',
                  style: const TextStyle(
                    color: kProdOrderPrimaryLight,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Khối lượng ước tính: ${_scannedWeightKg.toStringAsFixed(2)} kg • Kho: ${_order?.warehouseName ?? '—'}',
                  style: const TextStyle(color: kProdOrderTextGray, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _isEditable ? 'Đang đóng gói' : (_ticket?.status ?? ''),
              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanInputCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kProdOrderSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quét / nhập mã gói (PDA hoặc Camera)',
                style: TextStyle(color: kProdOrderTextGray, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Ẩn bàn phím', style: TextStyle(color: kProdOrderTextGray, fontSize: 11)),
                  const SizedBox(width: 4),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _hideKeyboard,
                      activeThumbColor: kProdOrderPrimary,
                      onChanged: (val) async {
                        setState(() => _hideKeyboard = val);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('hide_keyboard_pda', val);
                        _scanFocusNode.unfocus();
                        _refocus();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _scanController,
                  focusNode: _scanFocusNode,
                  autofocus: true,
                  readOnly: _hideKeyboard,
                  showCursor: true,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  decoration: prodOrderInputDeco(
                    null,
                    hint: 'Quét hoặc nhập mã QR gói...',
                    prefixIcon: const Icon(Icons.qr_code_2, color: kProdOrderPrimaryLight),
                  ),
                  onSubmitted: (_) => _handleTextScan(),
                  onChanged: (value) {
                    _pdaDebounceTimer?.cancel();
                    if (_hideKeyboard) {
                      SystemChannels.textInput.invokeMethod('TextInput.hide');
                    }
                    if (value.contains('\n') || value.contains('\r')) {
                      final clean = value.replaceAll(RegExp(r'[\n\r]'), '').trim();
                      _scanController.value = TextEditingValue(
                        text: clean,
                        selection: TextSelection.collapsed(offset: clean.length),
                      );
                      if (clean.isNotEmpty) _handleTextScan();
                      return;
                    }
                    if (value.trim().isNotEmpty) {
                      final delay = Duration(milliseconds: _hideKeyboard ? 350 : 600);
                      _pdaDebounceTimer = Timer(delay, () {
                        if (mounted &&
                            !_isScanning &&
                            _scanController.text.trim().isNotEmpty) {
                          _handleTextScan();
                        }
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Quét QR bằng Camera',
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: ElevatedButton(
                    onPressed:
                        (_isScanning || _isSubmittingAction) ? null : _showCameraScanner,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kProdOrderPrimary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isScanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.qr_code_scanner, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScannedList() {
    if (_scans.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_2_rounded, size: 60, color: Colors.white12),
            SizedBox(height: 10),
            Text(
              'Chưa có mã gói nào được quét trên phiếu này.',
              style: TextStyle(color: kProdOrderTextGray, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final displayCount = math.min(_scans.length, _visibleLimit);
    final hasMoreLocal = _scans.length > displayCount;

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: displayCount + (hasMoreLocal ? 1 : 0),
      itemBuilder: (ctx, index) {
        if (hasMoreLocal && index == displayCount) {
          return TextButton(
            onPressed: () => setState(() => _visibleLimit += _pageWindowSize),
            child: Text(
              'Xem thêm (${_scans.length - displayCount} mã nữa)',
              style: const TextStyle(color: kProdOrderPrimaryLight),
            ),
          );
        }
        final scan = _scans[index];
        return Card(
          color: kProdOrderSurface,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 15,
              backgroundColor: kProdOrderPrimary.withValues(alpha: 0.18),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: kProdOrderPrimaryLight,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              scan.serialNumber,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
            ),
            subtitle: Text(
              '${scan.scannerName ?? scan.scannerUsername ?? 'Công nhân'} • ${scan.scannedAt != null ? formatProdOrderDate(scan.scannedAt) : ''}',
              style: const TextStyle(color: kProdOrderTextGray, fontSize: 11.5),
            ),
            trailing: _isEditable
                ? IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    tooltip: 'Gỡ mã',
                    onPressed: () => _unscanSerial(scan),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: kProdOrderBg,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _isSubmittingAction ? null : _onTapReject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Hủy phiếu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmittingAction ? null : _onTapComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kProdOrderPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmittingAction
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Lưu & Nhập kho',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
