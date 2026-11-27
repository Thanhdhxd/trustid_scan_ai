import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/core/utils/app_toast.dart';
import 'package:trustid_scan_ai/core/utils/app_dialog.dart';
import '../../data/supply_repository.dart';

class PalletListScreen extends ConsumerStatefulWidget {
  const PalletListScreen({super.key});

  @override
  ConsumerState<PalletListScreen> createState() => _PalletListScreenState();
}

class _PalletListScreenState extends ConsumerState<PalletListScreen> {
  final Color kPrimaryColor = const Color(0xFF00875A);
  
  bool _isLoading = true;
  List<dynamic> _pallets = [];
  String _searchQuery = '';
  String _selectedStatus = '';

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
      final data = await repo.getPallets(
        page: _currentPage,
        limit: _limit,
        search: _searchQuery,
        status: _selectedStatus.isNotEmpty ? _selectedStatus : null,
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
        AppToast.error(context, e);
      }
    }
  }

  Future<void> _handleDelete(String id, String code) async {
    final confirm = await AppDialog.confirm(
      context,
      title: 'Xác nhận xóa',
      message: 'Bạn có chắc chắn muốn xóa Pallet $code?',
      confirmLabel: 'Xóa',
      isDangerous: true,
    );

    if (!confirm) return;

    try {
      await ref.read(supplyRepositoryProvider).deletePallet(id);
      if (mounted) {
        AppToast.success(context, 'Xóa Pallet $code thành công!');
        _loadPallets(isRefresh: true);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, e);
      }
    }
  }

  Future<void> _handleEdit(Map<String, dynamic> item) async {
    final id = item['id'] ?? item['palletId'];
    final code = item['palletCode'] ?? item['pallet_code'] ?? item['code'] ?? '';
    final maxCapacityRaw = item['maxBags'] ?? item['max_bags'] ?? item['maxBatches'] ?? item['max_batches'] ?? item['capacity'] ?? item['maxCapacity'] ?? item['max_capacity'] ?? item['limit'] ?? item['maxItems'] ?? item['max_items'] ?? 0;
    
    final maxCapacityController = TextEditingController(text: maxCapacityRaw.toString());

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16325B),
        title: Text('Sửa Pallet $code', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: maxCapacityController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Giới hạn số lượng',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lưu', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final newMax = int.tryParse(maxCapacityController.text) ?? maxCapacityRaw;
      await ref.read(supplyRepositoryProvider).updatePallet(id, {
        'maxCapacity': newMax,
        'maxBags': newMax,
      });
      if (mounted) {
        AppToast.success(context, 'Cập nhật Pallet thành công!');
        _loadPallets(isRefresh: true);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, e);
      }
    }
  }

  Future<void> _showBatchCreateDialog() async {
    final prefixController = TextEditingController(text: 'PLT');
    final quantityController = TextEditingController(text: '5');
    final maxBagsController = TextEditingController();
    bool isCreating = false;
    final currentYear = DateTime.now().year;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (sbContext, setDialogState) {
            final prefixText = prefixController.text.trim().isEmpty ? 'PLT' : prefixController.text.trim().toUpperCase();
            final previewCode = '$prefixText-$currentYear-0001';
            final qty = int.tryParse(quantityController.text) ?? 5;

            return AlertDialog(
              backgroundColor: const Color(0xFF16325B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.playlist_add_rounded, color: kPrimaryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Tạo Pallet mới',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tiền tố mã
                    const Text(
                      'Tiền tố mã pallet',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: prefixController,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        hintText: 'PLT',
                        hintStyle: const TextStyle(color: Colors.white30),
                        prefixIcon: const Icon(Icons.tag, color: Colors.white54, size: 20),
                        filled: true,
                        fillColor: const Color(0xFF0F2B46),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: (val) {
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mã tạo ra: $previewCode',
                      style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),

                    // Số lượng pallet
                    const Text(
                      'Số lượng pallet (1 - 100)',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: '5',
                        hintStyle: const TextStyle(color: Colors.white30),
                        prefixIcon: const Icon(Icons.numbers, color: Colors.white54, size: 20),
                        filled: true,
                        fillColor: const Color(0xFF0F2B46),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: (val) {
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 16),

                    // Giới hạn bao / pallet
                    const Text(
                      'Giới hạn bao / pallet (tùy chọn)',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: maxBagsController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: '0 = Không giới hạn',
                        hintStyle: const TextStyle(color: Colors.white30),
                        prefixIcon: const Icon(Icons.inventory_2_outlined, color: Colors.white54, size: 20),
                        filled: true,
                        fillColor: const Color(0xFF0F2B46),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Đặt 0 hoặc bỏ trống nếu không giới hạn số bao',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCreating ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: isCreating
                      ? null
                      : () async {
                          final quantity = int.tryParse(quantityController.text) ?? 0;
                          if (quantity <= 0 || quantity > 100) {
                            AppToast.warning(context, 'Số lượng pallet phải từ 1 đến 100');
                            return;
                          }

                          final prefix = prefixController.text.trim().isEmpty ? 'PLT' : prefixController.text.trim().toUpperCase();
                          final maxBags = int.tryParse(maxBagsController.text);

                          setDialogState(() => isCreating = true);
                          try {
                            final res = await ref.read(supplyRepositoryProvider).batchCreatePallets(
                              quantity: quantity,
                              prefix: prefix,
                              maxBags: maxBags != null && maxBags > 0 ? maxBags : null,
                            );

                            if (mounted) {
                              Navigator.pop(dialogContext);
                              final createdCount = res['created'] ?? quantity;
                              AppToast.success(context, 'Đã tạo $createdCount pallet thành công!');
                              _loadPallets(isRefresh: true);
                            }
                          } catch (e) {
                            setDialogState(() => isCreating = false);
                            if (mounted) {
                              AppToast.error(context, e);
                            }
                          }
                        },
                  child: isCreating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Tạo $qty Pallet',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2B46),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2B46),
        title: const Text('Quản lý Pallet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await context.push('/manager/pallet-linking');
              if (mounted) _loadPallets(isRefresh: true);
            },
            icon: const Icon(Icons.qr_code_scanner, size: 18, color: Color(0xFF36B37E)),
            label: const Text(
              'Đóng Pallet',
              style: TextStyle(color: Color(0xFF36B37E), fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
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

          // Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('', 'Tất cả', Icons.apps_rounded, null),
                const SizedBox(width: 8),
                _buildFilterChip('EMPTY', 'Trống', Icons.circle_outlined, Colors.grey[400]),
                const SizedBox(width: 8),
                _buildFilterChip('LOADING', 'Đang xếp', Icons.timelapse_rounded, Colors.blue[400]),
                const SizedBox(width: 8),
                _buildFilterChip('LOADED', 'Đã đầy', Icons.check_circle_rounded, Colors.green[400]),
                const SizedBox(width: 8),
                _buildFilterChip('EXPORTING', 'Đang xuất', Icons.local_shipping_rounded, Colors.orange[400]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // List View
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00875A)))
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimaryColor,
        elevation: 4,
        onPressed: _showBatchCreateDialog,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildPalletCard(Map<String, dynamic> item) {
    final id = item['id'] ?? item['palletId'];
    final code = item['palletCode'] ?? item['pallet_code'] ?? item['code'] ?? 'N/A';
    final itemCount = item['currentBagCount'] ?? item['current_bag_count'] ?? item['currentBatchCount'] ?? item['current_batch_count'] ?? item['itemCount'] ?? item['item_count'] ?? item['quantity'] ?? 0;
    final maxCapacityRaw = item['maxBags'] ?? item['max_bags'] ?? item['maxBatches'] ?? item['max_batches'] ?? item['capacity'] ?? item['maxCapacity'] ?? item['max_capacity'] ?? item['limit'] ?? item['maxItems'] ?? item['max_items'] ?? 0;
    
    // Nếu maxCapacity = 0 nghĩa là không giới hạn (vô cực)
    final maxCapacity = maxCapacityRaw <= 0 ? 999999 : maxCapacityRaw;
    
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

    final rawStatus = (item['status'] ?? '').toString().toUpperCase();
    String displayStatus;
    Color statusColor;

    if (rawStatus == 'EMPTY') {
      displayStatus = 'Trống';
      statusColor = Colors.grey[400]!;
    } else if (rawStatus == 'LOADING') {
      displayStatus = 'Đang xếp';
      statusColor = Colors.blue[400]!;
    } else if (rawStatus == 'LOADED') {
      displayStatus = 'Đã đầy';
      statusColor = Colors.green[400]!;
    } else if (rawStatus == 'EXPORTING') {
      displayStatus = 'Đang xuất';
      statusColor = Colors.orange[400]!;
    } else {
      final isFull = itemCount >= maxCapacity && maxCapacity > 0 && maxCapacity < 999999;
      displayStatus = isFull ? 'Đã đầy' : (itemCount > 0 ? 'Đang xếp' : 'Trống');
      statusColor = isFull ? Colors.green[400]! : (itemCount > 0 ? Colors.blue[400]! : Colors.grey[400]!);
    }

    return Card(
      color: const Color(0xFF16325B),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          if (id != null) {
            context.push('/manager/pallets/$id');
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
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    displayStatus,
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
                _buildStatInfo(Icons.inventory_2, 'Số bao', '$itemCount', kPrimaryColor),
                _buildStatInfo(Icons.data_usage, 'Giới hạn', maxCapacityRaw <= 0 ? '∞' : '$maxCapacityRaw', Colors.blue[300]!),
              ],
            ),
            
            const SizedBox(height: 12),
            Divider(color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 8),
            
            // Footer with Actions
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ngày tạo: $dateStr', style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('Người tạo: $creatorName', style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _handleEdit(item),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _handleDelete(id.toString(), code),
                    ),
                  ],
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

  Widget _buildFilterChip(String statusKey, String label, IconData icon, Color? statusColor) {
    final isSelected = _selectedStatus == statusKey;
    final activeColor = statusColor ?? kPrimaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_selectedStatus != statusKey) {
            setState(() {
              _selectedStatus = statusKey;
            });
            _loadPallets(isRefresh: true);
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.2) : const Color(0xFF16325B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor : Colors.white.withOpacity(0.1),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? activeColor : (statusColor?.withOpacity(0.7) ?? Colors.white54),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
