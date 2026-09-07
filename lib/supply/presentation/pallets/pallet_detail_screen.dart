import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/supply_repository.dart';
import '../../domain/pallet.dart';

final palletDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final repo = ref.read(supplyRepositoryProvider);
  return repo.getPalletDetail(id);
});

class PalletDetailScreen extends ConsumerStatefulWidget {
  final String palletId;

  const PalletDetailScreen({
    super.key,
    required this.palletId,
  });

  @override
  ConsumerState<PalletDetailScreen> createState() => _PalletDetailScreenState();
}

class _PalletDetailScreenState extends ConsumerState<PalletDetailScreen> {
  final Color kPrimaryColor = const Color(0xFF00875A);

  Future<void> _handleReleaseAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16325B),
        title: const Text('Xác nhận', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bạn có chắc chắn muốn giải phóng toàn bộ bao khỏi Pallet này không?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đồng ý', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(supplyRepositoryProvider).releasePallet(widget.palletId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã giải phóng Pallet thành công!')),
        );
        ref.refresh(palletDetailProvider(widget.palletId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _handleUnlink(String serial) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16325B),
        title: const Text('Xác nhận gỡ', style: TextStyle(color: Colors.white)),
        content: Text(
          'Bạn có muốn gỡ bao $serial ra khỏi Pallet không?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gỡ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(supplyRepositoryProvider).unlinkBagFromPallet(widget.palletId, serial);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gỡ bao thành công!')),
        );
        ref.refresh(palletDetailProvider(widget.palletId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(palletDetailProvider(widget.palletId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F2B46),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2B46),
        title: detailAsync.when(
          data: (data) {
            final code = data['palletCode'] ?? data['pallet_code'] ?? data['code'] ?? widget.palletId;
            return Text('Chi tiết – $code', style: const TextStyle(color: Colors.white, fontSize: 18));
          },
          loading: () => const Text('Đang tải...', style: TextStyle(color: Colors.white, fontSize: 18)),
          error: (_, __) => const Text('Lỗi', style: TextStyle(color: Colors.white, fontSize: 18)),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: detailAsync.when(
        data: (data) {
          final pallet = Pallet.fromJson(data);
          return _buildContent(pallet);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00875A))),
        error: (e, s) => Center(child: Text('Lỗi: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildContent(Pallet pallet) {
    final isFull = pallet.currentBagCount >= pallet.maxBags && pallet.maxBags > 0;
    final isInfinite = pallet.maxBags <= 0;
    final statusColor = isFull ? Colors.orange[400] : (pallet.currentBagCount > 0 ? Colors.blue[400] : Colors.grey[400]);

    return Column(
      children: [
        // Tổng quan
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF16325B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCol('MÃ PALLET', pallet.palletCode, Colors.white, isBold: true),
              _buildSummaryCol(
                'TRẠNG THÁI', 
                isFull ? 'Đã đầy' : (pallet.currentBagCount > 0 ? 'Đang xếp' : 'Trống'), 
                statusColor!,
                isBadge: true,
              ),
              _buildSummaryCol('SỨC CHỨA', '${pallet.currentBagCount} / ${isInfinite ? '∞' : pallet.maxBags} bao', Colors.white, isBold: true),
            ],
          ),
        ),

        // Danh sách sản phẩm (Bao)
        Expanded(
          child: pallet.bagMappings.isEmpty
              ? const Center(child: Text('Không có bao nào trong Pallet', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: pallet.bagMappings.length,
                  itemBuilder: (context, index) {
                    final item = pallet.bagMappings[index];
                    final serial = item.bagSerial;
                    final qr = item.bagQrCode ?? '';
                    final shortQr = qr.length > 10 ? '${qr.substring(0, 10)}...' : qr;
                    final product = item.productName ?? 'N/A';
                    final packetCount = item.packetCount ?? 0;
                    final linkerName = item.linkerName ?? 'N/A';
                    final timeStr = item.linkedAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(item.linkedAt!.toLocal()) : 'N/A';

                    return Card(
                      color: const Color(0xFF1A3A6B),
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text('#${index + 1}', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 12),
                                    Text(serial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                InkWell(
                                  onTap: () => _handleUnlink(serial),
                                  child: const Text('Gỡ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Divider(color: Colors.white.withOpacity(0.1), height: 1),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildDetailText('MÃ QR', shortQr),
                                _buildDetailText('SẢN PHẨM', product),
                                _buildDetailText('SỐ GÓI', '$packetCount'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildDetailText('NGƯỜI LIÊN KẾT', linkerName),
                                _buildDetailText('THỜI GIAN', timeStr),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Nút Giải phóng
        if (pallet.bagMappings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[400],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _handleReleaseAll,
                child: const Text('Giải phóng tất cả', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryCol(String label, String value, Color color, {bool isBold = false, bool isBadge = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        if (isBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          )
        else
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
      ],
    );
  }

  Widget _buildDetailText(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
