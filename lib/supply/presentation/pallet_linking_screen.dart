import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/supply_repository.dart';
import '../domain/pallet.dart';
import 'widgets/bag_card_widget.dart';
import 'widgets/pallet_info_card.dart';
import 'package:trustid_scan_ai/scan/scanner_screen.dart';

class PalletLinkingScreen extends ConsumerStatefulWidget {
  final String orderId;
  const PalletLinkingScreen({super.key, required this.orderId});

  @override
  ConsumerState<PalletLinkingScreen> createState() => _PalletLinkingScreenState();
}

class _PalletLinkingScreenState extends ConsumerState<PalletLinkingScreen> {
  static const Color kPrimaryColor = Color(0xFF00875A);
  static const Color kBackgroundDark = Color(0xFF0F2B46);
  static const Color kSurfaceDark = Color(0xFF16325B);
  static const Color kTextLight = Color(0xFFE8EDF3);
  static const Color kTextGray = Color(0xFF94A3B8);

  final _scanController = TextEditingController();
  late final FocusNode _scanFocusNode;
  final MobileScannerController _cameraController = MobileScannerController();

  // Order info
  String _orderCode = '';
  String _productName = '';

  // Pallet state
  Pallet? _currentPallet;
  bool _isLoadingPallet = false;

  // Scan state
  bool _isScanning = false;
  bool _palletScanned = false;
  Timer? _debounceTimer;
  bool _hideKeyboard = false;

  @override
  void initState() {
    super.initState();
    _scanFocusNode = FocusNode(
      debugLabel: 'scanFocusNode',
      onKeyEvent: (node, event) {
        if (!_hideKeyboard) return KeyEventResult.ignored;
        
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
            if (_scanController.text.trim().isNotEmpty) {
              _handleScan();
            }
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.backspace) {
            if (_scanController.text.isNotEmpty) {
              final newText = _scanController.text.substring(0, _scanController.text.length - 1);
              _scanController.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(offset: newText.length),
              );
            }
            return KeyEventResult.handled;
          } else if (event.character != null && event.character!.isNotEmpty) {
            if (event.character == '\n' || event.character == '\r') {
              if (_scanController.text.trim().isNotEmpty) {
                _handleScan();
              }
            } else {
              final newText = _scanController.text + event.character!;
              _scanController.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(offset: newText.length),
              );
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );
    _scanFocusNode.addListener(_onFocusChange);
    _loadPreferences();
    _loadOrderInfo();
  }

  void _onFocusChange() {
    if (_scanFocusNode.hasFocus) {
      if (_hideKeyboard) {
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      }
    } else {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && route.isCurrent) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_scanFocusNode.hasFocus && _scanFocusNode.canRequestFocus) {
            if (route.isCurrent) {
              _scanFocusNode.requestFocus();
              if (_hideKeyboard) {
                SystemChannels.textInput.invokeMethod('TextInput.hide');
              }
            }
          }
        });
      }
    }
  }

  void _refocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scanFocusNode.canRequestFocus) {
        _scanFocusNode.requestFocus();
        if (_hideKeyboard) {
          SystemChannels.textInput.invokeMethod('TextInput.hide');
        }
      }
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _hideKeyboard = prefs.getBool('hide_keyboard_pda') ?? false;
      });
    }
  }

  @override
  void dispose() {
    _scanFocusNode.removeListener(_onFocusChange);
    _debounceTimer?.cancel();
    _scanController.dispose();
    _scanFocusNode.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _loadOrderInfo() async {
    try {
      final data = await ref.read(supplyRepositoryProvider).getProductionOrderDetail(widget.orderId);
      if (mounted) {
        setState(() {
          _orderCode = data['orderCode'] ?? '';
          _productName = data['product']?['name'] ?? data['productName'] ?? '';
        });
      }
    } catch (_) {}
  }

  void _handleScan() {
    final code = _scanController.text.trim();
    if (code.isEmpty) return;

    if (!_palletScanned) {
      _scanPallet(code);
    } else {
      _scanBag(code);
    }
  }

  Future<void> _scanPallet(String code) async {
    setState(() => _isScanning = true);
    try {
      final data = await ref.read(supplyRepositoryProvider).getPalletByCode(code);
      final pallet = Pallet.fromJson(data);
      setState(() {
        _currentPallet = pallet;
        _palletScanned = true;
        _scanController.clear();
      });
      HapticFeedback.mediumImpact();
      _showSnack('✅ Pallet ${pallet.palletCode} đã sẵn sàng', isError: false);
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Không tìm thấy pallet';
      HapticFeedback.heavyImpact();
      _showSnack('❌ $msg', isError: true);
    } catch (e) {
      _showSnack('❌ Lỗi: $e', isError: true);
    } finally {
      setState(() => _isScanning = false);
      _scanController.clear();
      _refocus();
    }
  }

  Future<void> _scanBag(String serial) async {
    if (_currentPallet == null) return;
    setState(() => _isScanning = true);
    try {
      final data = await ref.read(supplyRepositoryProvider).linkBagToPallet(
        _currentPallet!.id, serial,
      );

      if (data['conflict'] == true) {
        _showTransferDialog(serial, data['message'] ?? 'Bao đang ở pallet khác');
        return;
      }
      if (data['crossProductWarning'] == true) {
        _showCrossProductDialog(serial, data['message'] ?? 'Bao khác sản phẩm');
        return;
      }
      if (data['success'] == true) {
        HapticFeedback.mediumImpact();
        _showSnack('✅ Đã liên kết bao $serial', isError: false);
        await _refreshPallet();
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Lỗi liên kết';
      HapticFeedback.heavyImpact();
      _showSnack('❌ $msg', isError: true);
    } finally {
      setState(() => _isScanning = false);
      _scanController.clear();
      _refocus();
    }
  }

  Future<void> _forceLink(String serial) async {
    if (_currentPallet == null) return;
    try {
      final data = await ref.read(supplyRepositoryProvider).linkBagToPallet(
        _currentPallet!.id, serial, force: true,
      );
      if (data['success'] == true) {
        HapticFeedback.mediumImpact();
        _showSnack('✅ Đã chuyển bao $serial', isError: false);
        await _refreshPallet();
      }
    } on DioException catch (e) {
      _showSnack('❌ ${e.response?.data?['message'] ?? 'Lỗi'}', isError: true);
    }
  }

  Future<void> _refreshPallet() async {
    if (_currentPallet == null) return;
    setState(() => _isLoadingPallet = true);
    try {
      final data = await ref.read(supplyRepositoryProvider).getPalletDetail(_currentPallet!.id);
      setState(() => _currentPallet = Pallet.fromJson(data));
    } catch (_) {}
    setState(() => _isLoadingPallet = false);
  }

  Future<void> _unlinkBag(PalletBagMapping mapping) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurfaceDark,
        title: const Text('Gỡ bao', style: TextStyle(color: kTextLight)),
        content: Text('Gỡ bao ${mapping.bagSerial} khỏi pallet?', style: const TextStyle(color: kTextGray)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Gỡ', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm != true || _currentPallet == null) return;
    try {
      await ref.read(supplyRepositoryProvider).unlinkBagFromPallet(_currentPallet!.id, mapping.bagSerial);
      _showSnack('Đã gỡ bao', isError: false);
      await _refreshPallet();
    } catch (e) {
      _showSnack('Lỗi gỡ bao', isError: true);
    }
  }

  void _showTransferDialog(String serial, String message) {
    bool confirmed = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: kSurfaceDark,
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text('Bao đã ở pallet khác', style: TextStyle(color: kTextLight, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: const TextStyle(color: kTextGray)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: confirmed,
                    onChanged: (v) => setDialogState(() => confirmed = v ?? false),
                    activeColor: kPrimaryColor,
                  ),
                  const Expanded(
                    child: Text('Tôi xác nhận muốn chuyển bao', style: TextStyle(color: kTextLight, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
            TextButton(
              onPressed: confirmed ? () { Navigator.pop(ctx); _forceLink(serial); } : null,
              child: Text('Chuyển pallet', style: TextStyle(color: confirmed ? Colors.orange : Colors.white24)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCrossProductDialog(String serial, String message) {
    bool confirmed = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: kSurfaceDark,
          title: const Text('⚠️ Bao khác sản phẩm', style: TextStyle(color: Colors.orange, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, style: const TextStyle(color: kTextGray)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: confirmed,
                    onChanged: (v) => setDialogState(() => confirmed = v ?? false),
                    activeColor: kPrimaryColor,
                  ),
                  const Expanded(child: Text('Xác nhận liên kết bao khác SP', style: TextStyle(color: kTextLight, fontSize: 13))),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
            TextButton(
              onPressed: confirmed ? () { Navigator.pop(ctx); _forceLink(serial); } : null,
              child: Text('Xác nhận', style: TextStyle(color: confirmed ? Colors.orange : Colors.white24)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCameraScanner() async {
    final String? result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerScreen(
          title: _palletScanned ? 'Quét mã bao' : 'Quét mã pallet',
          returnCode: true,
        ),
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      _scanController.text = result;
      _handleScan();
    }
  }

  void _clearPallet() {
    setState(() {
      _currentPallet = null;
      _palletScanned = false;
    });
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : kPrimaryColor,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Xếp Pallet', style: TextStyle(color: kTextLight, fontSize: 16)),
            if (_orderCode.isNotEmpty)
              Text('$_orderCode — $_productName', style: const TextStyle(color: kTextGray, fontSize: 12)),
          ],
        ),
        backgroundColor: kBackgroundDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextGray),
        actions: [
          if (_palletScanned)
            IconButton(
              icon: const Icon(Icons.refresh, color: kTextGray),
              onPressed: _refreshPallet,
            ),
        ],
      ),
      body: Column(
        children: [
          // Scan input
          _buildScanInput(),
          // Pallet info
          if (_currentPallet != null)
            PalletInfoCard(
              palletCode: _currentPallet!.palletCode,
              status: _currentPallet!.status,
              currentBags: _currentPallet!.currentBagCount,
              maxBags: _currentPallet!.maxBags,
            ),
          // Bag list header
          if (_palletScanned)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bao trong pallet (${_currentPallet?.bagMappings.length ?? 0})',
                    style: const TextStyle(color: kTextGray, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  TextButton.icon(
                    onPressed: _clearPallet,
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('Đổi pallet', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          // Bag list
          Expanded(child: _buildBagList()),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),

    );
  }

  Widget _buildScanInput() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _palletScanned ? '📦 Bước 2: Quét mã bao' : '🏷️ Bước 1: Quét mã pallet',
                  style: const TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Ẩn bàn phím', style: TextStyle(color: kTextGray, fontSize: 11)),
                  const SizedBox(width: 4),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _hideKeyboard,
                      activeThumbColor: kPrimaryColor,
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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _scanController,
                  focusNode: _scanFocusNode,
                  autofocus: true,
                  readOnly: _hideKeyboard,
                  showCursor: true,
                  enableInteractiveSelection: true,
                  textInputAction: TextInputAction.none,
                  keyboardType: TextInputType.multiline,
                  maxLines: 1,
                  style: const TextStyle(color: kTextLight, fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: _palletScanned ? 'Mã bao (serial/QR)...' : 'Mã pallet...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      _palletScanned ? Icons.inventory_2 : Icons.palette_outlined,
                      color: kPrimaryColor,
                    ),
                  ),
                  onSubmitted: (_) => _handleScan(),
                  onChanged: (value) {
                    _debounceTimer?.cancel();
                    if (_hideKeyboard) {
                      SystemChannels.textInput.invokeMethod('TextInput.hide');
                    }
                    
                    // Detect scanner carriage return / newline, sanitize it, and scan instantly
                    if (value.contains('\n') || value.contains('\r')) {
                      final cleanValue = value.replaceAll(RegExp(r'[\n\r]'), '').trim();
                      _scanController.value = TextEditingValue(
                        text: cleanValue,
                        selection: TextSelection.collapsed(offset: cleanValue.length),
                      );
                      if (cleanValue.isNotEmpty) {
                        _handleScan();
                      }
                      return;
                    }
                    
                    if (value.trim().isNotEmpty) {
                      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                        if (_scanController.text.trim().isNotEmpty && mounted) {
                          _handleScan();
                        }
                      });
                    }
                  },
                  onTap: () {
                    _scanController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _scanController.text.length),
                    );
                    if (_hideKeyboard) {
                      SystemChannels.textInput.invokeMethod('TextInput.hide');
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isScanning ? null : _handleScan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isScanning
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Quét'),
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
            Text('Quét mã pallet để bắt đầu', style: TextStyle(color: kTextGray)),
          ],
        ),
      );
    }

    if (_isLoadingPallet) {
      return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
    }

    final bags = _currentPallet?.bagMappings ?? [];
    if (bags.isEmpty) {
      return const Center(
        child: Text('Chưa có bao nào trong pallet', style: TextStyle(color: kTextGray)),
      );
    }

    return ListView.builder(
      itemCount: bags.length,
      padding: const EdgeInsets.only(bottom: 80),
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
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: kBackgroundDark,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kTextLight,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Quay lại', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _showCameraScanner,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  elevation: 8,
                  shadowColor: kPrimaryColor.withOpacity(0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_scanner, size: 20),
                    const SizedBox(height: 2),
                    Text(_palletScanned ? 'Quét bao' : 'Quét pallet', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  if (!_palletScanned) {
                    _showSnack('Vui lòng quét pallet trước', isError: true);
                    return;
                  }
                  _showSnack('✅ Đã lưu lại pallet', isError: false);
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Lưu lại', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.2)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
