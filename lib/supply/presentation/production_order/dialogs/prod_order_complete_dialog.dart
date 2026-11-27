import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/utils/app_toast.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';
import '../../../data/supply_repository.dart';
import '../../../domain/production_order.dart';
import '../constants/prod_order_constants.dart';
import '../constants/prod_order_helpers.dart';

/// Dialog Chốt hoàn thành (`NORMAL`) hoặc Dừng sản xuất sớm (`STOPPED`) đồng bộ 1:1 với Web `ProductionOrderDetail.vue`.
Future<bool?> showProdOrderCompleteDialog(
  BuildContext context, {
  required WidgetRef ref,
  required ProductionOrder order,
  String? closeType,
  Map<String, dynamic>? productData,
  required VoidCallback onCompleted,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: kProdOrderSurface,
    isScrollControlled: true,
    isDismissible: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ProdOrderCompleteSheet(
      ref: ref,
      order: order,
      initialCloseType: closeType,
      productData: productData,
      onCompleted: onCompleted,
    ),
  );
}

class _ProdOrderCompleteSheet extends StatefulWidget {
  final WidgetRef ref;
  final ProductionOrder order;
  final String? initialCloseType;
  final Map<String, dynamic>? productData;
  final VoidCallback onCompleted;

  const _ProdOrderCompleteSheet({
    required this.ref,
    required this.order,
    this.initialCloseType,
    this.productData,
    required this.onCompleted,
  });

  @override
  State<_ProdOrderCompleteSheet> createState() => _ProdOrderCompleteSheetState();
}

class _ProdOrderCompleteSheetState extends State<_ProdOrderCompleteSheet> {
  static const _stopReasons = <(String, String)>[
    ('OUT_OF_MATERIAL', 'Hết nguyên liệu / bán thành phẩm'),
    ('MACHINE_FAULT', 'Sự cố máy móc / thiết bị'),
    ('QUALITY_ISSUE', 'Vấn đề chất lượng (QC)'),
    ('OTHER', 'Lý do khác'),
  ];

  late final String _closeType; // 'NORMAL' | 'STOPPED'
  String? _stopReasonCode;
  final _stopNoteCtrl = TextEditingController();

  late DateTime _mfgDate;
  DateTime? _expiryDate;

  final _lossWeightCtrl = TextEditingController(text: '0.00');
  final _lossReasonCtrl = TextEditingController();
  String _remainderAction = 'REFUND'; // 'REFUND' | 'SURPLUS' | 'LOSS'
  DateTime? _surplusExpiryDate;

  bool _submitting = false;

  double get _remainingWeightKg {
    if (widget.order.summary != null) {
      return widget.order.summary!.remainingWeightKg;
    }
    final diff = widget.order.plannedWeightKg - widget.order.actualWeightKg;
    return diff > 0 ? diff : 0.0;
  }

  double get _lossKg {
    final normalized = _lossWeightCtrl.text.trim().replaceAll(',', '.');
    final parsed = double.tryParse(normalized) ?? 0.0;
    if (parsed < 0) return 0.0;
    return parsed > _remainingWeightKg ? _remainingWeightKg : parsed;
  }

  double get _rawLossInput {
    final normalized = _lossWeightCtrl.text.trim().replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0.0;
  }

  double get _usableRemainderKg {
    final usable = _remainingWeightKg - _lossKg;
    return usable > 0 ? usable : 0.0;
  }

  bool get _isStopped => _closeType == 'STOPPED';

  @override
  void initState() {
    super.initState();
    _closeType = widget.initialCloseType ??
        (_remainingWeightKg > 0.001 ? 'STOPPED' : 'NORMAL');
    _mfgDate = widget.order.mfgDate ?? widget.order.plannedDate ?? DateTime.now();
    _expiryDate = widget.order.expiryDate ??
        computeDefaultExpiryDate(_mfgDate, widget.productData);
    _surplusExpiryDate = null;
  }

  @override
  void dispose() {
    _stopNoteCtrl.dispose();
    _lossWeightCtrl.dispose();
    _lossReasonCtrl.dispose();
    super.dispose();
  }

  void _stepLoss(double delta) {
    final next = (_rawLossInput + delta).clamp(0.0, _remainingWeightKg);
    setState(() {
      _lossWeightCtrl.text = next.toStringAsFixed(2);
      if (next >= _remainingWeightKg - 0.0001 && _remainingWeightKg > 0) {
        _remainderAction = 'LOSS';
      } else if (_remainderAction == 'LOSS') {
        _remainderAction = 'REFUND';
      }
    });
  }

  Future<void> _submit() async {
    if (_isStopped && (_stopReasonCode == null || _stopReasonCode!.isEmpty)) {
      AppToast.warning(context, 'Vui lòng chọn lý do dừng sớm.');
      return;
    }
    if (_expiryDate != null &&
        DateTime(_expiryDate!.year, _expiryDate!.month, _expiryDate!.day).isBefore(
          DateTime(_mfgDate.year, _mfgDate.month, _mfgDate.day),
        )) {
      AppToast.warning(context, 'Hạn sử dụng không được nhỏ hơn ngày sản xuất.');
      return;
    }

    final hasRemainder = _remainingWeightKg > 0.001;
    final rawLoss = _rawLossInput;
    if (hasRemainder) {
      if (rawLoss < 0 || rawLoss > _remainingWeightKg + 0.001) {
        AppToast.warning(
          context,
          'Khối lượng hao hụt không được vượt quá phần nguyên liệu còn lại.',
        );
        return;
      }
      if (rawLoss > 0 && _lossReasonCtrl.text.trim().isEmpty) {
        AppToast.warning(context, 'Vui lòng nhập lý do hao hụt.');
        return;
      }
    }

    final effectiveAction = _usableRemainderKg <= 0.001
        ? 'LOSS'
        : (_remainderAction == 'LOSS' ? 'REFUND' : _remainderAction);

    setState(() => _submitting = true);
    try {
      final payload = <String, dynamic>{
        'close_type': _closeType,
        if (_isStopped) 'stop_reason_code': _stopReasonCode,
        if (_isStopped && _stopNoteCtrl.text.trim().isNotEmpty)
          'stop_note': _stopNoteCtrl.text.trim(),
        if (hasRemainder) 'remainder_action': effectiveAction,
        if (hasRemainder && effectiveAction == 'SURPLUS' && _surplusExpiryDate != null)
          'surplus_expiry_date': formatProdOrderDateIso(_surplusExpiryDate!),
        if (hasRemainder && rawLoss > 0) ...{
          'loss_weight_kg': rawLoss,
          'loss_reason': _lossReasonCtrl.text.trim(),
        },
        'mfg_date': formatProdOrderDateIso(_mfgDate),
        if (_expiryDate != null) 'expiry_date': formatProdOrderDateIso(_expiryDate!),
      };

      await widget.ref
          .read(supplyRepositoryProvider)
          .completeProductionOrder(widget.order.id, payload);

      if (!mounted) return;
      AppToast.success(context, 'Đã chốt lệnh sản xuất.');
      Navigator.pop(context, true);
      widget.onCompleted();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, parseSupplyHttpError(e).message);
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final hasRemainder = _remainingWeightKg > 0.001;
    final batchCode = widget.order.outputBatchCode ?? widget.order.orderCode;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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

              // Fixed Header
              Row(
                children: [
                  Icon(
                    _isStopped ? Icons.stop_circle_outlined : Icons.check_circle_outline,
                    color: _isStopped ? kProdOrderAmber : kProdOrderPrimaryLight,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isStopped ? 'Dừng Sản Xuất Sớm' : 'Chốt Lệnh Sản Xuất',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
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
              const Divider(color: Colors.white12, height: 16),

              // Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                // Banner tổng hợp Kế hoạch / Đã đóng / Còn dư (giống Web)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: kProdOrderPrimary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kProdOrderPrimaryLight.withValues(alpha: 0.35)),
                  ),
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      _summaryMetric(
                        'Kế hoạch',
                        '${widget.order.plannedWeightKg.toStringAsFixed(1)} kg',
                        Colors.white,
                      ),
                      _summaryMetric(
                        'Đã đóng',
                        '${widget.order.actualWeightKg.toStringAsFixed(1)} kg',
                        kProdOrderPrimaryLight,
                      ),
                      if (hasRemainder)
                        _summaryMetric(
                          'Còn dư',
                          '${_remainingWeightKg.toStringAsFixed(1)} kg',
                          kProdOrderAmber,
                        ),
                    ],
                  ),
                ),

                // Lý do dừng sớm & Ghi chú
                if (_isStopped) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kProdOrderAmber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kProdOrderAmber.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lý do dừng sớm *',
                          style: TextStyle(
                            color: kProdOrderTextSub,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _stopReasonCode,
                          dropdownColor: kProdOrderSurface,
                          hint: const Text(
                            'Chọn lý do dừng...',
                            style: TextStyle(color: kProdOrderTextGray, fontSize: 13),
                          ),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: prodOrderInputDeco(null),
                          items: _stopReasons
                              .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
                              .toList(),
                          onChanged: (v) => setState(() => _stopReasonCode = v),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Ghi chú',
                          style: TextStyle(
                            color: kProdOrderTextSub,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _stopNoteCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          maxLines: 2,
                          decoration: prodOrderInputDeco(null, hint: 'Mô tả chi tiết nếu có...'),
                        ),
                      ],
                    ),
                  ),
                ],

                // Xác nhận NSX & HSD chính thức
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.lightBlueAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(color: kProdOrderTextSub, fontSize: 12, height: 1.4),
                          children: [
                            const TextSpan(text: 'Xác nhận '),
                            const TextSpan(
                              text: 'NSX & HSD chính thức',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            const TextSpan(text: ' cho lô thành phẩm '),
                            TextSpan(
                              text: batchCode,
                              style: const TextStyle(
                                color: Colors.lightBlueAccent,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(text: ' (cố định sau khi chốt lệnh):'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ngày sản xuất chính thức (NSX)',
                                  style: TextStyle(color: kProdOrderTextGray, fontSize: 11),
                                ),
                                const SizedBox(height: 4),
                                _buildDateTile(
                                  date: _mfgDate,
                                  onPick: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _mfgDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2035),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _mfgDate = picked;
                                        final auto = computeDefaultExpiryDate(
                                          picked,
                                          widget.productData,
                                        );
                                        if (auto != null) _expiryDate = auto;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Hạn sử dụng chính thức (HSD)',
                                  style: TextStyle(color: kProdOrderTextGray, fontSize: 11),
                                ),
                                const SizedBox(height: 4),
                                _buildDateTile(
                                  date: _expiryDate,
                                  onPick: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _expiryDate ?? _mfgDate,
                                      firstDate: _mfgDate,
                                      lastDate: DateTime(2040),
                                    );
                                    if (picked != null) setState(() => _expiryDate = picked);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Xử lý phần còn lại & Hao hụt
                if (hasRemainder) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kProdOrderBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Chênh lệch còn lại: ${_remainingWeightKg.toStringAsFixed(2)} kg',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (_rawLossInput < _remainingWeightKg - 0.0001)
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _lossWeightCtrl.text = _remainingWeightKg.toStringAsFixed(2);
                                    _remainderAction = 'LOSS';
                                  });
                                },
                                child: Text(
                                  'Hao hụt toàn bộ (${_remainingWeightKg.toStringAsFixed(2)} kg)',
                                  style: const TextStyle(color: kProdOrderAmber, fontSize: 11.5),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Khối lượng hao hụt thực tế (kg)',
                          style: TextStyle(
                            color: kProdOrderTextSub,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _lossWeightCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: prodOrderInputDeco(null, hint: '0.00'),
                                onChanged: (_) => setState(() {
                                  if (_usableRemainderKg > 0.001 && _remainderAction == 'LOSS') {
                                    _remainderAction = 'REFUND';
                                  }
                                }),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _stepButton(Icons.remove, () => _stepLoss(-0.5)),
                            const SizedBox(width: 4),
                            _stepButton(Icons.add, () => _stepLoss(0.5)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(color: kProdOrderTextGray, fontSize: 11.5),
                            children: [
                              const TextSpan(text: 'Còn lại khả dụng sau hao hụt: '),
                              TextSpan(
                                text: '${_usableRemainderKg.toStringAsFixed(2)} kg',
                                style: const TextStyle(
                                  color: kProdOrderPrimaryLight,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_rawLossInput > 0) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Lý do hao hụt *',
                            style: TextStyle(color: kProdOrderTextSub, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _lossReasonCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: prodOrderInputDeco(null, hint: 'Nhập lý do hao hụt...'),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (_usableRemainderKg > 0.001) ...[
                          Text(
                            'Xử lý phần còn lại (${_usableRemainderKg.toStringAsFixed(2)} kg) *',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildRemainderOptionTile(
                            value: 'REFUND',
                            label: 'Hoàn trả về lô nguyên liệu gốc (+${_usableRemainderKg.toStringAsFixed(2)} kg)',
                            activeColor: kProdOrderPrimaryLight,
                          ),
                          const SizedBox(height: 6),
                          _buildRemainderOptionTile(
                            value: 'SURPLUS',
                            label: 'Nhập kho dư phẩm (Surplus +${_usableRemainderKg.toStringAsFixed(2)} kg)',
                            activeColor: kProdOrderAmber,
                          ),
                          if (_remainderAction == 'SURPLUS') ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Hạn sử dụng dư phẩm (tùy chọn)',
                              style: TextStyle(color: kProdOrderTextGray, fontSize: 11.5),
                            ),
                            const SizedBox(height: 4),
                            _buildDateTile(
                              date: _surplusExpiryDate,
                              emptyText: 'Chọn hạn giữ dư phẩm...',
                              onClear: _surplusExpiryDate != null
                                  ? () => setState(() => _surplusExpiryDate = null)
                                  : null,
                              onPick: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _surplusExpiryDate ?? _expiryDate ?? DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2040),
                                );
                                if (picked != null) {
                                  setState(() => _surplusExpiryDate = picked);
                                }
                              },
                            ),
                          ],
                        ] else ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.withValues(alpha: 0.45)),
                            ),
                            child: Text(
                              'Toàn bộ ${_remainingWeightKg.toStringAsFixed(2)} kg được ghi nhận là hao hụt (LOSS), không hoàn trả kho gốc.',
                              style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                    ],
                  ),
                ),
              ),

              // Fixed Footer buttons (Hủy + Xác nhận)
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: _submitting ? null : () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Hủy', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 6,
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isStopped ? Colors.orange.shade700 : kProdOrderPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                _isStopped ? 'Xác nhận Dừng Sớm' : 'Xác nhận Chốt Lệnh',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryMetric(String label, String value, Color valueColor) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: kProdOrderTextSub, fontSize: 12),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 38,
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: Colors.white70,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }

  Widget _buildRemainderOptionTile({
    required String value,
    required String label,
    required Color activeColor,
  }) {
    final selected = _remainderAction == value;
    return InkWell(
      onTap: () => setState(() => _remainderAction = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? activeColor.withValues(alpha: 0.14) : kProdOrderSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? activeColor : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? activeColor : kProdOrderTextGray,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTile({
    required DateTime? date,
    required VoidCallback onPick,
    String emptyText = '—',
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: kProdOrderSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kProdOrderCardBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 14, color: kProdOrderTextGray),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                date != null ? formatProdOrderDate(date) : emptyText,
                style: TextStyle(
                  color: date != null ? Colors.white : kProdOrderTextGray,
                  fontSize: 12.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 15, color: kProdOrderTextGray),
              ),
          ],
        ),
      ),
    );
  }
}
