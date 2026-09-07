import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';
import '../../data/farm_repository.dart';
import '../../domain/product.dart';
import 'package:trustid_scan_ai/core/constants/api_constants.dart';
import 'product_form_screen.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  static const Color kPrimaryColor = Color(0xFF00875A);
  static const Color kBackgroundDark = Color(0xFF0F2B46);
  static const Color kSurfaceDark = Color(0xFF16325B);
  static const Color kTextLight = Color(0xFFE8EDF3);
  static const Color kTextGray = Color(0xFF94A3B8);

  bool _isLoading = true;
  List<Product> _products = [];
  List<dynamic> _categories = [];
  String _searchQuery = '';
  String? _selectedCategoryId;

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
    _loadCategories();
    _loadProducts(isRefresh: true);
  }

  Future<void> _loadCategories() async {
    try {
      final repo = ref.read(farmRepositoryProvider);
      final cats = await repo.getCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
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
        _loadProducts();
      }
    }
  }

  Future<void> _loadProducts({bool isRefresh = false}) async {
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
      
      final data = await repo.getProducts({
        'page': _currentPage,
        'limit': _limit,
        if (_searchQuery.isNotEmpty) 'search': _searchQuery,
        if (_selectedCategoryId != null) 'categoryId': _selectedCategoryId,
      });

      if (mounted) {
        setState(() {
          if (isRefresh) {
            _products = data;
          } else {
            _products.addAll(data);
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

  String _getImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiConstants.baseUrl}/${path.startsWith("/") ? path.substring(1) : path}';
  }

  void _showProductForm([Product? product]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(
          product: product,
          categories: _categories,
          onSaved: () => _loadProducts(isRefresh: true),
        ),
      ),
    );
  }

  String _getCategoryName(String? id, List<dynamic> list) {
    if (id == null) return 'Tất cả';
    for (var c in list) {
      if (c['id'] == id) return c['name'] ?? 'Unknown';
      if (c['children'] != null && c['children'] is List && c['children'].isNotEmpty) {
        final childResult = _getCategoryName(id, c['children']);
        if (childResult != 'Tất cả') return childResult;
      }
    }
    return 'Tất cả';
  }

  void _showCategoryOverlay(BuildContext buttonContext) {
    final RenderBox renderBox = buttonContext.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        return Stack(
          children: [
            Positioned(
              left: position.dx,
              top: position.dy + size.height + 4,
              width: size.width, // Trùng width với button
              child: Material(
                elevation: 8,
                color: kSurfaceDark,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        dense: true,
                        title: const Text('Tất cả', style: TextStyle(color: kTextLight)),
                        onTap: () {
                          setState(() => _selectedCategoryId = null);
                          Navigator.pop(ctx);
                          _loadProducts(isRefresh: true);
                        },
                      ),
                      ..._categories.map((c) => _buildCategoryNode(ctx, c, 0)).toList(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryNode(BuildContext ctx, dynamic category, int level) {
    final hasChildren = category['children'] != null && category['children'] is List && category['children'].isNotEmpty;
    
    if (hasChildren) {
      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: Colors.blueAccent,
          collapsedIconColor: kTextGray,
          tilePadding: EdgeInsets.only(left: 16.0 + level * 16.0, right: 16.0),
          title: Text(category['name'] ?? 'Unknown', style: const TextStyle(color: kTextLight, fontSize: 13)),
          children: (category['children'] as List).map((child) => _buildCategoryNode(ctx, child, level + 1)).toList(),
        ),
      );
    }

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.only(left: 16.0 + level * 16.0, right: 16.0),
      title: Text(category['name'] ?? 'Unknown', style: const TextStyle(color: kTextLight, fontSize: 13)),
      onTap: () {
        setState(() => _selectedCategoryId = category['id']);
        Navigator.pop(ctx);
        _loadProducts(isRefresh: true);
      },
    );
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurfaceDark,
        title: const Text('Xác nhận xóa', style: TextStyle(color: kTextLight)),
        content: Text('Bạn có chắc chắn muốn xóa sản phẩm "${product.name}"?', style: const TextStyle(color: kTextGray)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy', style: TextStyle(color: kTextGray))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(farmRepositoryProvider).deleteProduct(product.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa sản phẩm')));
          _loadProducts(isRefresh: true);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi xóa: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      appBar: AppBar(
        title: const Text('Danh mục Sản phẩm', style: TextStyle(color: kTextLight)),
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
                : _products.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () => _loadProducts(isRefresh: true),
                        color: kPrimaryColor,
                        backgroundColor: kSurfaceDark,
                        child: _buildList(),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductForm(),
        backgroundColor: kPrimaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
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
                  hintText: 'Tìm theo tên, mã GTIN...',
                  hintStyle: TextStyle(color: kTextGray, fontSize: 14),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  _searchQuery = val;
                  if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
                  _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                    _loadProducts(isRefresh: true);
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Builder(
              builder: (btnCtx) => InkWell(
                onTap: () => _showCategoryOverlay(btnCtx),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: kSurfaceDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _getCategoryName(_selectedCategoryId, _categories),
                        style: const TextStyle(color: kTextLight, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: kTextGray),
                  ],
                ),
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
          Text('Chưa có sản phẩm nào', style: TextStyle(color: kTextGray, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 88),
      itemCount: _products.length + 1,
      itemBuilder: (context, index) {
        if (index == _products.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: _hasMoreData 
                  ? const CircularProgressIndicator(color: kPrimaryColor)
                  : const Text('Đã hiển thị hết danh sách', style: TextStyle(color: kTextGray)),
            ),
          );
        }
        final item = _products[index];
        return _buildProductCard(item);
      },
    );
  }

  Widget _buildProductCard(Product product) {
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: product.images.isNotEmpty
                ? Image.network(
                    _getImageUrl(product.images.first),
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                  )
                : _buildImagePlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name, 
                  style: const TextStyle(color: kTextLight, fontSize: 16, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 4),
                if (product.gtinCode != null && product.gtinCode!.isNotEmpty)
                  Text('GTIN: ${product.gtinCode}', style: const TextStyle(color: kTextGray, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (product.price != null)
                      Text(
                        '${product.price} đ',
                        style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold),
                      )
                    else
                      const Text('Giá: N/A', style: TextStyle(color: kTextGray)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          product.categoryName ?? 'Chưa phân loại',
                          style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Quy cách', style: TextStyle(color: kTextGray, fontSize: 11)),
                        Text(
                          product.netWeight != null ? '${product.netWeight} ${product.weightUnit ?? ""}' : '---',
                          style: const TextStyle(color: kTextLight, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Đóng bao', style: TextStyle(color: kTextGray, fontSize: 11)),
                        Text(
                          product.defaultPackagingSpec != null ? '${product.defaultPackagingSpec} gói/bao' : '---',
                          style: const TextStyle(color: kTextLight, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildActionButton(Icons.edit, 'Sửa', Colors.blue, () => _showProductForm(product)),
                    const SizedBox(width: 8),
                    _buildActionButton(Icons.delete, 'Xóa', Colors.red, () => _deleteProduct(product)),
                  ],
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildImagePlaceholder() {
    return Container(
      width: 60,
      height: 60,
      color: Colors.white.withOpacity(0.05),
      child: const Icon(Icons.inventory_2_outlined, color: Colors.white24, size: 28),
    );
  }
}
