import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:intl/intl.dart';
import 'package:trustid_scan_ai/core/widgets/skeleton_loader.dart';
import '../../data/supply_repository.dart';

class SFPalletListScreen extends ConsumerStatefulWidget {
  const SFPalletListScreen({super.key});

  @override
  ConsumerState<SFPalletListScreen> createState() => _SFPalletListScreenState();
}

class _SFPalletListScreenState extends ConsumerState<SFPalletListScreen> {
  final Color kPrimaryColor = const Color(0xFF00875A);
  
  bool _isLoading = true;
  List<dynamic> _pallets = [];
  String _searchQuery = '';

  int _currentPage = 1;
  final int _limit = 15;
  bool _hasMoreData = true;
  bool _isFetchingMore = false;
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPallets(isRefresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isFetchingMore && _hasMoreData && !_isLoading) {
        _loadPallets();
      }
    }
  }

  Future<void> _loadPallets({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _hasMoreData = true;
        _isLoading = true;
      });
    } else {
      setState(() => _isFetchingMore = true);
    }
    
    try {
      final repo = ref.read(supplyRepositoryProvider);
      final data = await repo.getSFPallets(
        page: _currentPage,
        limit: _limit,
        search: _searchQuery,
      );

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _pallets = data;
          } else {
            _pallets.addAll(data);
          }
          _currentPage++;
          if (data.length < _limit) {
            _hasMoreData = false;
          }
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải pallet BTP: $e')));
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2B46),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2B46),
        title: const Text('Pallet Bán Thành Phẩm', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Tìm mã pallet...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF16325B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                _searchQuery = value;
                if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                  _loadPallets(isRefresh: true);
                });
              },
            ),
          ),
          
          // List View
          Expanded(
            child: _isLoading 
                ? const SingleChildScrollView(child: SkeletonListView(count: 6))
                : _pallets.isEmpty
                    ? const Center(
                        child: Text('Không có dữ liệu pallet', style: TextStyle(color: Colors.white54)),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadPallets(isRefresh: true),
                        color: const Color(0xFF00875A),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _pallets.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _pallets.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: _hasMoreData 
                                      ? const CircularProgressIndicator(color: Color(0xFF00875A))
                                      : const Text('Đã hiển thị hết danh sách', style: TextStyle(color: Colors.white54)),
                                ),
                              );
                            }
                            return _buildPalletCard(_pallets[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPalletCard(dynamic item) {
    final code = item['palletCode'] ?? item['pallet_code'] ?? item['code'] ?? 'N/A';
    
    final itemCount = item['itemCount'] ?? item['item_count'] ?? item['currentBagCount'] ?? item['current_bag_count'] ?? item['currentBatchCount'] ?? item['current_batch_count'] ?? item['quantity'] ?? 0;
    final maxCapacity = item['maxCapacity'] ?? item['max_capacity'] ?? 10;
    final totalWeight = item['totalWeight'] ?? item['total_weight'] ?? 0;
    
    String statusText = 'Trống';
    final rawStatus = (item['status'] ?? '').toString().toUpperCase();
    if (rawStatus == 'FULL' || rawStatus == 'ĐÃ ĐẦY' || rawStatus == 'SEALED') statusText = 'Đã đầy';
    else if (rawStatus == 'IN_PROGRESS' || rawStatus == 'FILLING' || rawStatus == 'ĐANG XẾP' || rawStatus == 'LOADING') statusText = 'Đang xếp';
    else if (rawStatus == 'EMPTY' || rawStatus == 'TRỐNG') statusText = 'Trống';
    else if (rawStatus.isNotEmpty) statusText = item['status'].toString();
    else if (itemCount >= maxCapacity && maxCapacity > 0) statusText = 'Đã đầy';
    else if (itemCount > 0) statusText = 'Đang xếp';

    final statusColor = statusText == 'Đã đầy' ? Colors.orange[400] : (statusText == 'Đang xếp' ? Colors.blue[400] : Colors.grey[400]);
    
    dynamic rawCreator = item['creator'] ?? item['createdBy'];
    String creatorName = 'Demo';
    if (rawCreator is Map) {
      creatorName = rawCreator['fullName'] ?? rawCreator['username'] ?? rawCreator['name'] ?? 'Demo';
    } else if (rawCreator != null) {
      creatorName = rawCreator.toString();
    }
    
    String dateStr = '';
    final createdAt = item['createdAt'] ?? '';
    if (createdAt.isNotEmpty) {
      try {
        final d = DateTime.parse(createdAt);
        dateStr = DateFormat('dd/MM/yyyy').format(d.toLocal());
      } catch (_) {}
    }

    return Card(
      color: const Color(0xFF16325B),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          final id = item['id'] ?? item['palletId'];
          if (id != null) {
            context.push('/manager/sf-pallets/$id');
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      code, 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor?.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatInfo(Icons.inventory_2, 'Số SP', '$itemCount / $maxCapacity', kPrimaryColor),
                  _buildStatInfo(Icons.scale, 'Tổng KL', '$totalWeight kg', Colors.blue[300]!),
                ],
              ),
              
              const SizedBox(height: 12),
              Divider(color: Colors.white.withOpacity(0.1)),
              const SizedBox(height: 8),
              
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Ngày tạo: $dateStr', 
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Người tạo: $creatorName', 
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatInfo(IconData icon, String label, String value, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }
}
