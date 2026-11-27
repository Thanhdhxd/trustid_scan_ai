import 'package:flutter/material.dart';
import 'package:trustid_scan_ai/supply/domain/surplus_pool.dart';
import '../constants/prod_order_constants.dart';
import '../constants/prod_order_helpers.dart';
import 'prod_order_common_widgets.dart';

/// Card Bước 1 khi tạo Lệnh Sản Xuất: sản phẩm, kho nhập, NSX/HSD, nguồn nguyên liệu & khối lượng.
class ProdOrderStep1MaterialsCard extends StatelessWidget {
  final String? selectedProductId;
  final List<Map<String, dynamic>> products;
  final ValueChanged<String?> onProductChanged;
  final Map<String, dynamic>? selectedProduct;
  final String? selectedWarehouseId;
  final List<Map<String, dynamic>> warehouses;
  final ValueChanged<String?> onWarehouseChanged;
  final double unitWeightKg;
  final bool isBagOrder;
  final double packagingSpec;
  final ValueChanged<bool> onIsBagOrderChanged;
  final DateTime plannedDate;
  final ValueChanged<DateTime> onPlannedDateChanged;
  final DateTime? expiryDate;
  final bool hasProductExpiry;
  final ValueChanged<DateTime> onExpiryDateChanged;
  final bool hasFarmFeature;
  final String sourceType; // FARM | EXTERNAL | CROSS_TENANT | SEMI_FINISHED | SURPLUS
  final ValueChanged<String> onSourceTypeChanged;
  final List<SurplusPool> filteredSurplusPools;
  final bool hasSelectedLot;
  final Map<String, dynamic>? selectedLot;
  final SurplusPool? selectedSurplusPool;
  final VoidCallback onOpenLotPicker;
  final TextEditingController plannedWeightCtrl;
  final String plannedWeightUnit;
  final ValueChanged<String> onPlannedWeightUnitChanged;
  final VoidCallback onPlannedWeightChanged;

  const ProdOrderStep1MaterialsCard({
    super.key,
    required this.selectedProductId,
    required this.products,
    required this.onProductChanged,
    required this.selectedProduct,
    required this.selectedWarehouseId,
    required this.warehouses,
    required this.onWarehouseChanged,
    required this.unitWeightKg,
    required this.isBagOrder,
    required this.packagingSpec,
    required this.onIsBagOrderChanged,
    required this.plannedDate,
    required this.onPlannedDateChanged,
    required this.expiryDate,
    required this.hasProductExpiry,
    required this.onExpiryDateChanged,
    required this.hasFarmFeature,
    required this.sourceType,
    required this.onSourceTypeChanged,
    required this.filteredSurplusPools,
    required this.hasSelectedLot,
    required this.selectedLot,
    required this.selectedSurplusPool,
    required this.onOpenLotPicker,
    required this.plannedWeightCtrl,
    required this.plannedWeightUnit,
    required this.onPlannedWeightUnitChanged,
    required this.onPlannedWeightChanged,
  });

  bool get _isFarm => sourceType == 'FARM';
  bool get _isSurplus => sourceType == 'SURPLUS';

  String get _sourceSubtitle {
    switch (sourceType) {
      case 'FARM':
        return 'Lô thu hoạch nông trại';
      case 'CROSS_TENANT':
        return 'Lô nhận B2B';
      case 'SEMI_FINISHED':
        return 'Lô bán thành phẩm (BTP)';
      case 'SURPLUS':
        return 'Mẻ dư đã lưu kho BTP';
      default:
        return 'Lô nhập ngoài';
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final selectedProductValid = selectedProductId != null &&
        products.any((p) => p['id']?.toString() == selectedProductId);
    final selectedWarehouseValid = selectedWarehouseId != null &&
        warehouses.any((w) => w['id']?.toString() == selectedWarehouseId);

    return ProdOrderSectionCard(
      title: '1. Thông Tin Sản Phẩm, Kho & Nguồn NL',
      icon: Icons.inventory_2_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1.1 Sản phẩm thành phẩm
          const ProdOrderFieldLabel('Sản phẩm thành phẩm', isRequired: true),
          DropdownButtonFormField<String>(
            initialValue: selectedProductValid ? selectedProductId : null,
            dropdownColor: kProdOrderSurface,
            icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white),
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            decoration: prodOrderInputDeco(null, hint: 'Chọn sản phẩm đóng gói...'),
            hint: const Text(
              'Chọn sản phẩm đóng gói...',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            isExpanded: true,
            items: products.map((p) {
              final name = p['name'] ?? 'Sản phẩm';
              final sku = p['sku'] ?? p['gtin'] ?? p['gtinCode'] ?? 'Không có SKU';
              return DropdownMenuItem<String>(
                value: p['id']?.toString(),
                child: Text(
                  '$name ($sku)',
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: onProductChanged,
          ),

          if (selectedProductId != null &&
              selectedProduct != null &&
              selectedProduct!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F3B5C),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.lightBlueAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: kProdOrderTextSub, fontSize: 12),
                        children: [
                          const TextSpan(text: 'Quy cách: '),
                          TextSpan(
                            text:
                                '${unitWeightKg.toStringAsFixed(unitWeightKg.truncateToDouble() == unitWeightKg ? 0 : 1)} kg/gói',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.lightBlueAccent,
                            ),
                          ),
                          if (isBagOrder) ...[
                            const TextSpan(text: ' | '),
                            TextSpan(
                              text: packagingSpec > 0
                                  ? '${packagingSpec.toInt()} gói/bao'
                                  : 'Chưa cài quy cách bao',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: packagingSpec > 0
                                    ? Colors.lightBlueAccent
                                    : kProdOrderAmber,
                              ),
                            ),
                          ],
                          if (hasProductExpiry) ...[
                            const TextSpan(text: ' | HSD: '),
                            TextSpan(
                              text:
                                  '${selectedProduct!['expiryDuration'] ?? selectedProduct!['expiry_duration']} ${productExpiryUnitLabel(selectedProduct)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.greenAccent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // 1.2 Kho nhập thành phẩm (bắt buộc cố định theo lệnh)
          const ProdOrderFieldLabel('Kho nhập thành phẩm', isRequired: true),
          DropdownButtonFormField<String>(
            initialValue: selectedWarehouseValid ? selectedWarehouseId : null,
            dropdownColor: kProdOrderSurface,
            icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white),
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            decoration: prodOrderInputDeco(null, hint: 'Chọn kho lưu thành phẩm...'),
            hint: const Text(
              'Chọn kho lưu thành phẩm...',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            isExpanded: true,
            items: warehouses.map((w) {
              final name = (w['name'] ?? 'Kho').toString();
              final isDef = w['isDefault'] == true || w['is_default'] == true;
              return DropdownMenuItem<String>(
                value: w['id']?.toString(),
                child: Text(
                  isDef ? '$name (Mặc định)' : name,
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: onWarehouseChanged,
          ),

          const SizedBox(height: 14),

          // 1.3 Ngày thực hiện / NSX dự kiến & Hạn sử dụng dự kiến
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ProdOrderFieldLabel('NSX dự kiến', isRequired: true),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: plannedDate.isBefore(todayDate) ? todayDate : plannedDate,
                          firstDate: todayDate,
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) onPlannedDateChanged(picked);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: kProdOrderFieldBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kProdOrderCardBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, color: Colors.white, size: 17),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                formatProdOrderDate(plannedDate),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProdOrderFieldLabel(
                      'HSD dự kiến',
                      isRequired: selectedProductId != null && !hasProductExpiry,
                    ),
                    InkWell(
                      onTap: (selectedProductId == null || hasProductExpiry)
                          ? null
                          : () async {
                              final minExp = DateTime(
                                plannedDate.year,
                                plannedDate.month,
                                plannedDate.day,
                              );
                              final init = (expiryDate != null && !expiryDate!.isBefore(minExp))
                                  ? expiryDate!
                                  : minExp;
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: init,
                                firstDate: minExp,
                                lastDate: DateTime(2040),
                              );
                              if (picked != null) onExpiryDateChanged(picked);
                            },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: (selectedProductId == null || hasProductExpiry)
                              ? kProdOrderFieldBg.withValues(alpha: 0.65)
                              : kProdOrderFieldBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: hasProductExpiry
                                ? Colors.greenAccent.withValues(alpha: 0.35)
                                : kProdOrderCardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              hasProductExpiry ? Icons.lock_clock : Icons.event_available,
                              color: hasProductExpiry ? Colors.greenAccent : Colors.white70,
                              size: 17,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                expiryDate != null
                                    ? formatProdOrderDate(expiryDate)
                                    : (selectedProductId == null
                                        ? 'Theo SP'
                                        : 'Chọn HSD...'),
                                style: TextStyle(
                                  color: expiryDate != null ? Colors.white : Colors.white54,
                                  fontSize: 13,
                                  fontWeight:
                                      expiryDate != null ? FontWeight.bold : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (selectedProductId != null) ...[
            const SizedBox(height: 4),
            Text(
              hasProductExpiry
                  ? 'HSD tự động tính theo sản phẩm (chốt chính thức khi chốt lệnh).'
                  : 'Sản phẩm chưa khai báo HSD mặc định — vui lòng chọn HSD dự kiến.',
              style: TextStyle(
                color: hasProductExpiry ? Colors.greenAccent : kProdOrderAmber,
                fontSize: 11,
              ),
            ),
          ],

          const SizedBox(height: 14),

          // 1.4 Loại đóng gói & Nguồn nguyên liệu (đồng bộ Web)
          InkWell(
            onTap: () => onIsBagOrderChanged(!isBagOrder),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isBagOrder
                    ? kProdOrderPrimary.withValues(alpha: 0.12)
                    : kProdOrderFieldBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isBagOrder
                      ? kProdOrderPrimary.withValues(alpha: 0.45)
                      : kProdOrderCardBorder,
                ),
              ),
              child: Row(
                children: [
                  Switch(
                    value: isBagOrder,
                    activeThumbColor: kProdOrderPrimaryLight,
                    onChanged: onIsBagOrderChanged,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Đóng bao thành phẩm',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isBagOrder ? 'Có đóng bao (gói → bao)' : 'Chỉ đóng gói lẻ',
                          style: const TextStyle(
                            color: kProdOrderTextGray,
                            fontSize: 11.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isBagOrder ? kProdOrderPrimary : Colors.white24)
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isBagOrder ? 'Có' : 'Không',
                      style: TextStyle(
                        color: isBagOrder ? kProdOrderPrimaryLight : kProdOrderTextGray,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Nguồn nguyên liệu đầu vào kiểu segmented pills như Web (Nhập ngoài | Farm | Nhận B2B)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kProdOrderFieldBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kProdOrderCardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final inline = constraints.maxWidth >= 520;
                    final headerInfo = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nguồn nguyên liệu',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _sourceSubtitle,
                          style: const TextStyle(
                            color: kProdOrderTextGray,
                            fontSize: 11.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    );

                    if (inline) {
                      return Row(
                        children: [
                          Expanded(child: headerInfo),
                          const SizedBox(width: 10),
                          Flexible(
                            flex: 0,
                            child: _buildSourceSegmentedGroup(expand: false),
                          ),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        headerInfo,
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: _buildSourceSegmentedGroup(expand: true),
                        ),
                      ],
                    );
                  },
                ),
                if (_isSurplus) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: kProdOrderAmber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: kProdOrderAmber.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: kProdOrderAmber, size: 15),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Lấy nguyên liệu từ mẻ dư đã lưu kho sau sơ chế hoặc đóng bao trước đó.',
                            style: TextStyle(color: Colors.white70, fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 1.5 Chọn Lô Nguồn (Remote Search / Kho dư)
          ProdOrderFieldLabel(_lotPickerLabel(), isRequired: true),
          InkWell(
            onTap: onOpenLotPicker,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selectedProductId == null
                    ? kProdOrderFieldBg.withValues(alpha: 0.5)
                    : kProdOrderFieldBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selectedProductId == null
                      ? kProdOrderCardBorder.withValues(alpha: 0.5)
                      : ((_isSurplus && hasSelectedLot)
                          ? kProdOrderAmber
                          : kProdOrderCardBorder),
                ),
              ),
              child: Row(
                children: [
                  if (selectedProductId == null) ...[
                    const Icon(Icons.info_outline, color: Colors.white38, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Vui lòng chọn sản phẩm đóng gói ở trên trước...',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else if (!hasSelectedLot) ...[
                    Expanded(
                      child: Text(
                        _lotPickerPlaceholder(),
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else if (_isSurplus) ...[
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.archive_outlined, color: kProdOrderAmber, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              selectedSurplusPool?.product?.name ?? 'Kho Dư BTP',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF332A00),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: kProdOrderAmber.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        'Dư: ${(selectedSurplusPool?.availableWeightKg ?? 0).toStringAsFixed(1)} kg',
                        style: const TextStyle(
                          color: kProdOrderAmber,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: Text(
                        (selectedLot?['batchCode'] ?? selectedLot?['batch_code'] ?? '').toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (selectedLot != null) _buildSelectedLotRemainingBadge(),
                  ],
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: selectedProductId == null ? Colors.white38 : Colors.white,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // 1.6 Khối lượng kế hoạch & Đơn vị
          const ProdOrderFieldLabel('Khối lượng kế hoạch', isRequired: true),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: plannedWeightCtrl,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: prodOrderInputDeco(null, hint: '0.0'),
                  onChanged: (_) => onPlannedWeightChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 95,
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: kProdOrderFieldBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kProdOrderCardBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: plannedWeightUnit,
                    dropdownColor: kProdOrderSurface,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'KG', child: Text('kg')),
                      DropdownMenuItem(value: 'YEN', child: Text('Yến')),
                      DropdownMenuItem(value: 'TA', child: Text('Tạ')),
                      DropdownMenuItem(value: 'TON', child: Text('Tấn')),
                    ],
                    onChanged: (val) {
                      if (val != null) onPlannedWeightUnitChanged(val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceSegmentedGroup({required bool expand}) {
    final options = <(String, String)>[
      ('EXTERNAL', 'Nhập ngoài'),
      if (hasFarmFeature) ('FARM', 'Farm'),
      ('CROSS_TENANT', 'Nhận B2B'),
    ];

    Widget buildItem(String value, String label) {
      final active = sourceType == value;
      final item = InkWell(
        onTap: () => onSourceTypeChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(horizontal: expand ? 8 : 14, vertical: 9),
          color: active ? kProdOrderPrimary : Colors.transparent,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : kProdOrderTextSub,
              fontSize: 12.5,
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
      return expand ? Expanded(child: item) : item;
    }

    return Container(
      decoration: BoxDecoration(
        color: kProdOrderSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0)
                  Container(
                    width: 1,
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                buildItem(options[i].$1, options[i].$2),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _lotPickerLabel() {
    switch (sourceType) {
      case 'FARM':
        return 'Chọn Lô Thu Hoạch Nông Trại';
      case 'CROSS_TENANT':
        return 'Chọn Lô Nhận B2B (Cross-Tenant)';
      case 'SEMI_FINISHED':
        return 'Chọn Lô Bán Thành Phẩm (BTP)';
      case 'SURPLUS':
        return 'Chọn Kho Dư Bán Thành Phẩm';
      default:
        return 'Chọn Lô Nguyên Liệu Nhập Ngoài';
    }
  }

  String _lotPickerPlaceholder() {
    switch (sourceType) {
      case 'FARM':
        return 'Tìm & chọn lô thu hoạch...';
      case 'CROSS_TENANT':
        return 'Tìm & chọn lô nhận B2B...';
      case 'SEMI_FINISHED':
        return 'Tìm & chọn lô BTP...';
      case 'SURPLUS':
        return 'Chọn kho dư BTP khả dụng...';
      default:
        return 'Tìm & chọn lô nguyên liệu...';
    }
  }

  Widget _buildSelectedLotRemainingBadge() {
    final raw = _isFarm
        ? (selectedLot!['remainingQuantityKg'] ??
            selectedLot!['quantityKg'] ??
            selectedLot!['totalQuantity'] ??
            0)
        : (selectedLot!['availableQuantity'] ??
            selectedLot!['remainingQuantityKg'] ??
            selectedLot!['totalQuantity'] ??
            selectedLot!['totalUnitsExpected'] ??
            selectedLot!['quantity'] ??
            0);
    final remainingKg = double.tryParse(raw.toString()) ?? 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0F3B5C),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.3)),
      ),
      child: Text(
        'Còn: ${remainingKg.toStringAsFixed(remainingKg.truncateToDouble() == remainingKg ? 0 : 1)} kg',
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
