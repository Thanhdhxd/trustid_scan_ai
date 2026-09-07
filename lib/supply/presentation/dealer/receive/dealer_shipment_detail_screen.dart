import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:trustid_scan_ai/supply/data/dealer_providers.dart';

const Color kDealerBg = Color(0xFF0F2B46);
const Color kDealerSurface = Color(0xFF16325B);
const Color kDealerText = Color(0xFFF8FAFC);
const Color kDealerTextMuted = Color(0xFF94A3B8);
const Color kDealerPrimary = Color(0xFF00875A);

class DealerShipmentDetailScreen extends ConsumerWidget {
  final String shipmentId;
  const DealerShipmentDetailScreen({super.key, required this.shipmentId});

  String _formatDateFull(dynamic iso) {
    if (iso == null || iso.toString().isEmpty) return '---';
    try {
      final d = DateTime.parse(iso.toString()).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(d);
    } catch (_) {
      return iso.toString();
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'CREATED': return 'Mới tạo';
      case 'SCANNING': return 'Đang quét hàng';
      case 'READY': return 'Sẵn sàng giao';
      case 'READY_FOR_PICKUP': return 'Chờ lấy hàng';
      case 'WAITING_DRIVER': return 'Chờ tài xế nhận';
      case 'IN_TRANSIT': return 'Đang vận chuyển';
      case 'PENDING_DEALER_CONFIRM': return 'Chờ xác nhận nhận';
      case 'DELIVERED': return 'Tài xế đã giao';
      case 'AT_DEALER': return 'Đã nhận vào kho';
      case 'CANCELLED': return 'Đã hủy';
      default: return status;
    }
  }

  List<Map<String, dynamic>> _buildTimeline(Map<String, dynamic> data) {
    List<Map<String, dynamic>> events = [];
    if (data['createdAt'] != null) {
      events.add({
        'time': DateTime.parse(data['createdAt']).toLocal(),
        'title': 'Khởi tạo phiếu',
        'description': 'Tạo bởi: ${data['sender']?['username'] ?? data['createdByRole'] ?? 'Hệ thống'}',
        'type': 'info'
      });
    }
    if (data['startTime'] != null) {
      events.add({
        'time': DateTime.parse(data['startTime']).toLocal(),
        'title': 'Bắt đầu vận chuyển',
        'description': data['vehiclePlate'] != null ? 'Xe: ${data['vehiclePlate']}' : 'Đã giao cho tài xế',
        'type': 'primary'
      });
    }
    final logs = data['logs'] ?? data['events'] ?? data['history'] ?? [];
    if (logs is List) {
      for (var log in logs) {
        String actionLabel = log['action'] ?? '';
        if (log['action'] == 'DRIVER_RECEIVE') actionLabel = 'Tài xế xác nhận nhận hàng';
        else if (log['action'] == 'DRIVER_DELIVER') actionLabel = 'Tài xế xác nhận giao hàng';
        else if (log['action'] == 'DEALER_CONFIRM') actionLabel = 'Đại lý xác nhận nhận hàng';
        else if (log['action'] == 'RECEIVER_CONFIRM') actionLabel = 'Người nhận xác nhận';
        else if (actionLabel.isEmpty) actionLabel = log['status'] ?? 'Cập nhật';

        events.add({
          'time': log['actionTime'] != null ? DateTime.parse(log['actionTime']).toLocal() : (log['time'] != null ? DateTime.parse(log['time']).toLocal() : DateTime.now()),
          'title': actionLabel,
          'description': log['lat'] != null ? 'Vị trí GPS: ${log['lat']}, ${log['long']}' : (log['location'] ?? '---'),
          'type': (log['action'] == 'DEALER_CONFIRM' || log['action'] == 'RECEIVER_CONFIRM') ? 'success' : 'primary'
        });
      }
    }
    if (data['endTime'] != null) {
      events.add({
        'time': DateTime.parse(data['endTime']).toLocal(),
        'title': 'Hoàn thành giao hàng',
        'description': 'Người nhận đã xác nhận nhận đủ hàng',
        'type': 'success'
      });
    }
    final seen = <String>{};
    final uniqueEvents = <Map<String, dynamic>>[];
    for (var e in events) {
      final key = '${e['title']}_${(e['time'] as DateTime).millisecondsSinceEpoch}';
      if (!seen.contains(key)) {
        seen.add(key);
        uniqueEvents.add(e);
      }
    }
    
    int getOrderIndex(String title) {
      if (title.contains('Khởi tạo')) return 1;
      if (title.contains('Bắt đầu vận chuyển')) return 2;
      if (title.contains('Tài xế xác nhận nhận hàng')) return 3;
      if (title.contains('Tài xế xác nhận giao hàng')) return 4;
      if (title.contains('Đại lý xác nhận') || title.contains('Người nhận xác nhận')) return 5;
      if (title.contains('Hoàn thành')) return 6;
      return 99;
    }

    uniqueEvents.sort((a, b) {
      final tA = a['time'] as DateTime;
      final tB = b['time'] as DateTime;
      final diff = tA.difference(tB).inSeconds.abs();
      
      if (diff == 0) {
        return getOrderIndex(a['title']).compareTo(getOrderIndex(b['title']));
      }
      return tA.compareTo(tB);
    });
    
    return uniqueEvents;
  }

  Widget _buildInfoRow(String label, String value, {bool isBlue = false, bool isOrange = false, bool isTag = false, Color tagColor = Colors.grey}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label, 
            style: const TextStyle(color: kDealerTextMuted, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        if (isTag)
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: tagColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: tagColor.withOpacity(0.3)),
              ),
              child: Text(
                value, 
                style: TextStyle(color: tagColor, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
        else
          Expanded(
            child: Text(
              value, 
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isBlue ? Colors.blueAccent : (isOrange ? Colors.orangeAccent : Colors.white), 
                fontWeight: isBlue || isOrange ? FontWeight.bold : FontWeight.w500, 
                fontSize: 11
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Widget _buildTimelineWidget(List<Map<String, dynamic>> events) {
    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(left: 24),
        child: Text('Chưa có thông tin lịch trình', style: TextStyle(color: kDealerTextMuted, fontStyle: FontStyle.italic)),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(events.length, (index) {
        final isLast = index == events.length - 1;
        final event = events[index];
        final isSuccess = event['type'] == 'success' || event['type'] == 'primary';
        
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isSuccess ? Colors.greenAccent : Colors.white54,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: Colors.white10,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(event['description'], style: const TextStyle(color: kDealerTextMuted, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(_formatDateFull(event['time'].toString()), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(dealerShipmentDetailProvider(shipmentId));

    return Scaffold(
      backgroundColor: kDealerBg,
      appBar: AppBar(
        backgroundColor: kDealerBg,
        title: const Text('Chi tiết Đơn hàng', style: TextStyle(color: kDealerText)),
        iconTheme: const IconThemeData(color: kDealerText),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: kDealerPrimary)),
        error: (e, s) => Center(child: Text('Lỗi tải dữ liệu: $e', style: const TextStyle(color: Colors.redAccent))),
        data: (data) {
          final expectedItems = (data['expectedItems'] as List?) ?? (data['items'] as List?) ?? [];
          final events = _buildTimeline(data);
          final code = data['trackingCode'] ?? data['code'] ?? data['shipmentCode'] ?? '---';
          final typeLabel = data['type'] == 'DEALER_EXPORT' ? 'Xuất bán Đại lý' : 'Chuyển kho';
          final vehicle = data['vehiclePlate'] ?? '---';
          
          String driver = '---';
          if (data['externalDriverName'] != null) {
            driver = data['externalDriverName'];
            if (data['externalDriverPhone'] != null) {
              driver += ' (${data['externalDriverPhone']})';
            }
          } else if (data['driver'] != null) {
            driver = data['driver']['fullName'] ?? data['driver']['username'] ?? '---';
          }

          final source = data['sourceWarehouse']?['name'] ?? '---';
          final dest = data['destinationWarehouse']?['name'] ?? data['dealer']?['name'] ?? '---';
          final statusLabel = _getStatusLabel(data['status'] ?? 'CREATED');
          
          String? sigUrl = data['signature']?.toString();
          String? photoUrl = data['evidenceUrl']?.toString();

          final logsList = data['logs'] ?? data['events'] ?? data['history'] ?? [];
          if (logsList is List) {
            for (final log in logsList) {
              if (log['step'] == 'DRIVER_DELIVER' || log['action'] == 'DRIVER_DELIVER') {
                if (sigUrl == null || sigUrl.isEmpty) {
                  sigUrl = log['signatureUrl']?.toString() ?? log['signature_url']?.toString();
                }
                if (photoUrl == null || photoUrl.isEmpty) {
                  final photos = log['evidencePhotos'] ?? log['evidence_photos'] ?? [];
                  if (photos is List && photos.isNotEmpty) {
                    photoUrl = photos.first.toString();
                  }
                }
              }
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Grid Details Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kDealerSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _buildInfoRow('Mã vận đơn', code, isBlue: true),
                              const Divider(height: 20, color: Colors.white10),
                              _buildInfoRow('Loại hình', typeLabel, isTag: true, tagColor: Colors.greenAccent),
                              const Divider(height: 20, color: Colors.white10),
                              _buildInfoRow('Xe vận chuyển', vehicle),
                              const Divider(height: 20, color: Colors.white10),
                              _buildInfoRow('Lái xe', driver),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: [
                              _buildInfoRow('Kho xuất', source),
                              const Divider(height: 20, color: Colors.white10),
                              _buildInfoRow('Đích đến', dest, isOrange: true),
                              const Divider(height: 20, color: Colors.white10),
                              _buildInfoRow('Trạng thái', statusLabel, isTag: true, tagColor: Colors.white54),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: kDealerBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                                  child: const Icon(Icons.calendar_today, color: Colors.blueAccent, size: 14),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Lịch yêu cầu', style: TextStyle(color: kDealerTextMuted, fontSize: 10)),
                                      Text(
                                        _formatDateFull(data['expectedDeliveryTime'] ?? data['createdAt']),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: kDealerBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: data['endTime'] != null ? Colors.green.withOpacity(0.1) : Colors.white10, 
                                    shape: BoxShape.circle
                                  ),
                                  child: Icon(Icons.access_time, color: data['endTime'] != null ? Colors.greenAccent : Colors.white54, size: 14),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Ngày thực hiện', style: TextStyle(color: kDealerTextMuted, fontSize: 10)),
                                      Text(
                                        data['endTime'] != null ? _formatDateFull(data['endTime']) : 'Chưa hoàn tất',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold, 
                                          fontSize: 11, 
                                          color: data['endTime'] != null ? Colors.greenAccent : Colors.white54
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Items List
              Row(
                children: const [
                  Icon(Icons.inventory_2_outlined, size: 20, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Danh mục Hàng hóa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: kDealerSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.white10)),
                      ),
                      child: Row(
                        children: const [
                          SizedBox(width: 30, child: Text('STT', style: TextStyle(color: kDealerTextMuted, fontSize: 13, fontWeight: FontWeight.bold))),
                          Expanded(child: Text('Sản phẩm', style: TextStyle(color: kDealerTextMuted, fontSize: 13, fontWeight: FontWeight.bold))),
                          SizedBox(width: 70, child: Text('Số lượng', textAlign: TextAlign.center, style: TextStyle(color: kDealerTextMuted, fontSize: 13, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                    if (expectedItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Không có hàng hóa', style: TextStyle(color: kDealerTextMuted)),
                      ),
                    ...List.generate(expectedItems.length, (index) {
                      final i = expectedItems[index];
                      return Container(
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(width: 30, child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 13))),
                            Expanded(child: Text(i['productName'] ?? i['name'] ?? 'Sản phẩm ${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 13))),
                            SizedBox(
                              width: 70, 
                              child: Text(
                                '${i['quantity'] ?? i['expectedQuantity'] ?? 0}', 
                                textAlign: TextAlign.center, 
                                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13)
                              )
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              
              // Minh chứng giao nhận
              if ((sigUrl != null && sigUrl.isNotEmpty) || (photoUrl != null && photoUrl.isNotEmpty)) ...[
                const SizedBox(height: 24),
                Row(
                  children: const [
                    Icon(Icons.verified_user_outlined, size: 20, color: Colors.greenAccent),
                    SizedBox(width: 8),
                    Text('Minh chứng giao nhận', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kDealerSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sigUrl != null && sigUrl.isNotEmpty)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Chữ ký nhận:', style: TextStyle(color: kDealerTextMuted, fontSize: 12)),
                              const SizedBox(height: 8),
                              Container(
                                height: 100,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    sigUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.broken_image, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (sigUrl != null && sigUrl.isNotEmpty && photoUrl != null && photoUrl.isNotEmpty)
                        const SizedBox(width: 16),
                      if (photoUrl != null && photoUrl.isNotEmpty)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Ảnh hóa đơn:', style: TextStyle(color: kDealerTextMuted, fontSize: 12)),
                              const SizedBox(height: 8),
                              Container(
                                height: 100,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    photoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.broken_image, color: Colors.white24),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              
              // Timeline Widget
              Row(
                children: const [
                  Icon(Icons.receipt_long, size: 20, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Lịch sử hành trình', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _buildTimelineWidget(events),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}
