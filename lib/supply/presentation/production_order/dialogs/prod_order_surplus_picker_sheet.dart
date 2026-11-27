import 'package:flutter/material.dart';
import 'package:trustid_scan_ai/supply/domain/surplus_pool.dart';
import '../constants/prod_order_constants.dart';

class ProdOrderSurplusPickerSheet extends StatelessWidget {
  final List<SurplusPool> items;
  final String? selectedKey;
  final String productName;
  final ValueChanged<String?> onSelect;

  const ProdOrderSurplusPickerSheet({
    super.key,
    required this.items,
    required this.selectedKey,
    required this.productName,
    required this.onSelect,
  });

  static Future<void> show({
    required BuildContext context,
    required List<SurplusPool> items,
    required String? selectedKey,
    required String productName,
    required ValueChanged<String?> onSelect,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: kProdOrderBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ProdOrderSurplusPickerSheet(
        items: items,
        selectedKey: selectedKey,
        productName: productName,
        onSelect: onSelect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: kProdOrderAmber.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.archive_outlined, color: kProdOrderAmber, size: 16),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Chọn Kho Dư Bán Thành Phẩm',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Sản phẩm: $productName (${items.length} kho dư)',
                        style: const TextStyle(color: kProdOrderTextGray, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 20),
            if (items.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.archive_outlined, color: Colors.white24, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Không có kho dư BTP nào còn tồn (> 0 kg) cho sản phẩm này!',
                        style: TextStyle(color: kProdOrderTextGray.withOpacity(0.8), fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final pool = items[idx];
                    final isSelected = pool.id == selectedKey;
                    final pName = pool.product?.name ?? 'Sản phẩm BTP';
                    final pCode = pool.product?.code ?? pool.product?.sku ?? '';

                    return InkWell(
                      onTap: () {
                        onSelect(pool.id);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? kProdOrderAmber.withOpacity(0.15) : kProdOrderSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? kProdOrderAmber : Colors.white.withOpacity(0.08),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: kProdOrderAmber.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.inventory_2_outlined, color: kProdOrderAmber, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    pCode.isNotEmpty
                                        ? '$pCode • ${pool.availableEntryCount} mẻ dư • Hạn: ${pool.expiryDays} ngày'
                                        : '${pool.availableEntryCount} mẻ dư khả dụng • Hạn: ${pool.expiryDays} ngày',
                                    style: const TextStyle(color: kProdOrderTextGray, fontSize: 11.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF332A00),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: kProdOrderAmber.withOpacity(0.5)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Khả dụng',
                                    style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w500),
                                  ),
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: pool.availableWeightKg.toStringAsFixed(1),
                                          style: const TextStyle(
                                            color: kProdOrderAmber,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const TextSpan(
                                          text: ' kg',
                                          style: TextStyle(color: Colors.white70, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.check_circle_rounded, color: kProdOrderAmber, size: 20),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
