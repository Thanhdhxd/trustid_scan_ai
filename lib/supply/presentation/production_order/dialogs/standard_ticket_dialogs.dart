import 'package:flutter/material.dart';
import 'package:trustid_scan_ai/core/utils/app_toast.dart';
import '../constants/prod_order_constants.dart';
import '../constants/prod_order_helpers.dart';

/// Kết quả người dùng xác nhận trên Dialog hoàn thành Phiếu đóng gói tiêu chuẩn.
class CompleteStandardTicketInput {
  final double actualWeightKg;
  final DateTime? mfgDate;
  final DateTime? expiryDate;

  const CompleteStandardTicketInput({
    required this.actualWeightKg,
    this.mfgDate,
    this.expiryDate,
  });
}

/// Dialog xác nhận lưu & nhập kho Phiếu đóng gói Tiêu chuẩn (`API-16`).
Future<CompleteStandardTicketInput?> showCompleteStandardTicketDialog(
  BuildContext context, {
  required String ticketCode,
  required int packetCount,
  required double unitWeightKg,
  required double initialWeightKg,
  required double maxAllowedWeightKg,
  required String warehouseName,
  required String batchCode,
  DateTime? initialMfgDate,
  DateTime? initialExpiryDate,
}) {
  final clampedInit = initialWeightKg.clamp(0.01, maxAllowedWeightKg);
  final weightCtrl = TextEditingController(text: clampedInit.toStringAsFixed(2));
  DateTime? mfgDate = initialMfgDate;
  DateTime? expiryDate = initialExpiryDate;
  bool showDates = false;

  return showDialog<CompleteStandardTicketInput>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: kProdOrderSurface,
        title: Text(
          'Lưu phiếu $ticketCode & Nhập kho',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kProdOrderPrimary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kProdOrderPrimaryLight.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kích hoạt $packetCount tem gói và nhập kho thành phẩm.',
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kho: $warehouseName\nLô TP: $batchCode',
                      style: const TextStyle(color: kProdOrderTextSub, fontSize: 12, height: 1.35),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Lệnh SX vẫn mở để tạo thêm phiếu mới nếu cần.',
                      style: TextStyle(color: kProdOrderPrimaryLight, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Khối lượng thực tế nhập kho (kg) *',
                style: TextStyle(color: kProdOrderTextSub, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                decoration: prodOrderInputDeco(null, hint: '0.00'),
              ),
              const SizedBox(height: 6),
              Text(
                'Quy đổi: $packetCount gói × $unitWeightKg kg/gói = ${(packetCount * unitWeightKg).toStringAsFixed(2)} kg\nGiới hạn tối đa còn lại: ${maxAllowedWeightKg.toStringAsFixed(2)} kg',
                style: const TextStyle(color: kProdOrderTextGray, fontSize: 11.5, height: 1.35),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => setDialogState(() => showDates = !showDates),
                child: Row(
                  children: [
                    Icon(
                      showDates ? Icons.expand_less : Icons.expand_more,
                      color: kProdOrderPrimaryLight,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Kiểm tra / chỉnh NSX & HSD (nếu cần)',
                      style: TextStyle(color: kProdOrderPrimaryLight, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (showDates) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _dateTile(
                        label: 'NSX',
                        date: mfgDate,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: mfgDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) setDialogState(() => mfgDate = picked);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _dateTile(
                        label: 'HSD',
                        date: expiryDate,
                        onTap: () async {
                          final base = mfgDate ?? DateTime.now();
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: expiryDate ?? base,
                            firstDate: base,
                            lastDate: DateTime(2040),
                          );
                          if (picked != null) setDialogState(() => expiryDate = picked);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: kProdOrderTextGray)),
          ),
          ElevatedButton(
            onPressed: () {
              final w = double.tryParse(weightCtrl.text.trim()) ?? 0.0;
              if (w <= 0) {
                AppToast.warning(ctx, 'Khối lượng thực tế phải lớn hơn 0.');
                return;
              }
              if (w > maxAllowedWeightKg + 0.001) {
                AppToast.warning(
                  ctx,
                  'Khối lượng vượt quá giới hạn còn lại (${maxAllowedWeightKg.toStringAsFixed(2)} kg).',
                );
                return;
              }
              if (mfgDate != null &&
                  expiryDate != null &&
                  DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day).isBefore(
                    DateTime(mfgDate!.year, mfgDate!.month, mfgDate!.day),
                  )) {
                AppToast.warning(ctx, 'HSD không được nhỏ hơn NSX.');
                return;
              }
              Navigator.pop(
                ctx,
                CompleteStandardTicketInput(
                  actualWeightKg: w,
                  mfgDate: showDates ? mfgDate : null,
                  expiryDate: showDates ? expiryDate : null,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: kProdOrderPrimary),
            child: const Text('Lưu & Nhập kho', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

Widget _dateTile({
  required String label,
  required DateTime? date,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: kProdOrderBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kProdOrderCardBorder),
      ),
      child: Text(
        '$label: ${formatProdOrderDate(date)}',
        style: const TextStyle(color: Colors.white, fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

/// Dialog Hủy Phiếu đóng gói Tiêu chuẩn (`POST /supply/production-tickets/:id/reject`).
Future<String?> showRejectStandardTicketDialog(
  BuildContext context, {
  required String ticketCode,
}) {
  final reasonCtrl = TextEditingController();
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: kProdOrderSurface,
      title: Text(
        'Hủy phiếu $ticketCode',
        style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hủy phiếu sẽ giải phóng toàn bộ mã gói đang quét về trạng thái khả dụng.',
            style: TextStyle(color: kProdOrderTextSub, fontSize: 12.5, height: 1.35),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: reasonCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            maxLines: 2,
            decoration: prodOrderInputDeco('Lý do hủy phiếu *', hint: 'Nhập lý do hủy...'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Quay lại', style: TextStyle(color: kProdOrderTextGray)),
        ),
        ElevatedButton(
          onPressed: () {
            final reason = reasonCtrl.text.trim();
            if (reason.isEmpty) {
              AppToast.warning(ctx, 'Vui lòng nhập lý do hủy phiếu.');
              return;
            }
            Navigator.pop(ctx, reason);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          child: const Text('Xác nhận hủy', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}
