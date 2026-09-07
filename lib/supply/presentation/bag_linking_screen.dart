import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/supply_repository.dart';
import '../domain/bag_mapping.dart';
import 'package:intl/intl.dart';
import 'widgets/bag_card_widget.dart';
import 'widgets/warehouse_selector.dart';
import 'package:trustid_scan_ai/scan/scanner_screen.dart';

class BagLinkingScreen extends ConsumerStatefulWidget {
  final String orderId;
  const BagLinkingScreen({super.key, required this.orderId});

  @override
  ConsumerState<BagLinkingScreen> createState() => _BagLinkingScreenState();
}

class _BagLinkingScreenState extends ConsumerState<BagLinkingScreen> {
  static const Color kPrimaryColor = Color(0xFF00875A);
  static const Color kBackgroundDark = Color(0xFF0F2B46);
  static const Color kSurfaceDark = Color(0xFF16325B);
  static const Color kTextLight = Color(0xFFE8EDF3);
  static const Color kTextGray = Color(0xFF94A3B8);
  static const Color kWarningColor = Color(0xFFFFA726);

  final _scanController = TextEditingController();
  late final FocusNode _scanFocusNode;

  String _orderCode = '';
  String _productName = '';
  List<BagMapping> _bagMappings = [];
  String? _receiptId;
  String? _selectedWarehouseId;
  String _receiptCode = '';
  String _receiptTime = '';
  String _receiptUser = '';
  String _receiptStatus = '';
  String _orderStatus = '';
  bool _isLoading = true;
  bool _isScanning = false;
  Timer? _debounceTimer;
  bool _hideKeyboard = false;

  // 2-step state
  String? _currentBagSerial;
  int _currentBagPacketCount = 0;

  bool get _isBagScanned => _currentBagSerial != null;
  bool _isBagCode(String code) => code.toUpperCase().endsWith('-B');

  /// Extract mã thực từ URL QR (http://trustid.com.vn/?Code=XXX → XXX)
  String _extractCode(String raw) {
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasQuery) {
      final code = uri.queryParameters['Code'] ?? uri.queryParameters['code'];
      if (code != null && code.isNotEmpty) return code;
    }
    // Fallback: nếu chứa '=' thì lấy sau dấu '=' cuối cùng
    if (trimmed.contains('=')) {
      return trimmed.substring(trimmed.lastIndexOf('=') + 1);
    }
    return trimmed;
  }

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
    _loadData();
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
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final repo = ref.read(supplyRepositoryProvider);
      final orderData = await repo.getProductionOrderDetail(widget.orderId);
      final mappings = await repo.getOrderLotMappings(widget.orderId);
      
      String? receiptId;
      String? receiptError;
      final orderStatus = (orderData['status'] ?? '').toString().toUpperCase();
      final linkedBags = mappings.where((m) {
        final s = (m['lotStatus'] ?? m['lot_status'] ?? '').toString().toUpperCase();
        return s == 'LINKED';
      }).length;
      final totalBags = mappings.length;
      final stillOpen = totalBags == 0 || linkedBags < totalBags;

      try {
        final receiptData = await repo.getOrCreateReceipt(widget.orderId);
        receiptId = _extractReceiptId(receiptData);
        
        final rMap = receiptData['receipt'] is Map ? receiptData['receipt'] as Map : receiptData;
        _receiptCode = (rMap['receiptCode'] ?? rMap['code'] ?? '').toString();
        
        final dtStr = rMap['createdAt'] ?? rMap['created_at'];
        if (dtStr != null) {
          final parsed = DateTime.tryParse(dtStr.toString());
          if (parsed != null) {
            _receiptTime = DateFormat('HH:mm:ss dd/MM/yyyy').format(parsed.toLocal());
          }
        }
        
        final createdBy = rMap['createdBy'] ?? rMap['created_by'];
        if (createdBy is Map) {
          _receiptUser = (createdBy['fullName'] ?? createdBy['name'] ?? 'Demo').toString();
        } else {
          _receiptUser = createdBy?.toString() ?? 'Demo';
        }

        _selectedWarehouseId = (rMap['warehouseId'] ?? rMap['warehouse_id'])?.toString();

        final receiptStatus = (rMap['status'] ?? '').toString().toUpperCase();
        _receiptStatus = receiptStatus;

        // Chỉ reopen khi phiếu đã COMPLETED. Phiếu đang PACKING mà gọi reopen → 400.
        if (receiptId != null && stillOpen && receiptStatus == 'COMPLETED') {
          final reopened = await repo.reopenIfIncompleteBagOrder(widget.orderId);
          if (reopened && mounted) {
            _showSnack('Đã mở lại phiếu — có thể đóng bao tiếp', isError: false);
          }
        } else if (stillOpen && orderStatus == 'COMPLETED' && receiptStatus != 'COMPLETED') {
          // Lệnh đã đóng sớm, phiếu vẫn mở — app không đổi được status lệnh
          receiptError =
              'LSX đã Hoàn thành trên server trong khi còn thiếu bao. Cần backend/admin mở lại lệnh về IN_PROGRESS.';
        }

        if (receiptId == null || receiptId.isEmpty) {
          receiptError ??= 'Không lấy được mã phiếu đóng bao';
          receiptId = null;
        }
      } catch (e) {
        receiptError = e is DioException
            ? (e.response?.data?['message']?.toString() ?? 'Không tạo được phiếu đóng bao')
            : e.toString();
        print('Receipt lookup failed: $e');

        final errLower = receiptError!.toLowerCase();
        final blockedByStatus = errLower.contains('codes_ready') ||
            errLower.contains('in_progress') ||
            errLower.contains('trạng thái') ||
            orderStatus == 'COMPLETED';

        if (stillOpen && blockedByStatus) {
          try {
            final receipts = orderData['packagingReceipts'] ?? orderData['packaging_receipts'];
            if (receipts is List && receipts.isNotEmpty) {
              final first = receipts.first;
              final id = (first['id'] ?? first['receiptId'])?.toString();
              final rStatus = (first['status'] ?? '').toString().toUpperCase();
              if (id != null && id.isNotEmpty && rStatus == 'COMPLETED') {
                await repo.reopenReceipt(id);
                final again = await repo.getOrCreateReceipt(widget.orderId);
                receiptId = _extractReceiptId(again) ?? id;
                receiptError = null;
                if (mounted) {
                  _showSnack('Đã mở lại phiếu — có thể đóng bao tiếp', isError: false);
                }
              } else {
                receiptError =
                    'LSX đã khóa (COMPLETED). Cần backend mở lại lệnh về IN_PROGRESS để đóng bao tiếp.';
              }
            }
          } catch (reopenErr) {
            final msg = reopenErr is DioException
                ? (reopenErr.response?.data?['message']?.toString() ?? reopenErr.message)
                : reopenErr.toString();
            print('Reopen receipt failed: $msg');
          }
        }
      }

      if (mounted) {
        setState(() {
          _orderCode = orderData['orderCode'] ?? orderData['order_code'] ?? '';
          _productName = orderData['product']?['name'] ?? orderData['productName'] ?? '';
          _bagMappings = mappings.map((e) => BagMapping.fromJson(e)).toList();
          _receiptId = receiptId;
          _orderStatus = orderStatus;
          _isLoading = false;
        });
        if (receiptError != null) {
          _showSnack('❌ $receiptError — quét sẽ không lên web', isError: true);
        }
        _refocus();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Lỗi tải dữ liệu: $e', isError: true);
      }
    }
  }

  String? _extractReceiptId(Map<String, dynamic> receiptData) {
    final id = receiptData['id'] ??
        receiptData['receiptId'] ??
        receiptData['receipt']?['id'] ??
        receiptData['receipt']?['receiptId'];
    final s = id?.toString();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  Future<void> _handleScan() async {
    if (_isScanning) return;
    _debounceTimer?.cancel();

    final code = _extractCode(_scanController.text);
    if (code.isEmpty) return;
    if (_isBagCode(code)) {
      _handleBagScan(code);
    } else {
      await _handlePacketScan(code);
    }
  }

  void _handleBagScan(String bagCode) {
    if (_isBagScanned) {
      _scanController.clear();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E3A5F),
          title: const Text('Đổi mã bao?', style: TextStyle(color: kTextLight)),
          content: Text(
            'Bao hiện tại: $_currentBagSerial\nĐã quét: $_currentBagPacketCount gói\n\nChuyển sang bao:\n$bagCode ?',
            style: const TextStyle(color: kTextGray),
          ),
          actions: [
            TextButton(
              onPressed: () { 
                Navigator.pop(ctx); 
                _refocus();
              },
              child: const Text('Huỷ', style: TextStyle(color: kTextGray)),
            ),
            ElevatedButton(
              onPressed: () { Navigator.pop(ctx); _setBag(bagCode); },
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
              child: const Text('Xác nhận đổi', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }
    _setBag(bagCode);
  }

  void _setBag(String bagCode) {
    setState(() { _currentBagSerial = bagCode; _currentBagPacketCount = 0; });
    HapticFeedback.mediumImpact();
    _showSnack('📦 Bao $bagCode sẵn sàng — Quét gói để liên kết', isError: false);
    _scanController.clear();
    _refocus();
  }

  Future<void> _handlePacketScan(String packetCode) async {
    if (!_isBagScanned) {
      HapticFeedback.heavyImpact();
      _showSnack('⚠️ Quét mã BAO trước (hậu tố -B)!', isError: true);
      _scanController.clear();
      _refocus();
      return;
    }
    setState(() => _isScanning = true);
    final bagUsed = _currentBagSerial!;
    try {
      // Bắt buộc dùng phiếu đóng bao (v6) — API cũ link-bag không cập nhật phiếu trên web
      if (_receiptId == null) {
        HapticFeedback.heavyImpact();
        _showSnack('❌ Chưa có phiếu đóng bao. Tải lại màn hình hoặc kiểm tra trạng thái LSX.', isError: true);
        return;
      }
      await ref.read(supplyRepositoryProvider).scanBagLinkV6(_receiptId!, packetCode, bagCode: bagUsed);
      HapticFeedback.mediumImpact();
      _showSnack('✅ Gói $packetCode → Bao $bagUsed', isError: false);
      // 1 lần quét = gắn cả lô gói vào bao → xóa bao để quét bao tiếp theo
      _clearBag();
      await _loadData(silent: true);
    } on DioException catch (e) {
      HapticFeedback.heavyImpact();
      final msg = e.response?.data?['message'] ?? 'Lỗi liên kết';
      final statusCode = e.response?.statusCode ?? 0;
      final msgLower = msg.toString().toLowerCase();
      if (statusCode == 404 || msgLower.contains('không tồn tại') || msgLower.contains('not found') || msgLower.contains('bag_code')) {
        final oldBag = _currentBagSerial;
        _clearBag();
        _showSnack('❌ Bao "$oldBag" không tồn tại. Gói chưa liên kết.', isError: true);
      } else {
        _showSnack('❌ $msg', isError: true);
      }
    } catch (e) {
      _showSnack('❌ $e', isError: true);
    } finally {
      setState(() => _isScanning = false);
      _scanController.clear();
      _refocus();
    }
  }

  void _clearBag() {
    setState(() { _currentBagSerial = null; _currentBagPacketCount = 0; });
  }

  // ─── Camera Continuous Mode ───
  void _openContinuousScanner() {
    String? camBag;
    bool isProcessing = false;
    String scanPhase = 'bag'; // 'bag' or 'packet'

    final camController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 1500,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.78,
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),

                // Status header
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: scanPhase == 'bag' ? kWarningColor.withOpacity(0.15) : kPrimaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scanPhase == 'bag' ? kWarningColor.withOpacity(0.4) : kPrimaryColor.withOpacity(0.4)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            scanPhase == 'bag' ? Icons.inventory_2 : Icons.qr_code,
                            color: scanPhase == 'bag' ? kWarningColor : kPrimaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            scanPhase == 'bag' ? 'Bước 1: Quét mã BAO (-B)' : 'Bước 2: Quét mã GÓI',
                            style: TextStyle(
                              color: scanPhase == 'bag' ? kWarningColor : kPrimaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      if (camBag != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Bao: $camBag',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),

                // Camera
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: MobileScanner(
                      controller: camController,
                      onDetect: (capture) async {
                        if (isProcessing) return;
                        for (final barcode in capture.barcodes) {
                          final rawCode = barcode.rawValue;
                          if (rawCode == null || rawCode.isEmpty) continue;
                          final code = _extractCode(rawCode);

                          if (scanPhase == 'bag') {
                            // Expect bag code
                            if (!_isBagCode(code)) {
                              HapticFeedback.heavyImpact();
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content: const Text('⚠️ Đây là mã gói! Quét mã BAO trước (-B)'),
                                  backgroundColor: Colors.red.shade700,
                                  duration: const Duration(seconds: 2),
                                ));
                              }
                              return;
                            }
                            camBag = code;
                            setSheetState(() => scanPhase = 'packet');
                            HapticFeedback.mediumImpact();
                            return;
                          }

                          if (scanPhase == 'packet') {
                            if (_isBagCode(code)) {
                              // User scanned another bag, switch
                              camBag = code;
                              setSheetState(() {});
                              HapticFeedback.mediumImpact();
                              return;
                            }
                            // Process packet
                            isProcessing = true;
                            try {
                              if (_receiptId == null) {
                                throw Exception('Chưa có phiếu đóng bao. Tải lại màn hình.');
                              }
                              await ref.read(supplyRepositoryProvider).scanBagLinkV6(_receiptId!, code, bagCode: camBag!);
                              HapticFeedback.mediumImpact();
                              final linkedBag = camBag!;
                              final linkedPacket = code;

                              // Close camera — 1 lần quét = gắn cả lô vào bao
                              camController.dispose();
                              if (sheetCtx.mounted) Navigator.pop(sheetCtx);

                              await _loadData();

                              if (mounted) {
                                _showSuccessOverlay(linkedBag, linkedPacket);
                              }
                            } catch (e) {
                              HapticFeedback.heavyImpact();
                              String errMsg = 'Lỗi';
                              if (e is DioException) {
                                errMsg = e.response?.data?['message']?.toString() ?? 'Lỗi liên kết';
                              }
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content: Text('❌ $errMsg'),
                                  backgroundColor: Colors.red.shade700,
                                  duration: const Duration(seconds: 2),
                                ));
                              }
                              // Stay in packet phase to retry
                            } finally {
                              isProcessing = false;
                            }
                            return;
                          }
                        }
                      },
                    ),
                  ),
                ),

                // Close button
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        camController.dispose();
                        Navigator.pop(sheetCtx);
                        _loadData(); // Reload data after closing
                      },
                      icon: const Icon(Icons.close, color: Colors.white),
                      label: const Text('Đóng camera', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSuccessOverlay(String bagCode, String packetCode) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        // Auto-dismiss after 2.5 seconds
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (ctx.mounted) Navigator.of(ctx).pop();
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kPrimaryColor.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(color: kPrimaryColor.withOpacity(0.3), blurRadius: 24, spreadRadius: 2),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: kPrimaryColor, size: 48),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ghép bao thành công!',
                  style: TextStyle(color: kTextLight, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.inventory_2, color: kWarningColor, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Bao: $bagCode',
                              style: const TextStyle(color: kTextLight, fontSize: 13, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.qr_code, color: kPrimaryColor, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Gói: $packetCode',
                              style: const TextStyle(color: kTextLight, fontSize: 13, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Bấm nút Scan để ghép bao tiếp',
                  style: TextStyle(color: kTextGray, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCompleteOrderDialog() async {
    bool refundUnused = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: kBackgroundDark,
            title: const Text('Chốt Lệnh Sản Xuất', style: TextStyle(color: kTextLight)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thao tác này sẽ chốt lệnh sản xuất. Bạn có đồng ý chốt lệnh?',
                  style: TextStyle(color: kTextGray, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Theme(
                      data: ThemeData(unselectedWidgetColor: kTextGray),
                      child: Checkbox(
                        value: refundUnused,
                        activeColor: kPrimaryColor,
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => refundUnused = val);
                          }
                        },
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Hoàn trả lại nguyên liệu thừa chưa đóng hết về tồn kho gốc',
                        style: TextStyle(color: kTextLight, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy', style: TextStyle(color: kTextGray)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                child: const Text('Xác nhận chốt', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await ref.read(supplyRepositoryProvider).completeProductionOrder(widget.orderId, refundUnused: refundUnused);
        _showSnack('✅ Chốt lệnh sản xuất thành công', isError: false);
        await _loadData();
      } on DioException catch (e) {
        final msg = e.response?.data?['message']?.toString() ?? 'Chốt lệnh thất bại';
        _showSnack('❌ $msg', isError: true);
        setState(() => _isLoading = false);
      } catch (e) {
        _showSnack('❌ Lỗi: $e', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showCancelOrderDialog() async {
    bool cancelConfirmed = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: kBackgroundDark,
            title: const Text('⚠️ Hủy Lệnh Sản Xuất', style: TextStyle(color: Colors.redAccent)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thao tác này không thể hoàn tác!',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '• Toàn bộ mã gói và mã bao đã sinh sẽ bị xóa vĩnh viễn\n'
                        '• Các phiếu sản xuất liên quan sẽ bị đóng\n'
                        '• Không thể hủy nếu đã có lô được liên kết bao',
                        style: TextStyle(color: kTextGray, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Theme(
                      data: ThemeData(unselectedWidgetColor: kTextGray),
                      child: Checkbox(
                        value: cancelConfirmed,
                        activeColor: Colors.redAccent,
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => cancelConfirmed = val);
                          }
                        },
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Tôi đã đọc kỹ và đồng ý hủy lệnh sản xuất',
                        style: TextStyle(color: kTextLight, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy', style: TextStyle(color: kTextGray)),
              ),
              ElevatedButton(
                onPressed: cancelConfirmed ? () => Navigator.pop(ctx, true) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                ),
                child: const Text('Xác nhận Hủy Lệnh', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await ref.read(supplyRepositoryProvider).cancelProductionOrder(widget.orderId);
        _showSnack('⚠️ Đã hủy lệnh sản xuất thành công', isError: false);
        await _loadData();
      } on DioException catch (e) {
        final msg = e.response?.data?['message']?.toString() ?? 'Hủy lệnh thất bại';
        _showSnack('❌ $msg', isError: true);
        setState(() => _isLoading = false);
      } catch (e) {
        _showSnack('❌ Lỗi: $e', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildOrderOperationsBox() {
    if (!['APPROVED', 'CODES_READY', 'IN_PROGRESS'].contains(_orderStatus)) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.precision_manufacturing, color: Colors.blueAccent, size: 18),
              SizedBox(width: 8),
              Text(
                'Thao tác Lệnh sản xuất',
                style: TextStyle(color: kTextLight, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showCompleteOrderDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Chốt Lệnh', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showCancelOrderDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Hủy Lệnh', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
            const Text('Đóng Bao', style: TextStyle(color: kTextLight, fontSize: 16)),
            if (_orderCode.isNotEmpty)
              Text('$_orderCode — $_productName', style: const TextStyle(color: kTextGray, fontSize: 12)),
          ],
        ),
        backgroundColor: kBackgroundDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextGray),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: kTextGray), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : SingleChildScrollView(
              child: Column(
                children: [
                  if (_isBagScanned) _buildCurrentBagBanner(),
                  _buildReceiptInfoBox(),
                  _buildOrderOperationsBox(),
                  _buildScanInput(),
                  _buildStats(),
                  _buildBagList(),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Future<void> _showCameraScanner() async {
    final String? result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerScreen(
          title: _isBagScanned ? 'Quét mã gói' : 'Quét mã bao',
          returnCode: true,
        ),
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      _scanController.text = result;
      _handleScan();
    }
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
                    Text(_isBagScanned ? 'Quét gói' : 'Quét bao', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
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
                onPressed: () async {
                  if (_receiptId == null) {
                    _showSnack('❌ Chưa có phiếu đóng bao — dữ liệu chưa gắn với web', isError: true);
                    return;
                  }
                  if (_selectedWarehouseId == null || _selectedWarehouseId!.isEmpty) {
                    _showSnack('❌ Vui lòng chọn kho lưu trước khi hoàn thành', isError: true);
                    return;
                  }
                  if (_bagMappings.isEmpty) {
                    _showSnack('Vui lòng quét bao trước', isError: true);
                    return;
                  }

                  try {
                    // Lưu và hoàn thành phiếu đóng bao
                    await ref.read(supplyRepositoryProvider).completeReceipt(_receiptId!);
                    _showSnack('✅ Đã lưu và hoàn thành đóng bao', isError: false);
                    if (mounted) Navigator.of(context).pop();
                  } on DioException catch (e) {
                    final msg = e.response?.data?['message']?.toString() ?? 'Lưu thất bại';
                    _showSnack('❌ $msg', isError: true);
                  } catch (e) {
                    _showSnack('❌ Lưu thất bại: $e', isError: true);
                  }
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

  Widget _buildBottomBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildReceiptInfoBox() {
    if (_receiptCode.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: kPrimaryColor, size: 18),
                  const SizedBox(width: 8),
                  Text(_receiptCode, style: const TextStyle(color: kTextLight, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _receiptStatus == 'COMPLETED' ? Colors.green.withOpacity(0.2) : kWarningColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _receiptStatus == 'COMPLETED' ? 'Đã hoàn thành' : 'Đang đóng gói',
                  style: TextStyle(
                    color: _receiptStatus == 'COMPLETED' ? Colors.green : kWarningColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInfoItem('Thời gian', _receiptTime, Icons.access_time)),
              Expanded(child: _buildInfoItem('Người đóng', _receiptUser, Icons.person_outline)),
            ],
          ),
          const SizedBox(height: 12),
          Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: const InputDecorationTheme(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            child: WarehouseSelector(
              label: 'Kho lưu (bắt buộc)',
              selectedId: _selectedWarehouseId,
              onChanged: (val) async {
                if (_receiptStatus == 'COMPLETED') {
                  _showSnack('❌ Phiếu đã hoàn thành, không thể sửa', isError: true);
                  return;
                }
                setState(() => _selectedWarehouseId = val);
                if (_receiptId != null && val != null) {
                  try {
                    await ref.read(supplyRepositoryProvider).updateReceiptWarehouse(_receiptId!, val);
                  } catch (e) {
                    _showSnack('❌ Lỗi cập nhật kho lưu', isError: true);
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: kTextGray),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: kTextGray, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value.isNotEmpty ? value : '--', style: const TextStyle(color: kTextLight, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentBagBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kPrimaryColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPrimaryColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2, color: kPrimaryColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bao: $_currentBagSerial', style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                Text('Đã quét $_currentBagPacketCount gói', style: TextStyle(color: kPrimaryColor.withOpacity(0.7), fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            onPressed: _clearBag,
            icon: const Icon(Icons.close, color: kPrimaryColor, size: 18),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
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
                  _isBagScanned ? '📦 Bước 2: Quét mã gói để liên kết' : '🏷️ Bước 1: Quét mã bao (hậu tố -B)',
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
                    hintText: _isBagScanned ? 'Quét/nhập mã gói...' : 'Quét/nhập mã bao (-B)...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    border: InputBorder.none,
                    prefixIcon: Icon(_isBagScanned ? Icons.qr_code : Icons.inventory_2, color: kPrimaryColor),
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
                    : const Text('Thêm'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final linkedCount = _bagMappings.where((b) => b.lotStatus == 'LINKED').length;
    final totalPackets = _bagMappings.fold<int>(0, (sum, b) => sum + b.packetCount);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: kSurfaceDark, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Tổng bao', '${_bagMappings.length}', kPrimaryColor),
          Container(width: 1, height: 30, color: Colors.white10),
          _statItem('Đã link', '$linkedCount', Colors.blue.shade300),
          Container(width: 1, height: 30, color: Colors.white10),
          _statItem('Tổng gói', '$totalPackets', Colors.amber.shade300),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: kTextGray)),
      ],
    );
  }

  Widget _buildBagList() {
    if (_bagMappings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white12),
            SizedBox(height: 12),
            Text('Chưa có bao nào', style: TextStyle(color: kTextGray)),
          ],
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _bagMappings.length,
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemBuilder: (context, index) {
        final bag = _bagMappings[index];
        final isActive = bag.bagSerial == _currentBagSerial;
        return Container(
          decoration: isActive
              ? BoxDecoration(border: Border.all(color: kPrimaryColor.withOpacity(0.5), width: 2), borderRadius: BorderRadius.circular(14))
              : null,
          margin: isActive ? const EdgeInsets.symmetric(horizontal: 14, vertical: 2) : EdgeInsets.zero,
          child: BagCardWidget(
            index: index,
            bagSerial: bag.bagSerial,
            bagQrCode: bag.bagQrCode,
            productName: bag.productName,
            packetCount: bag.packetCount,
            linkerName: bag.linkerName,
          ),
        );
      },
    );
  }
}
