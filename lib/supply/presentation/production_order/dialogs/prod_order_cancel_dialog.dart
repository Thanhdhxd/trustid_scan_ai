import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/utils/app_toast.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';
import '../../../data/supply_repository.dart';
import '../constants/prod_order_constants.dart';

/// Dialog Hủy Lệnh Sản Xuất (bắt buộc nhập lý do + xác nhận không thể hoàn tác).
Future<bool?> showProdOrderCancelDialog(
  BuildContext context, {
  required WidgetRef ref,
  required String orderId,
  required String orderCode,
  required VoidCallback onCancelled,
}) {
  final reasonCtrl = TextEditingController();
  bool confirmed = false;
  bool submitting = false;

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: kProdOrderSurface,
        title: Text(
          'Hủy Lệnh $orderCode',
          style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
                ),
                child: const Text(
                  'Thao tác này sẽ thu hồi toàn bộ mã chưa kích hoạt, hoàn hạn mức mã và hoàn nguyên liệu về kho gốc. Không thể hoàn tác!',
                  style: TextStyle(color: kProdOrderTextSub, fontSize: 12, height: 1.35),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 2,
                decoration: prodOrderInputDeco('Lý do hủy lệnh *', hint: 'Nhập lý do hủy...'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Checkbox(
                    value: confirmed,
                    activeColor: Colors.redAccent,
                    onChanged: (v) => setDialogState(() => confirmed = v ?? false),
                  ),
                  const Expanded(
                    child: Text(
                      'Tôi xác nhận hủy lệnh sản xuất này',
                      style: TextStyle(color: Colors.white, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: submitting ? null : () => Navigator.pop(ctx, false),
            child: const Text('Quay lại', style: TextStyle(color: kProdOrderTextGray)),
          ),
          ElevatedButton(
            onPressed: (!confirmed || submitting)
                ? null
                : () async {
                    final reason = reasonCtrl.text.trim();
                    if (reason.isEmpty) {
                      AppToast.warning(ctx, 'Vui lòng nhập lý do hủy lệnh.');
                      return;
                    }
                    setDialogState(() => submitting = true);
                    try {
                      await ref
                          .read(supplyRepositoryProvider)
                          .cancelProductionOrder(orderId, reason);
                      if (ctx.mounted) {
                        Navigator.pop(ctx, true);
                      }
                      onCancelled();
                    } catch (e) {
                      if (ctx.mounted) {
                        AppToast.error(ctx, parseSupplyHttpError(e).message);
                        setDialogState(() => submitting = false);
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Xác nhận hủy', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}
