import 'package:flutter/material.dart';

class PalletInfoCard extends StatelessWidget {
  final String palletCode;
  final String status;
  final int currentBags;
  final int maxBags;

  static const Color kPrimaryColor = Color(0xFF00875A);
  static const Color kSurfaceDark = Color(0xFF16325B);
  static const Color kTextLight = Color(0xFFE8EDF3);
  static const Color kTextGray = Color(0xFF94A3B8);

  const PalletInfoCard({
    super.key,
    required this.palletCode,
    required this.status,
    required this.currentBags,
    required this.maxBags,
  });

  @override
  Widget build(BuildContext context) {
    final fillPercent = maxBags > 0 ? currentBags / maxBags : 0.0;
    final isFull = currentBags >= maxBags;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.palette_outlined, color: kPrimaryColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      palletCode,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextLight, letterSpacing: 1),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _statusLabel,
                        style: TextStyle(fontSize: 11, color: _statusColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$currentBags / $maxBags',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimaryColor),
                  ),
                  const Text('bao', style: TextStyle(fontSize: 11, color: kTextGray)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fillPercent,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(isFull ? Colors.orange : kPrimaryColor),
            ),
          ),
          if (isFull)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('⚠️ Pallet đã đầy', style: TextStyle(fontSize: 11, color: Colors.orange.shade300)),
            ),
        ],
      ),
    );
  }

  Color get _statusColor {
    switch (status.toUpperCase()) {
      case 'ACTIVE': return kPrimaryColor;
      case 'FULL': return Colors.orange;
      case 'SEALED': return Colors.blue;
      default: return kTextGray;
    }
  }

  String get _statusLabel {
    switch (status.toUpperCase()) {
      case 'EMPTY': return 'Trống';
      case 'ACTIVE': return 'Đang xếp';
      case 'FULL': return 'Đã đầy';
      case 'SEALED': return 'Đã niêm';
      default: return status;
    }
  }
}
