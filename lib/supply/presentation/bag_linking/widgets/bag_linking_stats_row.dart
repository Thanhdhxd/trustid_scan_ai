import 'package:flutter/material.dart';

class BagLinkingStatsRow extends StatelessWidget {
  final int totalBags;
  final int linkedCount;
  final int totalPackets;
  final VoidCallback? onTapReplacePacket;

  const BagLinkingStatsRow({
    super.key,
    required this.totalBags,
    required this.linkedCount,
    required this.totalPackets,
    this.onTapReplacePacket,
  });

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF00875A);
    const surfaceDark = Color(0xFF16325B);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Tổng bao', '$totalBags', primaryColor),
          Container(width: 1, height: 30, color: Colors.white10),
          _statItem('Đã link', '$linkedCount', Colors.blue.shade300),
          Container(width: 1, height: 30, color: Colors.white10),
          _statItem('Tổng gói', '$totalPackets', Colors.amber.shade300),
          if (onTapReplacePacket != null) ...[
            Container(width: 1, height: 30, color: Colors.white10),
            TextButton.icon(
              onPressed: onTapReplacePacket,
              style: TextButton.styleFrom(
                foregroundColor: Colors.orangeAccent,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: const Text(
                'Thay gói',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
