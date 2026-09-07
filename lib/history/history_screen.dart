import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../scan/result_screen.dart';
import '../home/widgets/consumer_theme.dart';
import '../core/api_client.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  void _confirmClearAll(BuildContext context, Box box) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Xác nhận', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Bạn có chắc chắn muốn xóa toàn bộ lịch sử quét mã không?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              box.clear();
              Navigator.pop(ctx);
            },
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );
  }

  void _deleteItem(Box box, int originalIndex) {
    box.deleteAt(originalIndex);
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('scan_history');

    return Scaffold(
      backgroundColor: ConsumerTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Lịch sử quét', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: ConsumerTheme.backgroundDark,
        elevation: 0,
        centerTitle: true,
        actions: [
          ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, Box b, _) {
              if (b.values.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white70),
                tooltip: 'Xóa lịch sử',
                onPressed: () => _confirmClearAll(context, b),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box b, _) {
          if (b.values.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.history_rounded, size: 56, color: Colors.grey.withOpacity(0.5)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa có lịch sử quét mã',
                    style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Các mã QR bạn đã quét sẽ xuất hiện tại đây',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          final rawList = b.values.toList();
          // Index mapping to delete correctly from Hive
          final itemsWithIndex = List.generate(rawList.length, (i) => MapEntry(i, rawList[i] as Map)).reversed.toList();

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: itemsWithIndex.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = itemsWithIndex[index];
              final originalIndex = entry.key;
              final item = entry.value;

              final String code = (item['code'] ?? 'Unknown').toString();
              DateTime? scanTime;
              try {
                if (item['scanTime'] != null) {
                  scanTime = DateTime.parse(item['scanTime'].toString());
                }
              } catch (_) {}

              final String riskLevel = (item['riskLevel'] ?? 'NORMAL').toString();
              final String? productName = item['productName']?.toString();
              final String? supplierName = item['supplierName']?.toString();
              final String? thumbnailUrl = item['thumbnailUrl']?.toString();

              Color riskColor;
              String riskText;
              if (riskLevel == 'HIGH_RISK') {
                riskColor = Colors.redAccent;
                riskText = 'Rủi ro cao';
              } else if (riskLevel == 'WATCH') {
                riskColor = Colors.orangeAccent;
                riskText = 'Cảnh báo';
              } else {
                riskColor = const Color(0xFF00875A);
                riskText = 'Chính hãng';
              }

              return Dismissible(
                key: ValueKey('$originalIndex-$code-${item['scanTime']}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  padding: const EdgeInsets.only(right: 20),
                  alignment: Alignment.centerRight,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.delete, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Xóa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                onDismissed: (_) => _deleteItem(b, originalIndex),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ResultScreen(code: code, fromHistory: true),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16293D),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      children: [
                        // Thumbnail or Icon
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 52,
                            height: 52,
                            color: riskColor.withOpacity(0.12),
                            child: (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                                ? Image.network(
                                    getProxyImageUrl(thumbnailUrl),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(Icons.qr_code_2, color: riskColor, size: 28),
                                  )
                                : Icon(Icons.qr_code_2, color: riskColor, size: 28),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                productName ?? 'Sản phẩm: $code',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Mã: $code',
                                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: riskColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      riskText,
                                      style: TextStyle(color: riskColor, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              if (supplierName != null && supplierName.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  supplierName,
                                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 4),
                              if (scanTime != null)
                                Text(
                                  DateFormat('dd/MM/yyyy HH:mm').format(scanTime),
                                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
