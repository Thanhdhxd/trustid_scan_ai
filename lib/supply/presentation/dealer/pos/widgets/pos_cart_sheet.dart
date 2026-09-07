import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/supply/data/dealer_providers.dart';
import 'package:intl/intl.dart';
import 'pos_scanner_bar.dart';

class PosCartSheet extends ConsumerWidget {
  final VoidCallback? onCheckout;
  final VoidCallback onOpenScanner;
  const PosCartSheet({super.key, this.onCheckout, required this.onOpenScanner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(dealerCartProvider);
    final total = cartItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

    final formatCurrency = (dynamic v) {
      final numValue = num.tryParse(v.toString()) ?? 0;
      return NumberFormat.currency(locale: 'vi', symbol: 'đ').format(numValue);
    };

    void _showPacketsDialog(BuildContext ctx, CartItem item) {
      showDialog(
        context: ctx,
        builder: (c) => AlertDialog(
          backgroundColor: const Color(0xFF16325B),
          title: Text('Danh sách gói trong bao', style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: item.packets.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white12),
              itemBuilder: (context, index) {
                final packet = item.packets[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Serial: ${packet['serial'] ?? ''}', style: const TextStyle(color: Colors.white, fontFamily: 'monospace')),
                      Text('QR: ${packet['qrCode'] ?? ''}', style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontFamily: 'monospace')),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Đóng', style: TextStyle(color: Colors.white54)))
          ],
        ),
      );
    }

    void _editPriceDialog(BuildContext ctx, CartItem item) {
      final ctrl = TextEditingController(text: item.price.toInt().toString());
      showDialog(
        context: ctx,
        builder: (c) => AlertDialog(
          backgroundColor: const Color(0xFF16325B),
          title: Text(item.isBag ? 'Sửa đơn giá (1 gói trong bao)' : 'Sửa đơn giá', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.isBag)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Bao gồm ${item.quantity} gói. Thành tiền sẽ là: Đơn giá x ${item.quantity}.', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                ),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: const OutlineInputBorder(),
                  suffixText: item.isBag ? 'đ/gói' : 'đ',
                  suffixStyle: const TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hủy', style: TextStyle(color: Colors.white54))),
            TextButton(
              onPressed: () {
                final newPrice = double.tryParse(ctrl.text);
                if (newPrice != null) {
                  ref.read(dealerCartProvider.notifier).updatePrice(item.serialNumber, newPrice);
                }
                Navigator.pop(c);
              },
              child: const Text('Lưu', style: TextStyle(color: Colors.blueAccent)),
            )
          ],
        ),
      );
    }

    return Container(
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          PosScannerBar(onOpenScanner: onOpenScanner),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF1E293B),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Giỏ hàng (${cartItems.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                if (cartItems.isNotEmpty)
                  TextButton(
                    onPressed: () => ref.read(dealerCartProvider.notifier).clearCart(),
                    child: const Text('Xóa tất cả', style: TextStyle(color: Colors.redAccent)),
                  )
              ],
            ),
          ),
          Expanded(
            child: cartItems.isEmpty
                ? const Center(child: Text('Giỏ hàng trống', style: TextStyle(color: Colors.white54)))
                : ListView.separated(
                    itemCount: cartItems.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      final name = item.productInfo['productName'] ?? item.productInfo['name'] ?? 'Sản phẩm';
                      return Container(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                                      if (item.isBag)
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                          child: Text('Bao ${item.quantity} gói', style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                        )
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(item.qrCode, style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontFamily: 'monospace')),
                                  if (item.qrCode != item.serialNumber)
                                    Text('(${item.serialNumber})', style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace')),
                                  
                                  if (item.isBag && item.packets.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: InkWell(
                                        onTap: () => _showPacketsDialog(context, item),
                                        child: Text('Xem ${item.packets.length} gói con', style: const TextStyle(color: Colors.tealAccent, fontSize: 12, decoration: TextDecoration.underline)),
                                      ),
                                    )
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                InkWell(
                                  onTap: () => _editPriceDialog(context, item),
                                  child: Row(
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            formatCurrency(item.price * item.quantity),
                                            style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          if (item.isBag)
                                            Text(
                                              '${formatCurrency(item.price)}/gói x ${item.quantity}',
                                              style: const TextStyle(color: Colors.white54, fontSize: 10),
                                            ),
                                          if (item.discountPercent > 0)
                                            Row(
                                              children: [
                                                Text(formatCurrency(item.basePrice * item.quantity), style: const TextStyle(color: Colors.white54, fontSize: 10, decoration: TextDecoration.lineThrough)),
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                  decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                                                  child: Text('-${item.discountPercent.toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                                )
                                              ],
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.edit, color: Colors.white54, size: 14),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () => ref.read(dealerCartProvider.notifier).removeItem(item.serialNumber),
                                )
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(top: BorderSide(color: Colors.white12))
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tổng tiền', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        Text(formatCurrency(total), style: const TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  if (cartItems.isNotEmpty && onCheckout != null)
                    ElevatedButton.icon(
                      onPressed: onCheckout,
                      icon: const Icon(Icons.payment, color: Colors.white, size: 18),
                      label: const Text('Thanh toán', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00875A),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
