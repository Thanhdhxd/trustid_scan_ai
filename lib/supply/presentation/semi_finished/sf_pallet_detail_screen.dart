import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/supply_repository.dart';

final sfPalletDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final repo = ref.read(supplyRepositoryProvider);
  return repo.getSFPalletDetail(id);
});

class SFPalletDetailScreen extends ConsumerStatefulWidget {
  final String palletId;

  const SFPalletDetailScreen({
    super.key,
    required this.palletId,
  });

  @override
  ConsumerState<SFPalletDetailScreen> createState() => _SFPalletDetailScreenState();
}

class _SFPalletDetailScreenState extends ConsumerState<SFPalletDetailScreen> {
  final Color kPrimaryColor = const Color(0xFF00875A);

  Future<void> _handleReleaseAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16325B),
        title: const Text('Xác nhận', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bạn có chắc chắn muốn gỡ toàn bộ sản phẩm khỏi Pallet này không?',
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
      await ref.read(supplyRepositoryProvider).releaseSFPallet(widget.palletId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã giải phóng Pallet thành công!')),
        );
        ref.refresh(sfPalletDetailProvider(widget.palletId));
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
          'Bạn có muốn gỡ sản phẩm $serial ra khỏi Pallet không?',
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
      await ref.read(supplyRepositoryProvider).unlinkBagFromSFPallet(widget.palletId, serial);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gỡ sản phẩm thành công!')),
        );
        ref.refresh(sfPalletDetailProvider(widget.palletId));
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
    final detailAsync = ref.watch(sfPalletDetailProvider(widget.palletId));

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
        data: (data) => _buildContent(data),
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00875A))),
        error: (e, s) => Center(child: Text('Lỗi: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> data) {
    final code = data['palletCode'] ?? data['pallet_code'] ?? data['code'] ?? 'N/A';
    final itemCount = data['itemCount'] ?? data['item_count'] ?? data['currentBagCount'] ?? data['currentBatchCount'] ?? data['quantity'] ?? 0;
    final maxCapacity = data['maxCapacity'] ?? data['max_capacity'] ?? 10;
    final totalWeight = data['totalWeight'] ?? data['total_weight'] ?? 0.0;
    
    final items = (data['items'] as List?) ?? [];
    
    String statusText = 'Trống';
    final rawStatus = (data['status'] ?? '').toString().toUpperCase();
    if (rawStatus == 'FULL' || rawStatus == 'ĐÃ ĐẦY' || rawStatus == 'SEALED') statusText = 'Đã đầy';
    else if (rawStatus == 'IN_PROGRESS' || rawStatus == 'FILLING' || rawStatus == 'ĐANG XẾP' || rawStatus == 'LOADING') statusText = 'Đang xếp';
    else if (rawStatus == 'EMPTY' || rawStatus == 'TRỐNG') statusText = 'Trống';
    else if (rawStatus.isNotEmpty) statusText = data['status'].toString();
    else if (itemCount >= maxCapacity && maxCapacity > 0) statusText = 'Đã đầy';
    else if (itemCount > 0) statusText = 'Đang xếp';

    final statusColor = statusText == 'Đã đầy' ? Colors.orange[400] : (statusText == 'Đang xếp' ? Colors.blue[400] : Colors.grey[400]);

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
              _buildSummaryCol('MÃ PALLET', code, Colors.white, isBold: true),
              _buildSummaryCol(
                'TRẠNG THÁI', 
                statusText, 
                statusColor!,
                isBadge: true,
              ),
              _buildSummaryCol('SỐ SP', '$itemCount / $maxCapacity', Colors.white, isBold: true),
              _buildSummaryCol('TỔNG KL', '$totalWeight kg', Colors.blue[400]!, isBold: true),
            ],
          ),
        ),

        // Danh sách sản phẩm
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('Không có sản phẩm nào trong Pallet', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final serial = item['serial'] ?? item['itemSerial'] ?? 'N/A';
                    final qr = item['qrCode'] ?? item['qr_code'] ?? '';
                    final shortQr = qr.length > 10 ? '${qr.substring(0, 10)}...' : qr;
                    final batch = item['batchCode'] ?? item['batch_code'] ?? 'N/A';
                    final product = item['productName'] ?? item['product_name'] ?? 'N/A';
                    final weight = item['weight'] ?? 0.0;
                    
                    dynamic rawCreator = item['creator'] ?? item['createdBy'];
                    String creatorName = 'Demo';
                    if (rawCreator is Map) {
                      creatorName = rawCreator['fullName'] ?? rawCreator['username'] ?? rawCreator['name'] ?? 'Demo';
                    } else if (rawCreator != null) {
                      creatorName = rawCreator.toString();
                    }

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
                                _buildDetailText('MÃ LÔ', batch),
                                _buildDetailText('KL (KG)', '$weight'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildDetailText('SẢN PHẨM', product),
                                _buildDetailText('NGƯỜI GẮN', creatorName),
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
        if (items.isNotEmpty)
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
