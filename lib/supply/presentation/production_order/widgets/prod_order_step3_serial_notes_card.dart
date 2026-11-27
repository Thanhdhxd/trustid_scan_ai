import 'package:flutter/material.dart';
import '../constants/prod_order_constants.dart';
import 'prod_order_common_widgets.dart';

class ProdOrderStep3SerialNotesCard extends StatelessWidget {
  final TextEditingController serialPrefixCtrl;
  final String serialPreview;
  final VoidCallback onSerialPrefixChanged;
  final TextEditingController notesCtrl;

  const ProdOrderStep3SerialNotesCard({
    super.key,
    required this.serialPrefixCtrl,
    required this.serialPreview,
    required this.onSerialPrefixChanged,
    required this.notesCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return ProdOrderSectionCard(
      title: '3. Serial & Ghi Chú Kế Hoạch',
      icon: Icons.qr_code_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProdOrderFieldLabel('Mã prefix serial'),
          TextFormField(
            controller: serialPrefixCtrl,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            maxLength: 4,
            textCapitalization: TextCapitalization.characters,
            decoration: prodOrderInputDeco(null, hint: 'VD: AWD').copyWith(counterText: ''),
            onChanged: (_) => onSerialPrefixChanged(),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${serialPrefixCtrl.text.trim().length}/4 ký tự',
                style: const TextStyle(color: kProdOrderTextGray, fontSize: 11),
              ),
              const Text(' • ', style: TextStyle(color: kProdOrderTextGray, fontSize: 11)),
              const Text('Serial: ', style: TextStyle(color: kProdOrderTextGray, fontSize: 11)),
              Text(
                serialPreview,
                style: const TextStyle(
                  color: Colors.lightBlueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          const ProdOrderFieldLabel('Ghi chú / Chỉ dẫn sản xuất'),
          TextFormField(
            controller: notesCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            maxLines: 3,
            decoration: prodOrderInputDeco(null, hint: 'Nhập ghi chú hoặc yêu cầu QC...'),
          ),
        ],
      ),
    );
  }
}
