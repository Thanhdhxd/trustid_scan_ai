import 'package:flutter/material.dart';
import '../constants/prod_order_constants.dart';
import 'prod_order_common_widgets.dart';

class ProdOrderStep2ParamsCard extends StatelessWidget {
  final int estimatedUnits;
  final int estimatedBags;
  final bool isBagOrder;
  final int sparePacketQuantity;
  final int spareBagQuantity;
  final ValueChanged<int> onSparePacketQuantityChanged;
  final ValueChanged<int>? onSpareBagQuantityChanged;

  const ProdOrderStep2ParamsCard({
    super.key,
    required this.estimatedUnits,
    required this.estimatedBags,
    required this.isBagOrder,
    required this.sparePacketQuantity,
    required this.spareBagQuantity,
    required this.onSparePacketQuantityChanged,
    required this.onSpareBagQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ProdOrderSectionCard(
      title: '2. Thông Số Sản Xuất & Đóng Gói',
      icon: Icons.tune_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4 Ô: Số gói dự kiến, Số bao dự kiến, Số gói dự phòng, Số bao dự phòng
          Row(
            children: [
              Expanded(
                child: ProdOrderParamBox('Số gói dự kiến', '$estimatedUnits'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ProdOrderParamBox(
                  'Số bao dự kiến',
                  '${isBagOrder ? estimatedBags : 0}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ProdOrderSpinBox(
                  'Số gói dự phòng',
                  sparePacketQuantity,
                  onSparePacketQuantityChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ProdOrderSpinBox(
                  'Số bao dự phòng',
                  isBagOrder ? spareBagQuantity : 0,
                  onSpareBagQuantityChanged,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Dòng tổng kết: Dự kiến tổng cộng
          if (isBagOrder) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F3B5C),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.lightBlueAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: kProdOrderTextSub,
                        fontSize: 12,
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(text: '📋 '),
                        const TextSpan(
                          text: 'Dự kiến tổng cộng: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: '$estimatedBags',
                          style: const TextStyle(
                            color: Colors.lightBlueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const TextSpan(text: ' lô (bao) + '),
                        TextSpan(
                          text: '$spareBagQuantity',
                          style: const TextStyle(
                            color: Colors.lightBlueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const TextSpan(text: ' dự phòng = '),
                        TextSpan(
                          text: '${estimatedBags + spareBagQuantity} mã bao.',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: kProdOrderTextSub, fontSize: 12),
                      children: [
                        const TextSpan(text: 'Tổng số gói: '),
                        TextSpan(
                          text: '${estimatedUnits + sparePacketQuantity} mã gói.',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
