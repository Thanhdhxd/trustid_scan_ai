import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/supply/data/dealer_providers.dart';
import 'package:trustid_scan_ai/supply/data/dealer_repository.dart';
import 'package:intl/intl.dart';
import 'dealer_shipment_detail_screen.dart';

const Color kDealerBg = Color(0xFF0F2B46);
const Color kDealerSurface = Color(0xFF16325B);
const Color kDealerText = Color(0xFFF8FAFC);
const Color kDealerTextMuted = Color(0xFF94A3B8);
const Color kDealerPrimary = Color(0xFF00875A); // Sync with other roles (Green)

class DealerReceiveScreen extends ConsumerStatefulWidget {
  const DealerReceiveScreen({super.key});

  @override
  ConsumerState<DealerReceiveScreen> createState() => _DealerReceiveScreenState();
}

class _DealerReceiveScreenState extends ConsumerState<DealerReceiveScreen> {
  bool _showAll = false;
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _allFetchedItems = []; // The full list from API
  List<dynamic> _displayedItems = [];  // Currently rendered items
  int _currentPage = 1;
  final int _pageSize = 10;
  bool _isLoading = false;
  bool _isLoadMoreRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitial();
    });
    _scrollController.addListener(_loadMoreListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_loadMoreListener);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _currentPage = 1;
    try {
      final repo = ref.read(dealerRepositoryProvider);
      final list = await repo.getPendingReceives(all: _showAll);
      if (mounted) {
        setState(() {
          _allFetchedItems = list;
          _displayedItems = list.take(_pageSize).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadMore() {
    if (_isLoadMoreRunning || _displayedItems.length >= _allFetchedItems.length) return;
    setState(() => _isLoadMoreRunning = true);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _currentPage++;
        final nextItems = _allFetchedItems.skip((_currentPage - 1) * _pageSize).take(_pageSize).toList();
        _displayedItems.addAll(nextItems);
        _isLoadMoreRunning = false;
      });
    });
  }

  void _loadMoreListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 150) {
      _loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDealerBg,
      appBar: AppBar(
        backgroundColor: kDealerBg,
        title: const Text('Nhận hàng từ Công ty / NSX', style: TextStyle(color: kDealerText)),
        iconTheme: const IconThemeData(color: kDealerText),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: kDealerSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (_showAll) {
                                setState(() {
                                  _showAll = false;
                                  _displayedItems.clear();
                                  _allFetchedItems.clear();
                                });
                                _loadInitial();
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: !_showAll ? kDealerPrimary : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              child: Text(
                                'Chờ nhận',
                                style: TextStyle(
                                  color: !_showAll ? Colors.white : kDealerTextMuted,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (!_showAll) {
                                setState(() {
                                  _showAll = true;
                                  _displayedItems.clear();
                                  _allFetchedItems.clear();
                                });
                                _loadInitial();
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: _showAll ? kDealerPrimary : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              child: Text(
                                'Tất cả phiếu',
                                style: TextStyle(
                                  color: _showAll ? Colors.white : kDealerTextMuted,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: kDealerPrimary))
                : _displayedItems.isEmpty
                    ? Center(
                        child: Text(
                          _showAll ? 'Không có phiếu giao hàng nào' : 'Không có phiếu chờ nhận',
                          style: const TextStyle(color: kDealerTextMuted),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadInitial,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _displayedItems.length + (_isLoadMoreRunning ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _displayedItems.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: CircularProgressIndicator(color: kDealerPrimary)),
                              );
                            }
                            final item = _displayedItems[index];
                            return _ReceiveCard(
                              item: item,
                              showAllState: _showAll,
                              onRefresh: _loadInitial,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ReceiveCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;
  final bool showAllState;
  final VoidCallback onRefresh;
  const _ReceiveCard({required this.item, required this.showAllState, required this.onRefresh});

  @override
  ConsumerState<_ReceiveCard> createState() => _ReceiveCardState();
}

class _ReceiveCardState extends ConsumerState<_ReceiveCard> {
  bool _isLoading = false;

  Future<void> _confirmReceive() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kDealerSurface,
        title: const Text('Xác nhận nhận', style: TextStyle(color: kDealerText)),
        content: Text('Xác nhận bạn đã nhận đủ danh sách mã sản phẩm cho phiếu ${widget.item['trackingCode'] ?? '---'}? Hệ thống sẽ tự động nhập hàng vào kho của đại lý.', style: const TextStyle(color: kDealerTextMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Đồng ý nhận'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final repo = ref.read(dealerRepositoryProvider);
        await repo.confirmReceive(widget.item['id'].toString());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nhập kho thành công! Sản phẩm đã nằm trong Tồn Kho.'), backgroundColor: Colors.green));
          widget.onRefresh();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _repairInbound() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kDealerSurface,
        title: const Text('Sửa lỗi tồn kho', style: TextStyle(color: kDealerText)),
        content: Text('Phiếu ${widget.item['trackingCode'] ?? '---'} đã nhận nhưng tồn kho có thể bị thiếu. Bạn có muốn sửa lỗi tồn kho không?', style: const TextStyle(color: kDealerTextMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Đồng ý sửa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final repo = ref.read(dealerRepositoryProvider);
        final result = await repo.repairInbound(widget.item['id'].toString());
        if (mounted) {
          String msg = 'Đã hoàn tất sửa lỗi';
          if (result['alreadyProcessed'] == true) {
            msg = 'Kho đã có dữ liệu nhập cho phiếu này. Không cần sửa.';
          } else if (result['count'] != null && result['count'] > 0) {
            msg = 'Đã nhập bổ sung ${result['count']} sản phẩm vào tồn kho';
          } else if (result['message'] != null) {
            msg = result['message'];
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orange));
          widget.onRefresh();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
  
  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '---';
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(d);
    } catch (_) {
      return iso;
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

  void _showDetailDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DealerShipmentDetailScreen(
          shipmentId: widget.item['id'].toString(),
        ),
      ),
    );
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'AT_DEALER': return Colors.green;
      case 'PENDING_DEALER_CONFIRM': return Colors.blueGrey;
      case 'IN_TRANSIT': return Colors.blue;
      case 'DELIVERED': return Colors.orangeAccent;
      case 'CANCELLED': return Colors.red;
      default: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsCount = (widget.item['expectedItems'] as List?)?.length ?? 0;
    final status = widget.item['status'] ?? 'CREATED';
    final isReceived = ['AT_DEALER', 'COMPLETED', 'DONE'].contains(status.toUpperCase());
    
    return GestureDetector(
      onTap: _showDetailDialog,
      child: Card(
        color: kDealerSurface,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.item['trackingCode'] ?? 'N/A', 
                      style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 16)
                    )
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.2), 
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getStatusColor(status).withOpacity(0.5), width: 1),
                    ),
                    child: Text(
                      _getStatusLabel(status), 
                      style: TextStyle(color: _getStatusColor(status), fontSize: 11, fontWeight: FontWeight.bold)
                    ),
                  )
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.home_work, size: 14, color: kDealerTextMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kho xuất: ${widget.item['sourceWarehouse']?['name'] ?? 'Công ty phát hành'}', 
                      style: const TextStyle(color: kDealerTextMuted, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: kDealerTextMuted),
                  const SizedBox(width: 8),
                  Text('Dự kiến giao: ${_formatDate(widget.item['expectedDeliveryTime'])}', style: const TextStyle(color: kDealerTextMuted, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),
              Text('Số lượng mặt hàng: $itemsCount', style: const TextStyle(color: kDealerText)),
              const SizedBox(height: 12),
            if (isReceived)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Đã nhận vào kho', 
                            style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isLoading ? null : _repairInbound,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: _isLoading 
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
                          : const Icon(Icons.refresh, color: Colors.orangeAccent, size: 18),
                    ),
                  )
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _confirmReceive,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, 
                    padding: const EdgeInsets.symmetric(vertical: 14), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  child: _isLoading 
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, size: 18, color: Colors.white),
                            SizedBox(width: 6),
                            Text('Xác nhận nhận', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                ),
              )
          ],
        ),
      ),
    ),
  );
}
}
