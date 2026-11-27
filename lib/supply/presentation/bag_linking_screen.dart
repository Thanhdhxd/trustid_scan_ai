import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trustid_scan_ai/core/utils/app_toast.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';
import 'package:trustid_scan_ai/core/utils/scan_feedback_helper.dart';
import 'package:trustid_scan_ai/scan/scanner_screen.dart';
import '../data/supply_repository.dart';
import '../domain/bag_mapping.dart';
import '../domain/packaging_receipt.dart';
import '../domain/production_order.dart';
import 'bag_linking/dialogs/bag_packet_detail_sheet.dart';
import 'bag_linking/dialogs/replace_packet_sheet.dart';
import 'bag_linking/widgets/bag_linking_current_bag_banner.dart';
import 'bag_linking/widgets/bag_linking_stats_row.dart';
import 'order_list_screen.dart';
import 'production_order/constants/prod_order_constants.dart';
import 'production_order/constants/prod_order_helpers.dart';
import 'widgets/bag_card_widget.dart';
import 'widgets/warehouse_selector.dart';

/// Màn hình Đóng Bao theo Phiếu (`BAG_PACKAGING` — `PackagingReceipt`).
/// Quét 2 bước trực tuyến (Zero Offline Queue): Bước 1 kiểm tra bao `-B` (`validate-bag`), Bước 2 liên kết gói (`scan`).
class BagLinkingScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String? initialReceiptId;

  const BagLinkingScreen({
    super.key,
    required this.orderId,
    this.initialReceiptId,
  });

  @override
  ConsumerState<BagLinkingScreen> createState() => _BagLinkingScreenState();
}

class _BagLinkingScreenState extends ConsumerState<BagLinkingScreen> {
  static const int _pageWindowSize = 30;

  final _scanController = TextEditingController();
  late final FocusNode _scanFocusNode;

  ProductionOrder? _order;
  String? _receiptId;
  String _receiptCode = '';
  String _receiptTime = '';
  String _receiptUser = '';
  String _receiptStatus = 'PACKING';
  String? _selectedWarehouseId;
  String _warehouseName = '';

  List<BagMapping> _bagMappings = [];
  int _totalBags = 0;
  int _totalPackets = 0;
  int _visibleLimit = _pageWindowSize;

  // 2-step state
  String? _currentBagSerial;

  bool _isLoading = true;
  bool _isScanning = false;
  bool _isSubmittingAction = false;
  bool _hideKeyboard = false;
  Timer? _pdaDebounceTimer;

  bool get _isBagScanned => _currentBagSerial != null && _currentBagSerial!.isNotEmpty;
  bool get _isEditable => _receiptStatus == 'PACKING';
  bool get _canReplace {
    final oStatus = _order?.status ?? 'IN_PROGRESS';
    return _isEditable &&
        (oStatus == 'CODES_READY' || oStatus == 'IN_PROGRESS' || oStatus == 'APPROVED');
  }

  bool _isBagCode(String code) => code.toUpperCase().contains('-B');

  @override
  void initState() {
    super.initState();
    _scanFocusNode = FocusNode(
      debugLabel: 'bagScanFocusNode',
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
      Map<String, dynamic>? detailPayload;
      String? receiptId = widget.initialReceiptId;

      if (receiptId != null && receiptId.isNotEmpty) {
        detailPayload = await repo.getReceiptDetail(receiptId);
      } else {
        final byOrder = await repo.getOrCreateReceipt(widget.orderId);
        receiptId = (byOrder['id'] ??
                byOrder['receiptId'] ??
                byOrder['receipt']?['id'] ??
                byOrder['receipt']?['receiptId'])
            ?.toString();
        if (receiptId != null && receiptId.isNotEmpty) {
          try {
            detailPayload = await repo.getReceiptDetail(receiptId);
          } catch (_) {
            detailPayload = byOrder;
          }
        }
      }

      if (detailPayload == null || receiptId == null || receiptId.isEmpty) {
        if (!mounted) return;
        AppToast.error(context, 'Không lấy được thông tin phiếu đóng bao.');
        Navigator.of(context).pop();
        return;
      }

      Map<String, dynamic>? orderMap;
      try {
        orderMap = await repo.getProductionOrderDetail(widget.orderId);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _receiptId = receiptId;
        _applyReceiptAndOrder(detailPayload!, orderMap);
        _isLoading = false;
      });
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

  Future<void> _fetchBags() async {
    final receiptId = _receiptId;
    if (receiptId == null || receiptId.isEmpty) return;
    try {
      final detail = await ref.read(supplyRepositoryProvider).getReceiptDetail(receiptId);
      if (!mounted) return;
      setState(() {
        _applyReceiptAndOrder(detail, null);
      });
    } catch (_) {}
  }

  void _applyReceiptAndOrder(
    Map<String, dynamic> payload,
    Map<String, dynamic>? orderJson,
  ) {
    final receiptRaw = payload['receipt'] is Map
        ? Map<String, dynamic>.from(payload['receipt'] as Map)
        : payload;
    final parsedReceipt = PackagingReceipt.fromJson(receiptRaw);

    final embeddedOrder = (payload['order'] ?? receiptRaw['order']) is Map
        ? Map<String, dynamic>.from((payload['order'] ?? receiptRaw['order']) as Map)
        : null;
    final resolvedOrderMap = orderJson ?? embeddedOrder;
    if (resolvedOrderMap != null) {
      _order = ProductionOrder.fromJson(resolvedOrderMap);
    }

    final rawBagsList = (payload['bags'] ?? payload['linkedBags'] ?? receiptRaw['bags']) as List? ?? const [];
    final parsedBags = rawBagsList
        .whereType<Map>()
        .map((e) => BagMapping.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) {
        final da = a.scannedAt ?? a.linkedAt ?? DateTime(0);
        final db = b.scannedAt ?? b.linkedAt ?? DateTime(0);
        return db.compareTo(da);
      });

    _receiptCode = parsedReceipt.receiptCode;
    _receiptStatus = parsedReceipt.status;
    _receiptUser = parsedReceipt.packerName ?? _receiptUser;
    _selectedWarehouseId = parsedReceipt.warehouseId ?? _order?.warehouseId;
    _warehouseName = parsedReceipt.warehouseName ?? _order?.warehouseName ?? _warehouseName;

    final dt = parsedReceipt.packingTime ?? parsedReceipt.createdAt;
    if (dt != null) {
      _receiptTime = DateFormat('HH:mm:ss dd/MM/yyyy').format(dt.toLocal());
    }

    _bagMappings = parsedBags;
    _totalBags = parsedReceipt.totalBags > 0 ? parsedReceipt.totalBags : parsedBags.length;
    _totalPackets = parsedReceipt.totalPackets > 0
        ? parsedReceipt.totalPackets
        : parsedBags.fold<int>(0, (sum, b) => sum + b.packetCount);

    // Nếu bao đang chờ đã được đồng nghiệp đóng xong trên server thì bỏ giữ pending
    if (_currentBagSerial != null &&
        _bagMappings.any(
          (b) => b.bagSerial == _currentBagSerial || b.bagQrCode == _currentBagSerial,
        )) {
      _currentBagSerial = null;
    }
  }

  Future<void> _handleTextScan() async {
    if (_isScanning || !_isEditable) return;
    _pdaDebounceTimer?.cancel();
    final code = extractSerialCodeFromQr(_scanController.text);
    if (code.isEmpty) return;

    _scanController.clear();
    await _processScan(code);
    _refocus();
  }

  Future<void> _processScan(String code) async {
    final receiptId = _receiptId;
    if (receiptId == null || receiptId.isEmpty || _isScanning || !_isEditable) return;

    if (_isBagCode(code)) {
      await _validateAndSetBag(code);
    } else {
      await _linkPacketToPendingBag(code);
    }
  }

  Future<void> _validateAndSetBag(String bagCode) async {
    if (_isBagScanned) {
      final confirmSwitch = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: kProdOrderSurface,
          title: const Text('Đổi mã bao?', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Text(
            'Bao hiện tại: $_currentBagSerial\nChuyển sang kiểm tra bao:\n$bagCode ?',
            style: const TextStyle(color: kProdOrderTextGray, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy', style: TextStyle(color: kProdOrderTextGray)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: kProdOrderPrimary),
              child: const Text('Xác nhận đổi', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirmSwitch != true || !mounted) return;
    }

    setState(() => _isScanning = true);
    try {
      final res = await ref
          .read(supplyRepositoryProvider)
          .validateBagForReceipt(_receiptId!, bagCode);
      ScanFeedbackHelper.playSuccess();

      final validatedSerial = (res['serial'] ?? bagCode).toString();
      if (!mounted) return;
      setState(() => _currentBagSerial = validatedSerial);

      AppToast.info(context, 'Bao $validatedSerial hợp lệ — tiếp tục quét mã gói');
    } catch (e) {
      ScanFeedbackHelper.playError();
      final err = parseSupplyHttpError(e);
      if (!mounted) return;

      AppToast.error(context, err.message);
      if (err.isBadRequest || err.isNotFound || err.isConflict) {
        await _fetchBags();
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _linkPacketToPendingBag(String packetCode) async {
    if (!_isBagScanned) {
      ScanFeedbackHelper.playError();
      AppToast.warning(context, 'Vui lòng quét mã BAO (-B) trước, sau đó quét mã gói.');
      return;
    }

    final bagUsed = _currentBagSerial!;
    setState(() => _isScanning = true);
    try {
      final res = await ref
          .read(supplyRepositoryProvider)
          .scanBagLinkV6(_receiptId!, packetCode, bagCode: bagUsed);
      ScanFeedbackHelper.playSuccess();

      if (!mounted) return;
      final mappingMap = res['bagMapping'] is Map
          ? Map<String, dynamic>.from(res['bagMapping'] as Map)
          : null;
      final totalsMap = res['receiptTotals'] is Map
          ? Map<String, dynamic>.from(res['receiptTotals'] as Map)
          : null;

      setState(() {
        if (mappingMap != null) {
          final addedMapping = BagMapping.fromJson(mappingMap);
          _bagMappings.removeWhere((b) => b.id == addedMapping.id || b.bagSerial == addedMapping.bagSerial);
          _bagMappings.insert(0, addedMapping);
        }
        if (totalsMap != null) {
          _totalBags = int.tryParse(totalsMap['totalBags']?.toString() ?? '') ?? _bagMappings.length;
          _totalPackets = int.tryParse(totalsMap['totalPackets']?.toString() ?? '') ??
              _bagMappings.fold<int>(0, (sum, b) => sum + b.packetCount);
        } else {
          _totalBags = _bagMappings.length;
          _totalPackets = _bagMappings.fold<int>(0, (sum, b) => sum + b.packetCount);
        }
        // Hoàn tất 1 bao → xóa _currentBagSerial để sẵn sàng bao tiếp theo
        _currentBagSerial = null;
      });

      final count = res['packetCount'] ?? mappingMap?['packetCount'] ?? '';
      AppToast.success(
        context,
        'Đã đóng bao $bagUsed${count.toString().isNotEmpty ? ' ($count gói)' : ''}',
      );
    } catch (e) {
      ScanFeedbackHelper.playError();
      final err = parseSupplyHttpError(e);
      if (!mounted) return;

      AppToast.error(context, err.message);

      // Giữ nguyên _currentBagSerial khi lỗi 400 (theo mục 5.7.4), chỉ xóa nếu đồng bộ phát hiện bao đã được đóng
      if (err.isBadRequest || err.isNotFound || err.isConflict) {
        await _fetchBags();
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _confirmRemoveBag(BagMapping bag) async {
    if (_receiptId == null || !_isEditable) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kProdOrderSurface,
        title: const Text('Xóa bao khỏi phiếu?', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
        content: Text(
          'Hủy liên kết bao ${bag.bagSerial} (${bag.packetCount} gói) khỏi phiếu $_receiptCode?',
          style: const TextStyle(color: kProdOrderTextSub, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Quay lại', style: TextStyle(color: kProdOrderTextGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Xóa bao', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final res = await ref
          .read(supplyRepositoryProvider)
          .removeBagFromReceipt(_receiptId!, bag.id);
      if (!mounted) return;
      final totalsMap = res['receiptTotals'] is Map
          ? Map<String, dynamic>.from(res['receiptTotals'] as Map)
          : null;
      setState(() {
        _bagMappings.removeWhere((b) => b.id == bag.id);
        _totalBags = int.tryParse(totalsMap?['totalBags']?.toString() ?? '') ?? _bagMappings.length;
        _totalPackets = int.tryParse(totalsMap?['totalPackets']?.toString() ?? '') ??
            _bagMappings.fold<int>(0, (sum, b) => sum + b.packetCount);
      });
      AppToast.info(context, 'Đã xóa bao ${bag.bagSerial} khỏi phiếu.');
    } catch (e) {
      if (mounted) AppToast.error(context, parseSupplyHttpError(e).message);
      await _fetchBags();
    }
  }

  Future<void> _openPacketDetail(BagMapping bag) async {
    await showBagPacketDetailSheet(
      context,
      bag: bag,
      canReplace: _canReplace,
      onTapReplaceSerial: (damagedSerial) => _openReplaceSheet(prefillSerial: damagedSerial),
    );
  }

  Future<void> _openReplaceSheet({String? prefillSerial}) async {
    if (_receiptId == null || !_canReplace) return;
    final replaced = await showReplacePacketSheet(
      context,
      receiptId: _receiptId!,
      prefillDamagedSerial: prefillSerial,
    );
    if (replaced == true && mounted) {
      await _fetchBags();
    }
  }

  Future<void> _onTapCompleteReceipt() async {
    if (_receiptId == null) return;
    if (_bagMappings.isEmpty && _totalBags == 0) {
      AppToast.warning(context, 'Phiếu chưa có bao nào. Vui lòng quét ít nhất 1 bao.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: kProdOrderSurface,
        title: Text(
          'Lưu phiếu $_receiptCode & Nhập kho',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Xác nhận nhập kho $_totalBags bao ($_totalPackets gói) vào kho ${_warehouseName.isNotEmpty ? _warehouseName : 'đã chọn'}?\n\nLệnh SX vẫn mở để tạo thêm phiếu mới nếu cần.',
          style: const TextStyle(color: kProdOrderTextSub, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: kProdOrderTextGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: kProdOrderPrimary),
            child: const Text('Lưu & Nhập kho', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmittingAction = true);
    try {
      await ref.read(supplyRepositoryProvider).completeReceipt(_receiptId!);
      OrderListScreen.clearStaticCache();
      if (!mounted) return;
      AppToast.success(context, 'Đã lưu phiếu đóng bao và nhập kho.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingAction = false);
        AppToast.error(context, parseSupplyHttpError(e).message);
      }
    }
  }

  Future<void> _onTapCancelReceipt() async {
    if (_receiptId == null || !_isEditable) return;
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: kProdOrderSurface,
        title: Text(
          'Hủy phiếu $_receiptCode',
          style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hủy phiếu sẽ tách toàn bộ bao đã quét khỏi phiếu này về trạng thái khả dụng.',
              style: TextStyle(color: kProdOrderTextSub, fontSize: 12.5, height: 1.35),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 2,
              decoration: prodOrderInputDeco('Lý do hủy phiếu (tùy chọn)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Quay lại', style: TextStyle(color: kProdOrderTextGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Xác nhận hủy', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmittingAction = true);
    try {
      await ref.read(supplyRepositoryProvider).cancelReceipt(
            _receiptId!,
            reason: reasonCtrl.text.trim(),
          );
      OrderListScreen.clearStaticCache();
      if (!mounted) return;
      AppToast.warning(context, 'Đã hủy phiếu $_receiptCode.');
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
        builder: (context) => ScannerScreen(
          title: _isBagScanned ? 'Quét mã gói' : 'Quét mã bao',
          isWarehouseMode: true,
        ),
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      final code = extractSerialCodeFromQr(result);
      if (code.isNotEmpty) {
        await _processScan(code);
      }
    }
    _refocus();
  }

  @override
  Widget build(BuildContext context) {
    final orderCode = _order?.orderCode ?? '';
    final productName = _order?.productName ?? '';

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
                _receiptCode.isNotEmpty ? 'Đóng Bao • $_receiptCode' : 'Đóng Bao',
                style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold),
              ),
            ),
            if (orderCode.isNotEmpty)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$orderCode${productName.isNotEmpty ? ' — $productName' : ''}',
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
            onPressed: _fetchBags,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kProdOrderPrimary))
          : RefreshIndicator(
              onRefresh: _fetchBags,
              color: kProdOrderPrimary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  children: [
                    if (_isBagScanned)
                      BagLinkingCurrentBagBanner(
                        currentBagSerial: _currentBagSerial!,
                        currentBagPacketCount: 0,
                        onClearBag: () => setState(() => _currentBagSerial = null),
                      ),
                    _buildReceiptInfoBox(),
                    if (_isEditable) _buildScanInputCard(),
                    BagLinkingStatsRow(
                      totalBags: _totalBags,
                      linkedCount: _bagMappings.where((b) => (b.lotStatus ?? '') == 'LINKED').length,
                      totalPackets: _totalPackets,
                      onTapReplacePacket: _canReplace ? () => _openReplaceSheet() : null,
                    ),
                    const SizedBox(height: 8),
                    _buildBagList(),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: MediaQuery.of(context).viewInsets.bottom > 0 || !_isEditable
          ? null
          : _buildBottomBar(),
    );
  }

  Widget _buildReceiptInfoBox() {
    final statusColor = prodOrderStatusColor(_receiptStatus);
    final statusLabel = _receiptStatus == 'COMPLETED'
        ? 'Đã lưu & nhập kho'
        : (_receiptStatus == 'CANCELLED' ? 'Đã hủy' : 'Đang đóng bao');
    final canEditWarehouse = _isEditable && _bagMappings.isEmpty && _totalBags == 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kProdOrderSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: kProdOrderPrimaryLight, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _receiptCode.isNotEmpty ? _receiptCode : 'Phiếu đóng bao',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const Divider(height: 18, color: Colors.white10),
          Row(
            children: [
              Expanded(child: _infoCol('Thời gian', _receiptTime)),
              Expanded(child: _infoCol('Người đóng', _receiptUser)),
            ],
          ),
          const SizedBox(height: 10),
          if (canEditWarehouse)
            WarehouseSelector(
              label: 'Kho lưu (cố định khi bắt đầu quét)',
              selectedId: _selectedWarehouseId,
              onChanged: (val) async {
                if (val == null || _receiptId == null) return;
                setState(() => _selectedWarehouseId = val);
                try {
                  await ref.read(supplyRepositoryProvider).updateReceiptWarehouse(_receiptId!, val);
                } catch (e) {
                  if (mounted) AppToast.error(context, parseSupplyHttpError(e).message);
                }
              },
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: kProdOrderBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warehouse_outlined, color: kProdOrderTextGray, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kho nhập: ${_warehouseName.isNotEmpty ? _warehouseName : 'Theo kho Lệnh SX'}',
                      style: const TextStyle(color: kProdOrderTextSub, fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Icon(Icons.lock_outline, color: kProdOrderTextGray, size: 14),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: kProdOrderTextGray, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value.isNotEmpty ? value : '—',
          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildScanInputCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kProdOrderSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _isBagScanned
                      ? 'Bước 2: Quét mã GÓI liên kết vào $_currentBagSerial'
                      : 'Bước 1: Quét mã BAO (-B)',
                  style: TextStyle(
                    color: _isBagScanned ? kProdOrderPrimaryLight : kProdOrderAmber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
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
                        try {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('hide_keyboard_pda', val);
                        } catch (_) {}
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
                    hint: _isBagScanned ? 'Quét/nhập mã gói...' : 'Quét/nhập mã bao (-B)...',
                    prefixIcon: Icon(
                      _isBagScanned ? Icons.qr_code_2 : Icons.inventory_2,
                      color: kProdOrderPrimaryLight,
                    ),
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

  Widget _buildBagList() {
    if (_bagMappings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 60, color: Colors.white12),
            SizedBox(height: 10),
            Text('Chưa có bao nào trong phiếu này.', style: TextStyle(color: kProdOrderTextGray)),
          ],
        ),
      );
    }

    final displayCount = math.min(_bagMappings.length, _visibleLimit);
    final hasMoreLocal = _bagMappings.length > displayCount;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayCount + (hasMoreLocal ? 1 : 0),
      padding: const EdgeInsets.only(bottom: 24),
      itemBuilder: (context, index) {
        if (hasMoreLocal && index == displayCount) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _visibleLimit += _pageWindowSize),
              child: Text(
                'Xem thêm (${_bagMappings.length - displayCount} bao nữa)',
                style: const TextStyle(color: kProdOrderPrimaryLight),
              ),
            ),
          );
        }
        final bag = _bagMappings[index];
        return BagCardWidget(
          index: index,
          bagSerial: bag.bagSerial,
          bagQrCode: bag.bagQrCode,
          productName: bag.productName ??
              (bag.packetSerialStart != null
                  ? '${bag.packetSerialStart} → ${bag.packetSerialEnd ?? ''}'
                  : null),
          packetCount: bag.packetCount,
          linkerName: bag.linkerName,
          onTap: () => _openPacketDetail(bag),
          onDelete: _isEditable ? () => _confirmRemoveBag(bag) : null,
        );
      },
    );
  }

  Widget _buildBottomBar() {
    final canComplete = (_bagMappings.isNotEmpty || _totalBags > 0) && !_isSubmittingAction;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
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
                onPressed: _isSubmittingAction ? null : _onTapCancelReceipt,
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
                onPressed: canComplete ? _onTapCompleteReceipt : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kProdOrderPrimary,
                  disabledBackgroundColor: kProdOrderPrimary.withValues(alpha: 0.35),
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
