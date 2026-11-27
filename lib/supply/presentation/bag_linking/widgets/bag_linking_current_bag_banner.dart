import 'package:flutter/material.dart';

class BagLinkingCurrentBagBanner extends StatelessWidget {
  final String currentBagSerial;
  final int currentBagPacketCount;
  final VoidCallback onClearBag;

  const BagLinkingCurrentBagBanner({
    super.key,
    required this.currentBagSerial,
    required this.currentBagPacketCount,
    required this.onClearBag,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF00875A);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2, color: primaryColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bao: $currentBagSerial',
                  style: const TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Đã quét $currentBagPacketCount gói',
                  style: TextStyle(
                    color: primaryColor.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClearBag,
            icon: const Icon(Icons.close, color: primaryColor, size: 18),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
