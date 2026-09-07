import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/supply/data/dealer_repository.dart';
import 'package:intl/intl.dart';

final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

const List<String> kUnitOptions = [
  'cái', 'hộp', 'thùng', 'chai', 'gói', 'kg', 'lon', 'vỉ', 'tuýp', 'mét', 'lít', 'túi'
];

class DealerPricingScreen extends ConsumerStatefulWidget {
  const DealerPricingScreen({super.key});

  @override
  ConsumerState<DealerPricingScreen> createState() => _DealerPricingScreenState();
}

class _DealerPricingScreenState extends ConsumerState<DealerPricingScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1929),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F2B46),
          title: const Text('Cài đặt Bảng giá Bán lẻ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.blueAccent,
            tabs: [
              Tab(text: 'Giá gốc (tất cả)'),
              Tab(text: 'Giá theo Nhóm KH'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BasePricingTab(),
            _GroupPricingTab(),
          ],
        ),
      ),
    );
  }
}

// --- BASE PRICING TAB ---

class _BasePricingTab extends ConsumerStatefulWidget {
  const _BasePricingTab();

  @override
  ConsumerState<_BasePricingTab> createState() => _BasePricingTabState();
}

class _BasePricingTabState extends ConsumerState<_BasePricingTab> {
  bool _isLoading = true;
  List<dynamic> _prices = [];
  String? _error;
  String? _savingId;

  // Controllers for inline editing
  final Map<String, TextEditingController> _priceControllers = {};
  final Map<String, String> _selectedUnits = {};

  @override
  void initState() {
    super.initState();
    _fetchPrices();
  }

  Future<void> _fetchPrices() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final repo = ref.read(dealerRepositoryProvider);
      final data = await repo.getDealerPrices();
      
      _priceControllers.clear();
      _selectedUnits.clear();
      for (var item in data) {
        final id = item['productId'] ?? item['product']?['id'];
        if (id != null) {
          _priceControllers[id] = TextEditingController(text: '${item['sellingPrice'] ?? 0}');
          final u = (item['unit'] ?? 'cái').toString().toLowerCase();
          _selectedUnits[id] = kUnitOptions.contains(u) ? u : 'cái';
        }
      }

      if (mounted) setState(() => _prices = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _savePrice(String productId) async {
    final priceVal = num.tryParse(_priceControllers[productId]?.text ?? '0')?.toInt() ?? 0;
    if (priceVal < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Giá bán không được âm'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _savingId = productId);
    try {
      await ref.read(dealerRepositoryProvider).saveDealerPrice({
        'productId': productId,
        'sellingPrice': priceVal,
        'unit': _selectedUnits[productId] ?? 'cái',
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu thành công!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  @override
  void dispose() {
    for (var c in _priceControllers.values) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Lỗi: $_error', style: const TextStyle(color: Colors.red)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Note Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
          ),
          child: const Text(
            '*Lưu ý: Bảng giá này được dùng tự động nhập giá khi quét mã QR lúc bán lẻ cho khách. Nếu không có ở đây, hệ thống sẽ mặc định giá bán là 0.',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
          ),
        ),
        const SizedBox(height: 16),

        // Responsive Cards list instead of Data Table
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _prices.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = _prices[index];
            final id = item['productId'] ?? item['product']?['id'];
            final productName = item['productName'] ?? item['product']?['name'] ?? 'Sản phẩm';

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F2B46),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6)),
                        child: Text('${index + 1}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(productName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Giá bán (VND)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _priceControllers[id],
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
                              ],
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                filled: true,
                                fillColor: Colors.black26,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Đơn vị', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedUnits[id],
                                  dropdownColor: const Color(0xFF16325B),
                                  isExpanded: true,
                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  items: kUnitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => _selectedUnits[id] = v);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _savingId == id ? null : () => _savePrice(id),
                      icon: _savingId == id 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save, color: Colors.white, size: 18),
                      label: const Text('Lưu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        // Add Product Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F2B46),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Thêm Sản phẩm vào Bảng giá', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white24, height: 24),
              _AddPriceForm(onAdded: _fetchPrices),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddPriceForm extends ConsumerStatefulWidget {
  final VoidCallback onAdded;
  const _AddPriceForm({required this.onAdded});

  @override
  ConsumerState<_AddPriceForm> createState() => _AddPriceFormState();
}

class _AddPriceFormState extends ConsumerState<_AddPriceForm> {
  final _searchController = TextEditingController();
  final _priceController = TextEditingController(text: '0');
  String _selectedUnit = 'cái';
  
  List<dynamic> _searchResults = [];
  bool _searching = false;
  String? _selectedProductId;
  String? _selectedProductName;
  bool _adding = false;
  Timer? _debounce;

  void _onSearchChanged(String q) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchProducts(q);
    });
  }

  void _searchProducts(String q) async {
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final results = await ref.read(dealerRepositoryProvider).searchSystemProducts(q);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    }
  }

  void _add() async {
    if (_selectedProductId == null) return;
    final priceVal = num.tryParse(_priceController.text)?.toInt() ?? 0;
    if (priceVal < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Giá bán không được âm'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _adding = true);
    try {
      await ref.read(dealerRepositoryProvider).saveDealerPrice({
        'productId': _selectedProductId,
        'sellingPrice': priceVal,
        'unit': _selectedUnit,
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm sản phẩm!'), backgroundColor: Colors.green));
      setState(() {
        _selectedProductId = null;
        _selectedProductName = null;
        _searchController.clear();
      });
      widget.onAdded();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_selectedProductId == null) ...[
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Tìm sản phẩm trên hệ thống...',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.black26,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: Colors.blueAccent),
                onPressed: () => _searchProducts(_searchController.text),
              ),
            ),
            onChanged: _onSearchChanged,
            onSubmitted: _searchProducts,
          ),
          if (_searching) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())
          else if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (ctx, i) {
                  final p = _searchResults[i];
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedProductId = p['id'];
                        _selectedProductName = p['name'];
                        _searchResults = [];
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.white12)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              p['name'] ?? '', 
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'GTIN: ${p['gtin'] ?? 'N/A'}', 
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Expanded(child: Text(_selectedProductName ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => setState(() => _selectedProductId = null),
                )
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Giá bán', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
                    ],
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black26,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Đơn vị', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedUnit,
                        dropdownColor: const Color(0xFF16325B),
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        items: kUnitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedUnit = v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF67C23A), // Green matching web
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _adding || _selectedProductId == null ? null : _add,
            child: _adding 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Thêm vào BG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

// --- GROUP PRICING TAB ---

class _GroupPricingTab extends ConsumerStatefulWidget {
  const _GroupPricingTab();

  @override
  ConsumerState<_GroupPricingTab> createState() => _GroupPricingTabState();
}

class _GroupPricingTabState extends ConsumerState<_GroupPricingTab> {
  bool _loadingGroups = true;
  List<dynamic> _groups = [];
  String? _selectedGroupId;
  String? _error;

  bool _loadingRules = false;
  List<dynamic> _rules = [];
  List<dynamic> _basePrices = [];
  String? _savingRuleId;
  String? _deletingRuleId;

  // Controllers for inline editing
  final Map<String, String> _ruleTypes = {};
  final Map<String, TextEditingController> _ruleValueControllers = {};

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() { _loadingGroups = true; _error = null; });
    try {
      final repo = ref.read(dealerRepositoryProvider);
      final groups = await repo.getCustomerGroups();
      final base = await repo.getDealerPrices();
      if (mounted) {
        setState(() {
          _groups = groups;
          _basePrices = base;
          _loadingGroups = false;
        });
        if (_groups.isNotEmpty) {
          _selectGroup(_groups.first['id']);
        }
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loadingGroups = false; });
    }
  }

  Future<void> _selectGroup(String groupId) async {
    setState(() {
      _selectedGroupId = groupId;
      _loadingRules = true;
    });
    try {
      final rules = await ref.read(dealerRepositoryProvider).getGroupPricingRules(groupId);
      
      _ruleTypes.clear();
      _ruleValueControllers.clear();
      
      for (var rule in rules) {
        final pid = rule['productId'];
        if (pid != null) {
          final type = rule['ruleType'] ?? 'discount_percent';
          _ruleTypes[pid] = type;
          if (type == 'fixed_price') {
            _ruleValueControllers[pid] = TextEditingController(text: '${rule['fixedPrice'] ?? 0}');
          } else {
            _ruleValueControllers[pid] = TextEditingController(text: '${rule['discountPercent'] ?? 0}');
          }
        }
      }

      if (mounted) {
        setState(() {
          _rules = rules;
          _loadingRules = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingRules = false);
    }
  }

  void _saveRule(String productId) async {
    if (_selectedGroupId == null) return;
    final type = _ruleTypes[productId] ?? 'discount_percent';
    final valText = _ruleValueControllers[productId]?.text ?? '0';
    final val = num.tryParse(valText) ?? 0;
    
    if (type == 'discount_percent' && (val < 0 || val > 100)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phần trăm chiết khấu phải từ 0% đến 100%'), backgroundColor: Colors.orange));
      return;
    }
    if (type == 'fixed_price' && val < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Giá bán không được âm'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _savingRuleId = productId);
    try {
      final payload = <String, dynamic>{
        'groupId': _selectedGroupId,
        'productId': productId,
        'ruleType': type,
      };
      
      if (type == 'fixed_price') {
        payload['fixedPrice'] = val;
      } else {
        payload['discountPercent'] = val;
      }
      
      await ref.read(dealerRepositoryProvider).saveGroupPricingRule(payload);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu rule giá!'), backgroundColor: Colors.green));
      _selectGroup(_selectedGroupId!);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _savingRuleId = null);
    }
  }

  void _deleteRule(String productId) async {
    if (_selectedGroupId == null) return;
    final rule = _rules.firstWhere((r) => r['productId'] == productId, orElse: () => {});
    if (rule.isEmpty || rule['id'] == null) return;

    setState(() => _deletingRuleId = productId);
    try {
      await ref.read(dealerRepositoryProvider).deleteGroupPricingRule(rule['id']);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa rule giá!'), backgroundColor: Colors.green));
      _selectGroup(_selectedGroupId!);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi xóa: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _deletingRuleId = null);
    }
  }

  Color _colorFromHex(String? hexString) {
    if (hexString == null || hexString.isEmpty) return Colors.grey;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.tryParse(buffer.toString(), radix: 16) ?? 0xFF9E9E9E);
  }

  @override
  void dispose() {
    for (var c in _ruleValueControllers.values) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingGroups) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Lỗi: $_error', style: const TextStyle(color: Colors.red)));
    if (_groups.isEmpty) return const Center(child: Text('Chưa có nhóm Khách hàng nào', style: TextStyle(color: Colors.white54)));

    final selectedGroupObj = _groups.firstWhere((g) => g['id'] == _selectedGroupId, orElse: () => {});
    final defaultDiscount = num.tryParse('${selectedGroupObj['discountPercent'] ?? 0}') ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Horizontal Group Selector
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _groups.length,
            itemBuilder: (context, index) {
              final g = _groups[index];
              final isSelected = g['id'] == _selectedGroupId;
              return GestureDetector(
                onTap: () => _selectGroup(g['id']),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blueAccent.withOpacity(0.1) : Colors.black12,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isSelected ? Colors.blueAccent : Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(color: _colorFromHex(g['color']), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(g['name'] ?? '', style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.white70, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
                        child: Text('${g['customerCount'] ?? 0} KH', style: const TextStyle(fontSize: 10, color: Colors.white54)),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Chiết khấu mặc định nhóm:', style: TextStyle(color: Colors.white70)),
              Text('${formatCurrency.format(defaultDiscount).replaceAll('đ', '')}%', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Responsive Cards List
        if (_loadingRules)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _basePrices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final bp = _basePrices[index];
              final productId = bp['productId'] ?? bp['product']?['id'];
              final productName = bp['productName'] ?? bp['product']?['name'] ?? 'Sản phẩm';
              final basePrice = num.tryParse(bp['sellingPrice']?.toString() ?? '0') ?? 0;
              
              final ruleType = _ruleTypes[productId] ?? 'discount_percent';
              final ruleExists = _rules.any((r) => r['productId'] == productId);
              
              if (_ruleValueControllers[productId] == null) {
                _ruleValueControllers[productId] = TextEditingController(text: '$defaultDiscount');
              }

              final valStr = _ruleValueControllers[productId]!.text;
              final valNum = num.tryParse(valStr) ?? 0;
              
              num finalPrice = basePrice;
              if (ruleType == 'fixed_price') {
                finalPrice = valNum;
              } else {
                finalPrice = (basePrice * (1 - valNum / 100)).round();
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F2B46),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6)),
                          child: Text('${index + 1}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(productName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('Giá gốc: ${formatCurrency.format(basePrice)}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Loại thiết lập', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: ruleType,
                                    dropdownColor: const Color(0xFF16325B),
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    items: const [
                                      DropdownMenuItem(value: 'discount_percent', child: Text('% Chiết khấu')),
                                      DropdownMenuItem(value: 'fixed_price', child: Text('Giá cứng')),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() {
                                          _ruleTypes[productId] = v;
                                          if (v == 'discount_percent') {
                                            _ruleValueControllers[productId]!.text = '$defaultDiscount';
                                          } else {
                                            _ruleValueControllers[productId]!.text = '$basePrice';
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Giá trị', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _ruleValueControllers[productId],
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
                                ],
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  filled: true,
                                  fillColor: Colors.black26,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                ),
                                onChanged: (v) => setState((){}),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Giá cuối (thực bán)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(formatCurrency.format(finalPrice), style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                        Row(
                          children: [
                            if (ruleExists)
                              TextButton(
                                onPressed: _deletingRuleId == productId ? null : () => _deleteRule(productId),
                                child: _deletingRuleId == productId
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2))
                                  : const Text('Xóa', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                              ),
                            if (ruleExists) const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              onPressed: _savingRuleId == productId ? null : () => _saveRule(productId),
                              icon: _savingRuleId == productId 
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.save, color: Colors.white, size: 18),
                              label: const Text('Lưu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
