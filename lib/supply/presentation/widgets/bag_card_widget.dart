import 'package:flutter/material.dart';

class BagCardWidget extends StatelessWidget {
  final String bagSerial;
  final String? bagQrCode;
  final String? productName;
  final int? packetCount;
  final String? linkerName;
  final DateTime? linkedAt;
  final int index;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  static const Color kPrimaryColor = Color(0xFF00875A);
  static const Color kSurfaceDark = Color(0xFF16325B);
  static const Color kTextLight = Color(0xFFE8EDF3);
  static const Color kTextGray = Color(0xFF94A3B8);

  const BagCardWidget({
    super.key,
    required this.bagSerial,
    this.bagQrCode,
    this.productName,
    this.packetCount,
    this.linkerName,
    this.linkedAt,
    this.index = 0,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Index badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bagSerial,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: kTextLight, fontSize: 14),
                      ),
                      if (bagQrCode != null && bagQrCode!.isNotEmpty)
                        Text(
                          'QR: $bagQrCode',
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade300),
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (productName != null) ...[
                            Icon(Icons.inventory_2_outlined, size: 12, color: kTextGray),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                productName!,
                                style: const TextStyle(fontSize: 11, color: kTextGray),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          if (packetCount != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: kPrimaryColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$packetCount gói',
                                style: const TextStyle(fontSize: 10, color: kPrimaryColor, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Delete button
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 22),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
