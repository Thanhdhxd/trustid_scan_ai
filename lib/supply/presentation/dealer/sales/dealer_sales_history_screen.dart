import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/supply/data/dealer_providers.dart';
import 'package:intl/intl.dart';

class DealerSalesHistoryScreen extends ConsumerStatefulWidget {
  const DealerSalesHistoryScreen({super.key});

  @override
  ConsumerState<DealerSalesHistoryScreen> createState() => _DealerSalesHistoryScreenState();
}

class _DealerSalesHistoryScreenState extends ConsumerState<DealerSalesHistoryScreen> {
  final int _currentPage = 1;

  void _showDetailDialog(Map<String, dynamic> sale) {
    final formatCurrency = (dynamic v) {
      final numValue = num.tryParse(v.toString()) ?? 0;
      return NumberFormat.currency(locale: 'vi', symbol: 'đ').format(numValue);
    };

    final items = (sale['items'] as List?) ?? [];
    final customerName = sale['customerName'] ?? 'Khách lẻ';
    final customerPhone = sale['customerPhone'] ?? '---';
    final paymentMethodRaw = sale['paymentMethod'] ?? 'CASH';
    final saleDateRaw = sale['saleDate'];
    final formattedTime = saleDateRaw != null 
        ? DateFormat('HH:mm dd/MM/yyyy').format(DateTime.parse(saleDateRaw).toLocal()) 
        : '---';
    
    String paymentMethodLabel = 'Tiền mặt';
    if (paymentMethodRaw.toString().toUpperCase() == 'TRANSFER') {
      paymentMethodLabel = 'Chuyển khoản / Quẹt thẻ';
    } else if (paymentMethodRaw.toString().toUpperCase() == 'BANK_TRANSFER') {
      paymentMethodLabel = 'Chuyển khoản';
    } else if (paymentMethodRaw.toString().toUpperCase() == 'CARD') {
      paymentMethodLabel = 'Thẻ';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16325B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Chi tiết Hóa đơn',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F2B46),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Mã hóa đơn', sale['receiptNumber'] ?? (sale['id'] as String).split('-')[0].toUpperCase()),
                          const SizedBox(height: 8),
                          _buildDetailRow('Khách hàng', customerName),
                          const SizedBox(height: 8),
                          _buildDetailRow('SĐT', customerPhone),
                          const SizedBox(height: 8),
                          _buildDetailRow('Thanh toán', paymentMethodLabel),
                          const SizedBox(height: 8),
                          _buildDetailRow('Thời gian', formattedTime),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Danh sách Sản phẩm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    ...items.map((item) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F2B46),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(item['productName'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                Text(formatCurrency(item['price'] ?? 0), style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('QR: ${item['qrCode'] ?? item['serialNumber']}', style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace')),
                            if (item['qrCode'] != null && item['qrCode'] != item['serialNumber'])
                              Text('Serial: ${item['serialNumber']}', style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace')),
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text('Tổng cộng: ', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                          formatCurrency(sale['totalAmount'] ?? 0),
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14))),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(dealerSalesHistoryProvider(_currentPage));
    final formatCurrency = (dynamic v) {
      final numValue = num.tryParse(v.toString()) ?? 0;
      return NumberFormat.currency(locale: 'vi', symbol: 'đ').format(numValue);
    };

    return Scaffold(
      backgroundColor: const Color(0xFF0F2B46),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2B46),
        title: const Text('Lịch sử bán hàng', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: historyAsync.when(
        data: (sales) {
          if (sales.isEmpty) {
            return const Center(child: Text('Chưa có dữ liệu giao dịch', style: TextStyle(color: Colors.white54)));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(dealerSalesHistoryProvider(_currentPage)),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sales.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final sale = sales[index];
                final date = sale['saleDate'] != null ? DateTime.parse(sale['saleDate']).toLocal() : DateTime.now();
                final customerName = sale['customerName'] ?? 'Khách lẻ';
                final amount = formatCurrency(sale['totalAmount'] ?? 0);
                final itemsCount = (sale['items'] as List?)?.length ?? 0;
                final receipt = sale['receiptNumber'] ?? (sale['id'] as String).split('-')[0].toUpperCase();

                return InkWell(
                  onTap: () => _showDetailDialog(sale),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
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
                          children: [
                            Text(receipt, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                            Text(amount, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$customerName', style: const TextStyle(color: Colors.white)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
                              child: Text('$itemsCount SP', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(DateFormat('HH:mm dd/MM/yyyy').format(date), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Lỗi: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }
}
