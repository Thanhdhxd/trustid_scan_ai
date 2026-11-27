import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/utils/app_toast.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';
import 'package:trustid_scan_ai/core/utils/scan_feedback_helper.dart';
import 'package:trustid_scan_ai/scan/scanner_screen.dart';
import '../../../data/supply_repository.dart';
import '../../production_order/constants/prod_order_constants.dart';
import '../../production_order/constants/prod_order_helpers.dart';

/// Sheet thay thế gói hỏng trên phiếu đóng bao đang mở (`POST /supply/packaging-receipts/:id/replace-packet`).
Future<bool?> showReplacePacketSheet(
  BuildContext context, {
  required String receiptId,
  String? prefillDamagedSerial,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: kProdOrderSurface,
    isScrollControlled: true,
    isDismissible: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ReplacePacketSheet(
      receiptId: receiptId,
      prefillDamagedSerial: prefillDamagedSerial,
    ),
  );
}

class _ReplacePacketSheet extends ConsumerStatefulWidget {
  final String receiptId;
  final String? prefillDamagedSerial;

  const _ReplacePacketSheet({
    required this.receiptId,
    this.prefillDamagedSerial,
  });

  @override
  ConsumerState<_ReplacePacketSheet> createState() => _ReplacePacketSheetState();
}

class _ReplacePacketSheetState extends ConsumerState<_ReplacePacketSheet> {
  static const _reasons = <(String, String)>[
    ('QUALITY_DEFECT', 'Hỏng / lỗi chất lượng'),
    ('TORN_PACKAGING', 'Rách bao bì'),
    ('DEFORMED', 'Móp / biến dạng'),
    ('OTHER', 'Khác'),
  ];

  late final TextEditingController _damagedCtrl;
  final TextEditingController _replacementCtrl = TextEditingController();
  String _reason = 'QUALITY_DEFECT';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _damagedCtrl = TextEditingController(
      text: widget.prefillDamagedSerial?.trim() ?? '',
    );
  }

  @override
  void dispose() {
    _damagedCtrl.dispose();
    _replacementCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanWithCamera(
    TextEditingController targetCtrl,
    String title,
  ) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ScannerScreen(title: title, isWarehouseMode: true),
      ),
    );
    if (result != null && result.trim().isNotEmpty && mounted) {
      final clean = extractSerialCodeFromQr(result);
      setState(() => targetCtrl.text = clean);
      ScanFeedbackHelper.playSuccess();
    }
  }

  Future<void> _submit() async {
    final damaged = extractSerialCodeFromQr(_damagedCtrl.text);
    final replacement = extractSerialCodeFromQr(_replacementCtrl.text);
    if (damaged.isEmpty || replacement.isEmpty) {
      AppToast.warning(context, 'Vui lòng nhập hoặc quét đủ mã gói hỏng và mã gói mới.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(supplyRepositoryProvider).replacePacketV2(
            widget.receiptId,
            damagedSerial: damaged,
            replacementSerial: replacement,
            reason: _reason,
          );
      ScanFeedbackHelper.playSuccess();
      if (!mounted) return;
      AppToast.success(context, 'Đã thay thế gói $damaged → $replacement.');
      Navigator.pop(context, true);
    } catch (e) {
      ScanFeedbackHelper.playError();
      if (!mounted) return;
      setState(() => _submitting = false);
      AppToast.error(context, parseSupplyHttpError(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final hasPrefill = (widget.prefillDamagedSerial ?? '').trim().isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: SingleChildScrollView(
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
                  children: [
                    const Icon(Icons.swap_horiz_rounded, color: kProdOrderAmber),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Thay thế gói hỏng',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _submitting ? null : () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close, color: kProdOrderTextGray),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 18),

                const Text(
                  'Lý do thay thế *',
                  style: TextStyle(color: kProdOrderTextSub, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _reason,
                  dropdownColor: kProdOrderSurface,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: prodOrderInputDeco(null),
                  items: _reasons
                      .map((r) => DropdownMenuItem(value: r.$1, child: Text(r.$2)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _reason = val);
                  },
                ),

                const SizedBox(height: 14),
                const Text(
                  'Bước 1: Mã gói hỏng cần thay *',
                  style: TextStyle(color: kProdOrderTextSub, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _damagedCtrl,
                        readOnly: hasPrefill,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontSize: 13.5,
                        ),
                        decoration: prodOrderInputDeco(null, hint: 'Quét/nhập mã gói hỏng...'),
                      ),
                    ),
                    if (!hasPrefill) ...[
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () => _scanWithCamera(_damagedCtrl, 'Quét mã gói hỏng'),
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFF1E4273)),
                        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 14),
                const Text(
                  'Bước 2: Mã gói mới thay vào *',
                  style: TextStyle(color: kProdOrderTextSub, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replacementCtrl,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontSize: 13.5,
                        ),
                        decoration: prodOrderInputDeco(null, hint: 'Quét/nhập mã gói mới...'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () => _scanWithCamera(_replacementCtrl, 'Quét mã gói mới'),
                      style: IconButton.styleFrom(backgroundColor: kProdOrderPrimary),
                      icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Xác nhận thay gói', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
