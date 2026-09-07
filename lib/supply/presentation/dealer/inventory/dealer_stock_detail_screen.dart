import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DealerStockDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  const DealerStockDetailScreen({super.key, required this.product});

  @override
  State<DealerStockDetailScreen> createState() => _DealerStockDetailScreenState();
}

class _DealerStockDetailScreenState extends State<DealerStockDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  late List<dynamic> _allSerials;
  int _loadedCount = 10;

  @override
  void initState() {
    super.initState();
    _allSerials = (widget.product['serials'] as List?) ?? [];
    if (_loadedCount > _allSerials.length) {
      _loadedCount = _allSerials.length;
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
      if (_loadedCount < _allSerials.length) {
        setState(() {
          _loadedCount += 10;
          if (_loadedCount > _allSerials.length) {
            _loadedCount = _allSerials.length;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleSerials = _allSerials.take(_loadedCount).toList();
    final hasMore = _loadedCount < _allSerials.length;
    final productName = widget.product['productName'] ?? 'Sản phẩm';

    return Scaffold(
      backgroundColor: const Color(0xFF0F2B46),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2B46),
        title: Text('Chi tiết mã - $productName', style: const TextStyle(color: Colors.white, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: visibleSerials.isEmpty
          ? const Center(child: Text('Không có chi tiết mã', style: TextStyle(color: Colors.white54)))
          : ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: visibleSerials.length + (hasMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == visibleSerials.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
                  );
                }

                final s = visibleSerials[index];
                final importDate = s['importDate'] != null 
                    ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(s['importDate']).toLocal()) 
                    : 'N/A';

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16325B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mã QR: ${s['fullQrCode'] ?? s['qrCode'] ?? s['codeString'] ?? 'N/A'}',
                                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Serial: ${s['serialNumber'] ?? ''}',
                                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (s['batchCode'] != null)
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Lô: ${s['batchCode']}', 
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (s['parentBagSerial'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('Nằm trong bao: ${s['parentBagSerial']}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                        ),
                      if (s['trackingCode'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('Phiếu: ${s['trackingCode']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                      if (s['sourceUnit'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('Nguồn: ${s['sourceUnit']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                      Text('Ngày nhập: $importDate', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
