import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/core/widgets/skeleton_loader.dart';
import '../../data/export_order_repository.dart';
import '../../data/supply_repository.dart';
import '../../domain/export_order.dart';

class ExportOrderListScreen extends ConsumerStatefulWidget {
  const ExportOrderListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ExportOrderListScreen> createState() => _ExportOrderListScreenState();
}

class _ExportOrderListScreenState extends ConsumerState<ExportOrderListScreen> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _limit = 10;

  List<ExportOrder> _orders = [];
  String _selectedStatus = '';
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
      final filters = {
        'page': _page,
        'limit': _limit,
        if (_selectedStatus.isNotEmpty) 'status': _selectedStatus,
      };
      final orders = await ref.read(exportOrderRepositoryProvider).getOrders(filters);
      
      // Load missing dealers individually
      final supplyRepo = ref.read(supplyRepositoryProvider);
      final missingDealerIds = orders
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
          _orders = orders;
        } else {
          _orders.addAll(orders);
        }
        _hasMore = orders.length == _limit;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải danh sách lệnh: $e')));
      }
    }
  }

  Future<void> _loadMoreOrders() async {
    setState(() {
      _isLoadingMore = true;
      _page++;
    });
    try {
      final filters = {
        'page': _page,
        'limit': _limit,
        if (_selectedStatus.isNotEmpty) 'status': _selectedStatus,
      };
      final orders = await ref.read(exportOrderRepositoryProvider).getOrders(filters);
      
      // Load missing dealers individually
      final supplyRepo = ref.read(supplyRepositoryProvider);
      final missingDealerIds = orders
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
        _orders.addAll(orders);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2B46),
      appBar: AppBar(
        title: const Text('Lệnh Xuất Kho', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: const Color(0xFF0F2B46),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchOrders(refresh: true),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF16325B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  dropdownColor: const Color(0xFF16325B),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  value: _selectedStatus,
                  hint: const Text('Trạng thái lệnh', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  style: const TextStyle(color: Colors.white),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Tất cả')),
                    const DropdownMenuItem(value: 'DRAFT', child: Text('Bản nháp (DRAFT)')),
                    const DropdownMenuItem(value: 'CONFIRMED', child: Text('Đã xác nhận (CONFIRMED)')),
                    const DropdownMenuItem(value: 'PICKING', child: Text('Đang lấy hàng (PICKING)')),
                    const DropdownMenuItem(value: 'EXPORTED', child: Text('Đã xuất kho (EXPORTED)')),
                    const DropdownMenuItem(value: 'CANCELLED', child: Text('Đã hủy (CANCELLED)')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedStatus = value);
                      _fetchOrders(refresh: true);
                    }
                  },
                ),
              ),
            ),
          ),
          
          Expanded(
            child: _isLoading && _page == 1
                ? const SingleChildScrollView(child: SkeletonListView(count: 6))
                : _orders.isEmpty
                    ? const Center(child: Text('Không có dữ liệu', style: TextStyle(color: Colors.white54)))
                    : RefreshIndicator(
                        onRefresh: () => _fetchOrders(refresh: true),
                        color: const Color(0xFF00875A),
                        backgroundColor: const Color(0xFF16325B),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
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
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00875A),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          context.push('/manager/export-orders/create').then((value) {
            if (value == true) {
              _fetchOrders(refresh: true);
            }
          });
        },
      ),
    );
  }

  Widget _buildOrderCard(ExportOrder order, double progress) {
    int totalExpected = 0;
    int totalScanned = 0;
    String firstProduct = 'Không có sản phẩm';
    if (order.items.isNotEmpty) {
      firstProduct = order.items.first.product?['name'] ?? order.items.first.productId;
      if (order.items.length > 1) {
        firstProduct += ' và ${order.items.length - 1} sp khác';
      }
      for (var item in order.items) {
        totalExpected += item.expectedQuantity;
        totalScanned += item.scannedQuantity;
      }
    }

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
              // Hàng 1: Mã lệnh & Trạng thái
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        order.orderCode,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueAccent),
                      ),
                      const SizedBox(width: 8),
                      _buildPriorityBadge(order.priority),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getStatusText(order.status),
                      style: TextStyle(
                        color: _getStatusColor(order.status),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Hàng 2: Thời gian
              Text(
                order.createdAt != null ? _formatDate(order.createdAt!) : 'N/A',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 16),
              
              // Liên kết
              const Text('Liên kết:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                'Đại lý: ${_getDealerName(order.dealerId)}',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Text(
                'Kho: ${_getWarehouseName(order.sourceWarehouseId)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              
              // Chi tiết sản phẩm
              const Text('Chi tiết sản phẩm:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                firstProduct,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Text(
                'Yêu cầu: $totalExpected  |  Đã lấy: $totalScanned',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              
              // Tiến độ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tiến độ', style: TextStyle(fontSize: 12, color: Colors.white54)),
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
              const SizedBox(height: 16),
              
              // Thao tác
              const Divider(height: 1, color: Colors.white12),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (order.status == 'DRAFT')
                    _buildActionButton(
                      icon: Icons.edit,
                      color: Colors.orange,
                      onTap: () {
                        context.push('/manager/export-orders/${order.id}/edit').then((value) {
                          if (value == true) {
                            _fetchOrders(refresh: true);
                          }
                        });
                      },
                    ),
                  if (order.status == 'DRAFT' || order.status == 'CONFIRMED' || order.status == 'PICKING')
                    const SizedBox(width: 8),
                  if (order.status == 'DRAFT')
                    _buildActionButton(
                      icon: Icons.check,
                      color: const Color(0xFF00875A),
                      onTap: () => _confirmOrder(order.id),
                    ),
                  if (order.status == 'CONFIRMED' || order.status == 'PICKING')
                    _buildActionButton(
                      icon: Icons.qr_code_scanner,
                      color: const Color(0xFF00875A),
                      onTap: () {
                        context.push('/manager/export-orders/${order.id}/scan').then((_) => _fetchOrders(refresh: true));
                      },
                    ),
                  if (order.status == 'DRAFT')
                    const SizedBox(width: 8),
                  if (order.status == 'DRAFT')
                    _buildActionButton(
                      icon: Icons.close,
                      color: Colors.redAccent,
                      onTap: () => _deleteOrder(order.id),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
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

  Widget _buildPriorityBadge(String priority) {
    Color color;
    String text;
    switch (priority) {
      case 'HIGH': color = Colors.redAccent; text = 'Cao'; break;
      case 'MEDIUM': color = Colors.orangeAccent; text = 'Trung bình'; break;
      case 'LOW': color = Colors.grey; text = 'Thấp'; break;
      default: color = Colors.orangeAccent; text = priority;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _deleteOrder(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF0F2B46),
        title: const Text('Xác nhận hủy', style: TextStyle(color: Colors.white)),
        content: const Text('Bạn có chắc chắn muốn hủy lệnh xuất kho này?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Đóng', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(c, true), 
            child: const Text('Hủy Lệnh', style: TextStyle(color: Colors.white))
          ),
        ],
      )
    );
    if (confirm == true) {
      try {
        await ref.read(exportOrderRepositoryProvider).cancel(id);
        _fetchOrders(refresh: true);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã hủy lệnh')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _confirmOrder(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF0F2B46),
        title: const Text('Xác nhận Lệnh', style: TextStyle(color: Colors.white)),
        content: const Text('Bạn có chắc chắn muốn xác nhận lệnh xuất kho này?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00875A)),
            onPressed: () => Navigator.pop(c, true), 
            child: const Text('Xác nhận', style: TextStyle(color: Colors.white))
          ),
        ],
      )
    );
    if (confirm == true) {
      try {
        await ref.read(exportOrderRepositoryProvider).confirm(id);
        _fetchOrders(refresh: true);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xác nhận lệnh')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
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

  Future<void> _confirmOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xác nhận Lệnh'),
        content: const Text('Bạn có chắc chắn muốn xác nhận lệnh xuất kho này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00875A)),
            onPressed: () => Navigator.pop(c, true), 
            child: const Text('Xác nhận')
          ),
        ],
      )
    );

    if (confirm == true) {
      try {
        await ref.read(exportOrderRepositoryProvider).confirm(widget.orderId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xác nhận lệnh')));
        }
        widget.onStatusChanged();
        _fetchDetail();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        }
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color color;
    String text;
    switch (priority) {
      case 'HIGH': color = Colors.red; text = 'Cao'; break;
      case 'MEDIUM': color = Colors.orange; text = 'Trung bình'; break;
      case 'LOW': color = Colors.grey; text = 'Thấp'; break;
      default: color = Colors.orange; text = priority;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFF16325B),
              child: Row(
                children: [
                  SizedBox(width: 70, child: Text(label1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70))),
                  Expanded(child: value1 is Widget ? value1 : Text(value1.toString(), style: const TextStyle(fontSize: 12, color: Colors.white))),
                ],
              ),
            ),
          ),
          VerticalDivider(width: 1, color: Colors.white12, thickness: 1),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFF16325B),
              child: isEmptyRight ? const SizedBox() : Row(
                children: [
                  SizedBox(width: 70, child: Text(label2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70))),
                  Expanded(child: value2 is Widget ? value2 : Text(value2.toString(), style: const TextStyle(fontSize: 12, color: Colors.white))),
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
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
          color: isHeader ? Colors.white70 : Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      insetPadding: EdgeInsets.symmetric(horizontal: width > 600 ? 100 : 16, vertical: 24),
      backgroundColor: const Color(0xFF0F2B46),
      child: _isLoading
          ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Color(0xFF00875A))))
          : _order == null
              ? const SizedBox(height: 200, child: Center(child: Text('Không tìm thấy dữ liệu', style: TextStyle(color: Colors.white54))))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Chi tiết Lệnh Xuất: ${_order!.orderCode}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Column(
                                children: [
                                  _buildGridRow('Trạng thái', _buildStatusBadge(_order!.status), 'Ngày tạo', _order!.createdAt != null ? _formatDate(_order!.createdAt!) : 'N/A'),
                                  Divider(height: 1, color: Colors.white12, thickness: 1),
                                  _buildGridRow('Đại lý', _getDealerName(_order!.dealerId), 'Kho xuất', _getWarehouseName(_order!.sourceWarehouseId)),
                                  Divider(height: 1, color: Colors.white12, thickness: 1),
                                  _buildGridRow('Mức ưu tiên', _buildPriorityBadge(_order!.priority), '', '', isEmptyRight: true),
                                  Divider(height: 1, color: Colors.white12, thickness: 1),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(
                                          width: 70,
                                          child: Text('Ghi chú', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ),
                                        Expanded(
                                          child: Text(_order!.notes?.isNotEmpty == true ? _order!.notes! : 'Không có ghi chú', style: const TextStyle(fontSize: 12, color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Danh sách sản phẩm xuất',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
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
                                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  item.expectedQuantity.toString(),
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(fontSize: 12, color: Colors.white),
                                                ),
                                                if (item.conversionFactor > 1) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '= ${item.expectedQuantity * item.conversionFactor} gói',
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Đóng'),
                          ),
                          if (_order!.status == 'CONFIRMED' || _order!.status == 'PICKING') ...[
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00875A), // same color as web
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                elevation: 0,
                              ),
                              onPressed: () {
                                Navigator.pop(context); // Close dialog before pushing to scanner
                                context.push('/manager/export-orders/${_order!.id}/scan').then((_) {
                                  widget.onStatusChanged();
                                });
                              },
                              icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 18),
                              label: const Text(
                                'Xử lý kho',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
