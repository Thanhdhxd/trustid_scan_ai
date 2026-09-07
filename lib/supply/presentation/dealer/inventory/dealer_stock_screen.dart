import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/supply/data/dealer_repository.dart';
import 'package:intl/intl.dart';
import 'dealer_stock_detail_screen.dart';

class DealerStockScreen extends ConsumerStatefulWidget {
  const DealerStockScreen({super.key});

  @override
  ConsumerState<DealerStockScreen> createState() => _DealerStockScreenState();
}

class _DealerStockScreenState extends ConsumerState<DealerStockScreen> {
  bool _isLoading = true;
  List<dynamic> _inventory = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(dealerRepositoryProvider);
      final items = await repo.getDealerStock();
      if (mounted) setState(() => _inventory = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSerialsDialog(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DealerStockDetailScreen(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2B46),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2B46),
        title: const Text('Báo cáo Tồn kho', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Lỗi: $_error', style: const TextStyle(color: Colors.red)))
              : _inventory.isEmpty
                  ? const Center(child: Text('Không có dữ liệu tồn kho', style: TextStyle(color: Colors.white54)))
                  : RefreshIndicator(
                      onRefresh: _fetchInventory,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _inventory.length,
                        itemBuilder: (context, index) {
                          final item = _inventory[index];
                          final int inflow = item['inflow'] ?? 0;
                          final int outflow = item['outflow'] ?? 0;
                          final int currentStock = item['currentStock'] ?? 0;

                          return Card(
                            color: const Color(0xFF16325B),
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.inventory_2, color: Colors.blueAccent),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item['productName'] ?? 'Sản phẩm',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: currentStock > 0 ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Tồn: $currentStock',
                                          style: TextStyle(
                                            color: currentStock > 0 ? Colors.greenAccent : Colors.redAccent,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildStockMetric('Đầu kỳ', '${item['beginningStock'] ?? 0}', Colors.white70),
                                      _buildStockMetric('Nhập', '+$inflow', inflow > 0 ? Colors.greenAccent : Colors.white70),
                                      _buildStockMetric('Xuất', '-$outflow', outflow > 0 ? Colors.orangeAccent : Colors.white70),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Divider(color: Colors.white.withOpacity(0.1)),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () => _showSerialsDialog(item),
                                      icon: const Icon(Icons.info_outline, size: 18),
                                      label: const Text('Xem mã Serial'),
                                      style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildStockMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
