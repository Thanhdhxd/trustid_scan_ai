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
    final fillPercent = maxBags > 0 ? (currentBags / maxBags).clamp(0.0, 1.0) : 0.0;
    final isFull = maxBags > 0 && currentBags >= maxBags;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPrimaryColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
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
                  color: kPrimaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.palette_outlined, color: kPrimaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      palletCode,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: kTextLight,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: _statusColor,
                          fontWeight: FontWeight.w600,
                        ),
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
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor,
                    ),
                  ),
                  const Text('bao', style: TextStyle(fontSize: 11, color: kTextGray)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fillPercent,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(isFull ? Colors.orange : kPrimaryColor),
            ),
          ),
          if (isFull)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Pallet đã đạt sức chứa tối đa',
                style: TextStyle(fontSize: 11, color: Colors.orange.shade300),
              ),
            ),
        ],
      ),
    );
  }

  Color get _statusColor {
    switch (status.toUpperCase()) {
      case 'LOADING':
      case 'ACTIVE':
        return kPrimaryColor;
      case 'LOADED':
      case 'FULL':
        return Colors.orange;
      case 'EXPORTING':
      case 'SEALED':
        return Colors.lightBlueAccent;
      default:
        return kTextGray;
    }
  }

  String get _statusLabel {
    switch (status.toUpperCase()) {
      case 'EMPTY':
        return 'Trống';
      case 'LOADING':
      case 'ACTIVE':
        return 'Đang xếp';
      case 'LOADED':
      case 'FULL':
        return 'Đã đầy';
      case 'EXPORTING':
        return 'Đang xuất';
      case 'SEALED':
        return 'Đã niêm';
      default:
        return status;
    }
  }
}
