import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';
import '../../data/farm_repository.dart';
import '../../domain/material.dart';
import 'widgets/material_form_dialog.dart';
import 'widgets/material_stock_dialog.dart';

class MaterialListScreen extends ConsumerStatefulWidget {
  const MaterialListScreen({super.key});

  @override
  ConsumerState<MaterialListScreen> createState() => _MaterialListScreenState();
}

class _MaterialListScreenState extends ConsumerState<MaterialListScreen> {
  static const Color kPrimaryColor = Color(0xFF00875A);
  static const Color kBackgroundDark = Color(0xFF0F2B46);
  static const Color kSurfaceDark = Color(0xFF16325B);
  static const Color kTextLight = Color(0xFFE8EDF3);
  static const Color kTextGray = Color(0xFF94A3B8);

  bool _isLoading = true;
  List<FarmMaterial> _materials = [];
  String _searchQuery = '';
  String _filterType = 'Tất cả';

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
    _loadMaterials(isRefresh: true);
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
        _loadMaterials();
      }
    }
  }

  String? _getApiType(String filterValue) {
    switch (filterValue) {
      case 'Phân bón': return 'FERTILIZER';
      case 'Giống': return 'SEED';
      case 'Thuốc BVTV': return 'PESTICIDE';
      case 'Khác': return 'OTHER';
      default: return null; // 'Tất cả'
    }
  }

  Future<void> _loadMaterials({bool isRefresh = false}) async {
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
      final repo = ref.read(farmRepositoryProvider);
      
      final type = _getApiType(_filterType);
      
      final data = await repo.getMaterials({
        'page': _currentPage,
        'limit': _limit,
        if (_searchQuery.isNotEmpty) 'search': _searchQuery,
        if (type != null) 'type': type,
      });

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _materials = data;
          } else {
            _materials.addAll(data);
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanErrorMessage(e))));
      }
    }
  }

  Future<void> _toggleStatus(FarmMaterial material) async {
    // Optimistic update to prevent disappearing
    setState(() {
      material.isActive = !material.isActive;
    });
    try {
      await ref.read(farmRepositoryProvider).toggleMaterialStatus(material.id, material.isActive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(material.isActive ? 'Đã bật vật tư' : 'Đã tắt vật tư'),
          backgroundColor: kPrimaryColor,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      // Revert on error
      setState(() {
        material.isActive = !material.isActive;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi cập nhật trạng thái: $e')));
    }
  }

  void _showMaterialForm([FarmMaterial? material]) {
    showDialog(
      context: context,
      builder: (_) => MaterialFormDialog(
        material: material,
        onSaved: () => _loadMaterials(isRefresh: true),
      ),
    );
  }

  void _showStockDialog(FarmMaterial material, bool isImport) {
    showDialog(
      context: context,
      builder: (_) => MaterialStockDialog(
        material: material,
        isImport: isImport,
        onSaved: () => _loadMaterials(isRefresh: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      appBar: AppBar(
        title: const Text('Quản lý Vật tư & Kho', style: TextStyle(color: kTextLight)),
        backgroundColor: kBackgroundDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextGray),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
                : _materials.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () => _loadMaterials(isRefresh: true),
                        color: kPrimaryColor,
                        backgroundColor: kSurfaceDark,
                        child: _buildList(),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMaterialForm(),
        backgroundColor: kPrimaryColor,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.inventory_2, color: Colors.white, size: 26),
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.add, color: kPrimaryColor, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: kSurfaceDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: TextField(
                style: const TextStyle(color: kTextLight),
                decoration: const InputDecoration(
                  icon: Icon(Icons.search, color: kTextGray, size: 20),
                  hintText: 'Tìm theo tên, mã...',
                  hintStyle: TextStyle(color: kTextGray, fontSize: 14),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  _searchQuery = val;
                  if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
                  _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                    _loadMaterials(isRefresh: true);
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: kSurfaceDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _filterType,
                  isExpanded: true,
                  dropdownColor: kSurfaceDark,
                  icon: const Icon(Icons.keyboard_arrow_down, color: kTextGray),
                  style: const TextStyle(color: kTextLight, fontSize: 14),
                  items: ['Tất cả', 'Phân bón', 'Giống', 'Thuốc BVTV', 'Khác'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _filterType = val ?? 'Tất cả';
                    });
                    _loadMaterials(isRefresh: true);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white24),
          SizedBox(height: 16),
          Text('Chưa có vật tư nào', style: TextStyle(color: kTextGray, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 88),
      itemCount: _materials.length + 1,
      itemBuilder: (context, index) {
        if (index == _materials.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: _hasMoreData 
                  ? const CircularProgressIndicator(color: kPrimaryColor)
                  : const Text('Đã hiển thị hết danh sách', style: TextStyle(color: kTextGray)),
            ),
          );
        }
        final item = _materials[index];
        return _buildMaterialCard(item);
      },
    );
  }

  Widget _buildMaterialCard(FarmMaterial material) {
    Color typeColor;
    switch (material.type) {
      case 'FERTILIZER': typeColor = Colors.lightGreen; break;
      case 'SEED': typeColor = Colors.tealAccent; break;
      case 'PESTICIDE': typeColor = Colors.orangeAccent; break;
      default: typeColor = Colors.grey; break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: typeColor.withOpacity(0.5)),
                ),
                child: Text(
                  material.typeLabel,
                  style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              if (material.code != null && material.code!.isNotEmpty)
                Text(
                  material.code!,
                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              const Spacer(),
              _buildCustomSwitch(material),
            ],
          ),
          const SizedBox(height: 8),
          Text(material.name, style: const TextStyle(color: kTextLight, fontSize: 16, fontWeight: FontWeight.bold)),
          if (material.description != null && material.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(material.description!, style: const TextStyle(color: kTextGray, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tồn kho', style: TextStyle(color: kTextGray, fontSize: 12)),
                  Row(
                    children: [
                      Text(
                        material.stockQuantity.toStringAsFixed(material.stockQuantity.truncateToDouble() == material.stockQuantity ? 0 : 2),
                        style: TextStyle(color: material.stockQuantity > 0 ? kPrimaryColor : Colors.orange, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      Text(material.unit, style: const TextStyle(color: kTextGray, fontSize: 14)),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              _buildActionButton(Icons.edit, 'Sửa', Colors.blue, () => _showMaterialForm(material)),
              const SizedBox(width: 8),
              _buildActionButton(Icons.download, 'Nhập', kPrimaryColor, () => _showStockDialog(material, true)),
              const SizedBox(width: 8),
              _buildActionButton(Icons.outbox, 'Xuất', Colors.orange, () => _showStockDialog(material, false)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomSwitch(FarmMaterial material) {
    return GestureDetector(
      onTap: () => _toggleStatus(material),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 60,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: material.isActive ? kPrimaryColor : Colors.white.withOpacity(0.2),
        ),
        child: Stack(
          alignment: material.isActive ? Alignment.centerRight : Alignment.centerLeft,
          children: [
            Align(
              alignment: material.isActive ? Alignment.centerLeft : Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  material.isActive ? 'Bật' : 'Tắt',
                  style: TextStyle(
                    color: material.isActive ? Colors.white : Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(2),
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}
