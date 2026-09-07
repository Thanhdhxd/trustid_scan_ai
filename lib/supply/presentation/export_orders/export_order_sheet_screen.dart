import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import '../../data/export_order_repository.dart';
import '../../data/supply_repository.dart';
import '../../domain/export_order.dart';

class ExportOrderSheetScreen extends ConsumerStatefulWidget {
  const ExportOrderSheetScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ExportOrderSheetScreen> createState() => _ExportOrderSheetScreenState();
}

class _ExportOrderSheetScreenState extends ConsumerState<ExportOrderSheetScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2B46),
      appBar: AppBar(
        title: const Text('Phiếu Xuất Kho', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: const Color(0xFF0F2B46),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00875A),
          labelColor: const Color(0xFF00875A),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Lệnh chờ xuất kho'),
            Tab(text: 'Lệnh đã xuất kho'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _OrderListTab(type: 'PENDING'),
          _OrderListTab(type: 'COMPLETED'),
        ],
      ),
    );
  }
}

class _OrderListTab extends ConsumerStatefulWidget {
  final String type; // 'PENDING' or 'COMPLETED'
  const _OrderListTab({Key? key, required this.type}) : super(key: key);

  @override
  ConsumerState<_OrderListTab> createState() => _OrderListTabState();
}

class _OrderListTabState extends ConsumerState<_OrderListTab> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _limit = 10;

  List<ExportOrder> _orders = [];
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _dealers = [];
  List<dynamic> _warehouses = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMasterData();
    _fetchOrders();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _loadMoreOrders();
      }
    }
  }

  Future<void> _loadMasterData() async {
    final supplyRepo = ref.read(supplyRepositoryProvider);
    
    try {
      final dealers = await supplyRepo.getDealers(limit: 1000);
      if (mounted) setState(() => _dealers = dealers);
    } catch (e) {
      // Ignore gracefully
    }

    try {
      final warehouses = await supplyRepo.getWarehouses(limit: 1000);
      if (mounted) setState(() => _warehouses = warehouses);
    } catch (e) {
      // Ignore gracefully
    }
  }

  Future<void> _fetchOrders({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _page = 1;
        _hasMore = true;
      });
    }
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> filters = {
        'page': _page,
        'limit': _limit,
      };
      // We rely on local filtering if API doesn't support complex filters,
      // But let's just fetch all and filter locally for simplicity and accuracy based on type.
      // Or we can fetch specific status. If COMPLETED, fetch EXPORTED.
      if (widget.type == 'COMPLETED') {
        filters['status'] = 'EXPORTED';
      } else if (widget.type == 'PENDING') {
        filters['status'] = 'CONFIRMED,PICKING';
      }
      
      final orders = await ref.read(exportOrderRepositoryProvider).getOrders(filters);
      
      // Local filter for PENDING (CONFIRMED and PICKING)
      List<ExportOrder> filteredOrders = orders;
      if (widget.type == 'PENDING') {
        filteredOrders = orders.where((o) => o.status == 'PICKING' || o.status == 'CONFIRMED').toList();
      }
      
      // Load missing dealers individually
      final supplyRepo = ref.read(supplyRepositoryProvider);
      final missingDealerIds = filteredOrders
          .where((o) => o.dealerId.isNotEmpty)
          .map((o) => o.dealerId)
          .toSet()
          .difference(_dealers.map((d) => (d['id'] ?? '').toString()).toSet());
          
      if (missingDealerIds.isNotEmpty) {
        await Future.wait(missingDealerIds.map((id) async {
          try {
            final dealer = await supplyRepo.getDealerDetail(id);
            if (mounted) {
              setState(() {
                _dealers.add(dealer);
              });
            }
          } catch (e) {
            // Ignore silently
          }
        }));
      }

      setState(() {
        if (refresh) {
          _orders = filteredOrders;
        } else {
          _orders.addAll(filteredOrders);
        }
        _hasMore = orders.length == _limit;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreOrders() async {
    setState(() {
      _isLoadingMore = true;
      _page++;
    });
    try {
      final Map<String, dynamic> filters = {
        'page': _page,
        'limit': _limit,
      };
      if (widget.type == 'COMPLETED') {
        filters['status'] = 'EXPORTED';
      } else if (widget.type == 'PENDING') {
        filters['status'] = 'CONFIRMED,PICKING';
      }
      final orders = await ref.read(exportOrderRepositoryProvider).getOrders(filters);
      
      List<ExportOrder> filteredOrders = orders;
      if (widget.type == 'PENDING') {
        filteredOrders = orders.where((o) => o.status == 'PICKING' || o.status == 'CONFIRMED').toList();
      }

      // Load missing dealers individually
      final supplyRepo = ref.read(supplyRepositoryProvider);
      final missingDealerIds = filteredOrders
          .where((o) => o.dealerId.isNotEmpty)
          .map((o) => o.dealerId)
          .toSet()
          .difference(_dealers.map((d) => (d['id'] ?? '').toString()).toSet());
          
      if (missingDealerIds.isNotEmpty) {
        await Future.wait(missingDealerIds.map((id) async {
          try {
            final dealer = await supplyRepo.getDealerDetail(id);
            if (mounted) {
              setState(() {
                _dealers.add(dealer);
              });
            }
          } catch (e) {
            // Ignore silently
          }
        }));
      }

      setState(() {
        _orders.addAll(filteredOrders);
        _hasMore = orders.length == _limit;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  String _getDealerName(String id) {
    if (id.isEmpty) return 'Chưa gán';
    final d = _dealers.firstWhere((x) => x['id'] == id, orElse: () => null);
    return d != null ? d['name'] : id;
  }

  String _getWarehouseName(String id) {
    if (id.isEmpty) return '(Chưa gán)';
    final w = _warehouses.firstWhere((x) => x['id'] == id, orElse: () => null);
    return w != null ? w['name'] : id;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'DRAFT': return Colors.grey;
      case 'CONFIRMED': return Colors.blue;
      case 'PICKING': return Colors.orange;
      case 'EXPORTED': return Colors.green;
      case 'CANCELLED': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'DRAFT': return 'Nháp';
      case 'CONFIRMED': return 'Đã xác nhận';
      case 'PICKING': return 'Đang lấy hàng';
      case 'EXPORTED': return 'Đã xuất kho';
      case 'CANCELLED': return 'Đã hủy';
      default: return status;
    }
  }

  double _calculateProgress(ExportOrder order) {
    if (order.items.isEmpty) return 0;
    int totalExpected = 0;
    int totalScanned = 0;
    for (var item in order.items) {
      totalExpected += item.expectedQuantity;
      totalScanned += item.scannedQuantity;
    }
    if (totalExpected == 0) return 0;
    return (totalScanned / totalExpected).clamp(0.0, 1.0);
  }

  void _showOrderDetailDialog(ExportOrder order) {
    showDialog(
      context: context,
      builder: (context) {
        return _OrderDetailDialog(
          orderId: order.id,
          onStatusChanged: () => _fetchOrders(refresh: true),
          dealers: _dealers,
          warehouses: _warehouses,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _page == 1) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00875A)));
    }
    if (_orders.isEmpty) {
      return const Center(child: Text('Không có dữ liệu', style: TextStyle(color: Colors.white54)));
    }
    return RefreshIndicator(
      onRefresh: () => _fetchOrders(refresh: true),
      color: const Color(0xFF00875A),
      backgroundColor: const Color(0xFF16325B),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80, top: 16),
        itemCount: _orders.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _orders.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF00875A))),
            );
          }
          return _buildOrderCard(_orders[index], _calculateProgress(_orders[index]));
        },
      ),
    );
  }

  Widget _buildOrderCard(ExportOrder order, double progress) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.transparent),
      ),
      elevation: 0,
      color: const Color(0xFF16325B),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _showOrderDetailDialog(order);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.orderCode,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _getStatusColor(order.status), width: 1),
                    ),
                    child: Text(
                      _getStatusText(order.status),
                      style: TextStyle(
                        color: _getStatusColor(order.status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  const Icon(Icons.store, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đại lý: ${_getDealerName(order.dealerId)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.warehouse, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kho xuất: ${_getWarehouseName(order.sourceWarehouseId)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Tiến độ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tiến độ lấy hàng', style: TextStyle(fontSize: 12, color: Colors.white54)),
                  Text('${(progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor(order.status)),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderDetailDialog extends ConsumerStatefulWidget {
  final String orderId;
  final VoidCallback onStatusChanged;
  final List<dynamic> dealers;
  final List<dynamic> warehouses;
  
  const _OrderDetailDialog({
    required this.orderId, 
    required this.onStatusChanged,
    required this.dealers,
    required this.warehouses,
  });

  @override
  ConsumerState<_OrderDetailDialog> createState() => _OrderDetailDialogState();
}

class _OrderDetailDialogState extends ConsumerState<_OrderDetailDialog> {
  bool _isLoading = true;
  ExportOrder? _order;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  String _getDealerName(String id) {
    if (id.isEmpty) return 'Chưa gán';
    final d = widget.dealers.firstWhere((x) => x['id'] == id, orElse: () => null);
    return d != null ? d['name'] : id;
  }

  String _getWarehouseName(String id) {
    if (id.isEmpty) return '(Chưa gán)';
    final w = widget.warehouses.firstWhere((x) => x['id'] == id, orElse: () => null);
    return w != null ? w['name'] : id;
  }

  Future<void> _fetchDetail() async {
    setState(() => _isLoading = true);
    try {
      final order = await ref.read(exportOrderRepositoryProvider).getDetail(widget.orderId);
      setState(() {
        _order = order;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải chi tiết lệnh: $e')));
      }
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    switch (status) {
      case 'DRAFT': color = Colors.grey; text = 'Nháp'; break;
      case 'CONFIRMED': color = Colors.blue; text = 'Đã xác nhận'; break;
      case 'PICKING': color = Colors.orange; text = 'Đang lấy'; break;
      case 'EXPORTED': color = const Color(0xFF00875A); text = 'Đã xuất kho'; break;
      case 'CANCELLED': color = Colors.red; text = 'Đã hủy'; break;
      default: color = Colors.grey; text = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildGridRow(String label1, dynamic value1, String label2, dynamic value2, {bool isEmptyRight = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              color: const Color(0xFF16325B),
              child: Row(
                children: [
                  SizedBox(width: 80, child: Text(label1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70))),
                  Expanded(child: value1 is Widget ? value1 : Text(value1.toString(), style: const TextStyle(fontSize: 13, color: Colors.white))),
                ],
              ),
            ),
          ),
          VerticalDivider(width: 1, color: Colors.white12, thickness: 1),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              color: const Color(0xFF16325B),
              child: isEmptyRight ? const SizedBox() : Row(
                children: [
                  SizedBox(width: 80, child: Text(label2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70))),
                  Expanded(child: value2 is Widget ? value2 : Text(value2.toString(), style: const TextStyle(fontSize: 13, color: Colors.white))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
          color: isHeader ? Colors.white70 : Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: EdgeInsets.symmetric(horizontal: width > 600 ? 100 : 16, vertical: 24),
      backgroundColor: const Color(0xFF0F2B46),
      child: _isLoading
          ? const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: Color(0xFF00875A))))
          : _order == null
              ? const SizedBox(height: 300, child: Center(child: Text('Không tìm thấy dữ liệu', style: TextStyle(color: Colors.white54))))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Chi tiết Lệnh: ${_order!.orderCode}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: Colors.white12),
                    
                    // Body
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Column(
                                children: [
                                  if (_order!.status == 'EXPORTED')
                                    _buildGridRow('Số PXK', _order!.orderCode.replaceFirst('LXH', 'PXK'), 'Số Lệnh', _order!.orderCode),
                                  if (_order!.status == 'EXPORTED')
                                    Divider(height: 1, color: Colors.white12, thickness: 1),
                                    
                                  if (_order!.status != 'EXPORTED')
                                    _buildGridRow('Số lệnh', _order!.orderCode, 'Ngày tạo', _order!.createdAt != null ? _formatDate(_order!.createdAt!) : 'N/A'),
                                  if (_order!.status != 'EXPORTED')
                                    Divider(height: 1, color: Colors.white12, thickness: 1),
                                    
                                  if (_order!.status == 'EXPORTED')
                                    _buildGridRow('Ngày tạo', _order!.createdAt != null ? _formatDate(_order!.createdAt!) : 'N/A', 'Trạng thái', _buildStatusBadge(_order!.status)),
                                  if (_order!.status == 'EXPORTED')
                                    Divider(height: 1, color: Colors.white12, thickness: 1),
                                    
                                  if (_order!.status != 'EXPORTED')
                                    _buildGridRow('Đại lý', _getDealerName(_order!.dealerId), 'Trạng thái', _buildStatusBadge(_order!.status)),
                                  if (_order!.status != 'EXPORTED')
                                    Divider(height: 1, color: Colors.white12, thickness: 1),
                                    
                                  if (_order!.status == 'EXPORTED')
                                    _buildGridRow('Đại lý', _getDealerName(_order!.dealerId), '', '', isEmptyRight: true),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Danh sách Sản phẩm Yêu cầu',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(2.5),
                                    1: FlexColumnWidth(1.8),
                                    2: FlexColumnWidth(1.8),
                                    3: FlexColumnWidth(1.2),
                                    4: FlexColumnWidth(1.5),
                                  },
                                  border: TableBorder(
                                    horizontalInside: const BorderSide(color: Colors.white12, width: 1),
                                    verticalInside: const BorderSide(color: Colors.white12, width: 1),
                                  ),
                                  children: [
                                    TableRow(
                                      decoration: const BoxDecoration(color: Color(0xFF16325B)),
                                      children: [
                                        _buildTableCell('Sản phẩm', isHeader: true),
                                        _buildTableCell('Đơn vị', isHeader: true, align: TextAlign.center),
                                        _buildTableCell('Yêu cầu', isHeader: true, align: TextAlign.center),
                                        _buildTableCell('Đã lấy', isHeader: true, align: TextAlign.center),
                                        _buildTableCell('Ghi chú', isHeader: true),
                                      ],
                                    ),
                                    ..._order!.items.map((item) {
                                      return TableRow(
                                        decoration: const BoxDecoration(color: Color(0xFF0F2B46)),
                                        children: [
                                          _buildTableCell(item.product?['name'] ?? item.productId),
                                          _buildTableCell(item.unitName ?? 'Gói', align: TextAlign.center),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  item.expectedQuantity.toString(),
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(fontSize: 13, color: Colors.white),
                                                ),
                                                if (item.conversionFactor > 1) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '= ${item.expectedQuantity * item.conversionFactor} gói',
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                                                  ),
                                                ]
                                              ],
                                            ),
                                          ),
                                          _buildTableCell(item.scannedQuantity.toString(), align: TextAlign.center),
                                          _buildTableCell(item.notes ?? ''),
                                        ],
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Footer
                    Divider(height: 1, color: Colors.white12),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00875A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            context.push('/manager/export-orders/${_order!.id}/scan').then((_) {
                              widget.onStatusChanged();
                            });
                          },
                          icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                          label: const Text(
                            'Đi tới Thực thi Xuất Kho',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
