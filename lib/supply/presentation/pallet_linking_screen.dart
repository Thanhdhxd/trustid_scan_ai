import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trustid_scan_ai/core/utils/app_toast.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';
import 'package:trustid_scan_ai/core/utils/scan_feedback_helper.dart';
import 'package:trustid_scan_ai/scan/scanner_screen.dart';
import '../data/supply_repository.dart';
import '../domain/pallet.dart';
import 'production_order/constants/prod_order_constants.dart';
import 'production_order/constants/prod_order_helpers.dart';
import 'widgets/bag_card_widget.dart';
import 'widgets/pallet_info_card.dart';

/// Màn hình Đóng Pallet (`PALLET_MANAGE` — `/supply/pallets/:id/link-bag`).
/// Hỗ trợ cả 2 chế độ: theo Lệnh Sản Xuất (`orderId != null`) và độc lập ngoài lệnh (`orderId == null`).
/// Quét trực tuyến hoàn toàn (Zero Offline Queue) và tự động lưu thẳng vào DB sau mỗi lượt quét/gỡ bao.
class PalletLinkingScreen extends ConsumerStatefulWidget {
  final String? orderId;
  const PalletLinkingScreen({super.key, this.orderId});

  @override
  ConsumerState<PalletLinkingScreen> createState() => _PalletLinkingScreenState();
}

class _PalletLinkingScreenState extends ConsumerState<PalletLinkingScreen> {
  final _scanController = TextEditingController();
  late final FocusNode _scanFocusNode;

  String _orderCode = '';
  String _productName = '';

  Pallet? _currentPallet;
  bool _isLoadingPallet = false;
  bool _isScanning = false;
  bool _dialogOpen = false;
  bool _hideKeyboard = false;
  Timer? _pdaDebounceTimer;

  bool get _hasOrder => widget.orderId != null && widget.orderId!.trim().isNotEmpty;
  bool get _palletScanned => _currentPallet != null;

  @override
  void initState() {
    super.initState();
    _scanFocusNode = FocusNode(
      debugLabel: 'palletScanFocusNode',
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
    if (_hasOrder) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadOrderInfo();
      });
    }
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
            !_dialogOpen &&
            !_scanFocusNode.hasFocus &&
            _scanFocusNode.canRequestFocus) {
          if (route.isCurrent) {
            _scanFocusNode.requestFocus();
            SystemChannels.textInput.invokeMethod('TextInput.hide');
          }
        }
      });
    }
  }

  void _refocus() {
    if (!_hideKeyboard || _dialogOpen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _hideKeyboard && !_dialogOpen && _scanFocusNode.canRequestFocus) {
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

  Future<void> _loadOrderInfo() async {
    if (!_hasOrder) return;
    try {
      final data = await ref
          .read(supplyRepositoryProvider)
          .getProductionOrderDetail(widget.orderId!);
      if (!mounted) return;
      setState(() {
        _orderCode = (data['orderCode'] ?? data['order_code'] ?? '').toString();
        _productName = (data['product']?['name'] ?? data['productName'] ?? '').toString();
      });
    } catch (_) {}
  }

  Future<void> _handleTextScan() async {
    if (_isScanning || _dialogOpen) return;
    _pdaDebounceTimer?.cancel();
    final code = extractSerialCodeFromQr(_scanController.text);
    if (code.isEmpty) return;

    _scanController.clear();
    await _processScan(code);
    _refocus();
  }

  Future<void> _processScan(String code) async {
    if (_isScanning || _dialogOpen) return;

    final isExplicitPallet = code.toUpperCase().startsWith('PLT');
    if (!_palletScanned || isExplicitPallet) {
      await _scanPallet(code);
    } else {
      await _scanBag(code);
    }
  }

  Future<void> _scanPallet(String code) async {
    setState(() => _isScanning = true);
    try {
      final data = await ref.read(supplyRepositoryProvider).getPalletByCode(code);
      ScanFeedbackHelper.playSuccess();

      final pallet = Pallet.fromJson(data);
      if (!mounted) return;
      setState(() => _currentPallet = pallet);

      AppToast.success(context, 'Pallet ${pallet.palletCode} sẵn sàng — quét mã bao để xếp');
    } catch (e) {
      ScanFeedbackHelper.playError();
      final msg = parseSupplyHttpError(e).message;
      if (!mounted) return;
      AppToast.error(context, msg);
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _scanBag(String serial) async {
    if (_currentPallet == null) return;
    setState(() => _isScanning = true);
    try {
      final data = await ref
          .read(supplyRepositoryProvider)
          .linkBagToPallet(_currentPallet!.id, serial);

      if (!mounted) return;
      if (data['conflict'] == true) {
        ScanFeedbackHelper.playError();
        setState(() => _isScanning = false);
        await _showForceConfirmDialog(
          serial: serial,
          title: 'Bao đã ở pallet khác',
          message: data['message']?.toString() ?? 'Bao đang ở pallet khác. Xác nhận chuyển sang pallet này?',
          confirmCheckboxLabel: 'Tôi xác nhận muốn chuyển bao sang pallet mới',
          confirmBtnLabel: 'Chuyển pallet',
        );
        return;
      }

      if (data['crossProductWarning'] == true) {
        ScanFeedbackHelper.playError();
        setState(() => _isScanning = false);
        await _showForceConfirmDialog(
          serial: serial,
          title: 'Cảnh báo bao khác sản phẩm',
          message: data['message']?.toString() ?? 'Bao chứa sản phẩm khác loại với các bao đang có trong pallet.',
          confirmCheckboxLabel: 'Tôi xác nhận xếp bao khác sản phẩm vào pallet',
          confirmBtnLabel: 'Xác nhận xếp',
        );
        return;
      }

      if (data['success'] == true) {
        ScanFeedbackHelper.playSuccess();
        await _refreshPallet();
        if (!mounted) return;
        AppToast.success(context, 'Đã liên kết bao $serial vào ${_currentPallet!.palletCode}');
      }
    } catch (e) {
      ScanFeedbackHelper.playError();
      final msg = parseSupplyHttpError(e).message;
      if (!mounted) return;
      AppToast.error(context, msg);
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _forceLink(String serial) async {
    if (_currentPallet == null) return;
    setState(() => _isScanning = true);
    try {
      final data = await ref
          .read(supplyRepositoryProvider)
          .linkBagToPallet(_currentPallet!.id, serial, force: true);
      if (!mounted) return;
      if (data['success'] == true) {
        ScanFeedbackHelper.playSuccess();
        await _refreshPallet();
        if (!mounted) return;
        AppToast.success(context, 'Đã liên kết bao $serial');
      }
    } catch (e) {
      ScanFeedbackHelper.playError();
      final msg = parseSupplyHttpError(e).message;
      if (!mounted) return;
      AppToast.error(context, msg);
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _showForceConfirmDialog({
    required String serial,
    required String title,
    required String message,
    required String confirmCheckboxLabel,
    required String confirmBtnLabel,
  }) async {
    bool confirmed = false;
    _dialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: kProdOrderSurface,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: kProdOrderAmber, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: const TextStyle(color: kProdOrderTextSub, fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: confirmed,
                    onChanged: (v) => setDialogState(() => confirmed = v ?? false),
                    activeColor: kProdOrderPrimary,
                  ),
                  Expanded(
                    child: Text(
                      confirmCheckboxLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: kProdOrderTextGray)),
            ),
            ElevatedButton(
              onPressed: confirmed
                  ? () {
                      Navigator.pop(ctx);
                      _forceLink(serial);
                    }
                  : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
              child: Text(confirmBtnLabel, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    _dialogOpen = false;
    _refocus();
  }

  Future<void> _refreshPallet() async {
    if (_currentPallet == null) return;
    setState(() => _isLoadingPallet = true);
    try {
      final data = await ref
          .read(supplyRepositoryProvider)
          .getPalletDetail(_currentPallet!.id);
      if (mounted) {
        setState(() => _currentPallet = Pallet.fromJson(data));
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingPallet = false);
    }
  }

  Future<void> _unlinkBag(PalletBagMapping mapping) async {
    if (_currentPallet == null) return;
    _dialogOpen = true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kProdOrderSurface,
        title: const Text('Gỡ bao khỏi pallet', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          'Gỡ bao ${mapping.bagSerial} khỏi pallet ${_currentPallet!.palletCode}?',
          style: const TextStyle(color: kProdOrderTextSub, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: kProdOrderTextGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Gỡ bao', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (confirm != true || !mounted) {
      _refocus();
      return;
    }

    try {
      await ref
          .read(supplyRepositoryProvider)
          .unlinkBagFromPallet(_currentPallet!.id, mapping.bagSerial);
      if (!mounted) return;
      AppToast.info(context, 'Đã gỡ bao ${mapping.bagSerial}.');
      await _refreshPallet();
    } catch (e) {
      if (mounted) AppToast.error(context, parseSupplyHttpError(e).message);
    }
    _refocus();
  }

  void _clearPallet() {
    setState(() {
      _currentPallet = null;
      _scanController.clear();
    });
    _refocus();
  }

  Future<void> _showCameraScanner() async {
    final String? result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerScreen(
          title: _palletScanned ? 'Quét mã bao' : 'Quét mã pallet',
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
    final titleText = _hasOrder
        ? (_orderCode.isNotEmpty ? 'Đóng Pallet — $_orderCode' : 'Đóng Pallet')
        : 'Đóng Pallet ngoài lệnh';
    final subtitleText = _hasOrder
        ? _productName
        : 'Quét mã Pallet trước, sau đó quét mã bao để xếp';

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
                titleText,
                style: const TextStyle(color: kProdOrderText, fontSize: 15.5, fontWeight: FontWeight.bold),
              ),
            ),
            if (subtitleText.isNotEmpty)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  subtitleText,
                  style: const TextStyle(color: kProdOrderTextGray, fontSize: 12),
                ),
              ),
          ],
        ),
        backgroundColor: kProdOrderBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: kProdOrderTextGray),
        actions: [
          if (_palletScanned)
            IconButton(
              icon: const Icon(Icons.refresh, color: kProdOrderTextGray),
              onPressed: _refreshPallet,
            ),
        ],
      ),
      body: Column(
        children: [
          _buildScanInput(),
          if (_currentPallet != null)
            PalletInfoCard(
              palletCode: _currentPallet!.palletCode,
              status: _currentPallet!.status,
              currentBags: _currentPallet!.currentBagCount,
              maxBags: _currentPallet!.maxBags,
            ),
          if (_palletScanned)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bao trong pallet (${_currentPallet?.bagMappings.length ?? 0})',
                    style: const TextStyle(
                      color: kProdOrderTextGray,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _clearPallet,
                    icon: const Icon(Icons.swap_horiz, size: 16, color: kProdOrderAmber),
                    label: const Text(
                      'Đổi pallet',
                      style: TextStyle(fontSize: 12, color: kProdOrderAmber),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildBagList()),
        ],
      ),
      bottomNavigationBar: MediaQuery.of(context).viewInsets.bottom > 0
          ? null
          : _buildBottomBar(),
    );
  }

  Widget _buildScanInput() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _palletScanned
                      ? 'Bước 2: Quét mã bao (hoặc mã Pallet mới)'
                      : 'Bước 1: Quét mã Pallet',
                  style: TextStyle(
                    color: _palletScanned ? kProdOrderPrimaryLight : kProdOrderAmber,
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: prodOrderInputDeco(
                    null,
                    hint: _palletScanned ? 'Quét/nhập mã bao...' : 'Quét/nhập mã pallet...',
                    prefixIcon: Icon(
                      _palletScanned ? Icons.inventory_2 : Icons.palette_outlined,
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
                            !_dialogOpen &&
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
                message: _palletScanned ? 'Quét mã bao bằng Camera' : 'Quét mã pallet bằng Camera',
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isScanning ? null : _showCameraScanner,
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
    if (!_palletScanned) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.palette_outlined, size: 64, color: Colors.white12),
            SizedBox(height: 12),
            Text('Quét mã pallet để bắt đầu', style: TextStyle(color: kProdOrderTextGray)),
          ],
        ),
      );
    }

    if (_isLoadingPallet) {
      return const Center(child: CircularProgressIndicator(color: kProdOrderPrimary));
    }

    final bags = _currentPallet?.bagMappings ?? [];
    if (bags.isEmpty) {
      return const Center(
        child: Text('Chưa có bao nào trong pallet', style: TextStyle(color: kProdOrderTextGray)),
      );
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: bags.length,
      padding: const EdgeInsets.only(bottom: 24),
      itemBuilder: (context, index) {
        final bag = bags[index];
        return BagCardWidget(
          index: index,
          bagSerial: bag.bagSerial,
          bagQrCode: bag.bagQrCode,
          productName: bag.productName,
          packetCount: bag.packetCount,
          linkerName: bag.linkerName,
          onDelete: () => _unlinkBag(bag),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    final pallet = _currentPallet;
    final statusLine = pallet != null
        ? 'Số bao: ${pallet.currentBagCount}/${pallet.maxBags} • Đã lưu tự động sau mỗi lần quét'
        : 'Quét mã Pallet để bắt đầu • Đã lưu tự động sau mỗi lần quét';

    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: kProdOrderBg,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            statusLine,
            style: const TextStyle(color: kProdOrderTextGray, fontSize: 11.5),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Quay lại', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ),
              if (_palletScanned) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _clearPallet,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kProdOrderAmber,
                        side: const BorderSide(color: kProdOrderAmber),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Đóng pallet khác',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
