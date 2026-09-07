import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import '../../data/export_order_repository.dart';
import '../../data/supply_repository.dart';
import '../../../farm/data/farm_repository.dart';
import '../../../farm/domain/product.dart';
import 'package:intl/intl.dart';

class ExportOrderEditScreen extends ConsumerStatefulWidget {
  final String orderId;
  const ExportOrderEditScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  ConsumerState<ExportOrderEditScreen> createState() => _ExportOrderEditScreenState();
}

class OrderItemInput {
  String productId;
  int quantity;
  String notes;
  final TextEditingController qtyController;
  
  OrderItemInput({required this.productId, required this.quantity, this.notes = ''})
      : qtyController = TextEditingController(text: quantity.toString());
}

class _ExportOrderEditScreenState extends ConsumerState<ExportOrderEditScreen> {
  bool _isLoading = true; // initially true to fetch data
  bool _isSubmitting = false;

  List<dynamic> _dealers = [];
  List<dynamic> _warehouses = [];
  List<Product> _products = [];

  String? _selectedDealerId;
  String? _selectedWarehouseId;
  DateTime? _expectedDate;
  String _priority = 'MEDIUM';
  final _notesController = TextEditingController();

  List<OrderItemInput> _items = [];

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (var item in _items) {
      item.qtyController.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMasterData() async {
    setState(() => _isLoading = true);
    try {
      final supplyRepo = ref.read(supplyRepositoryProvider);
      final farmRepo = ref.read(farmRepositoryProvider);
      
      final results = await Future.wait([
        supplyRepo.getDealers(limit: 100),
        supplyRepo.getWarehouses(limit: 100),
      ]);
      
      // Load products
      final pRes = await farmRepo.getProducts();
      
      // Fetch current order data
      final orderRepo = ref.read(exportOrderRepositoryProvider);
      final order = await orderRepo.getDetail(widget.orderId);
      
      setState(() {
        _dealers = results[0];
        _warehouses = results[1];
        _products = pRes;
        
        // Populate form
        _selectedDealerId = order.dealerId;
        _selectedWarehouseId = order.sourceWarehouseId;
        if (order.createdAt != null) {
           // We might not have expectedDate in model, so using createdAt or leaving it
           try { _expectedDate = DateTime.parse(order.createdAt!); } catch (_) {}
        }
        _priority = order.priority;
        _notesController.text = order.notes ?? '';
        
        _items = order.items.map((e) => OrderItemInput(
          productId: e.productId,
          quantity: e.expectedQuantity,
          notes: e.notes ?? '',
        )).toList();

        if (_items.isEmpty) {
          _items.add(OrderItemInput(productId: '', quantity: 1));
        }
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu: $e')));
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00875A),
              onPrimary: Colors.white,
              surface: Color(0xFF16325B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _expectedDate = picked);
    }
  }

  void _addItem() {
    setState(() {
      _items.add(OrderItemInput(productId: '', quantity: 1));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].qtyController.dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _update() async {
    if (_selectedDealerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn Đại lý')));
      return;
    }
    if (_selectedWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn Kho xuất')));
      return;
    }
    
    // Validate items
    final validItems = _items.where((item) => item.productId.isNotEmpty && item.quantity > 0).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng thêm ít nhất 1 sản phẩm hợp lệ')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'dealerId': _selectedDealerId,
        'sourceWarehouseId': _selectedWarehouseId,
        'expectedDate': _expectedDate?.toIso8601String(),
        'priority': _priority,
        'notes': _notesController.text,
        'items': validItems.map((e) => {
          'productId': e.productId,
          'expectedQuantity': e.quantity,
          'notes': e.notes,
        }).toList(),
      };

      await ref.read(exportOrderRepositoryProvider).update(widget.orderId, payload);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật lệnh xuất kho thành công', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF00875A)));
        context.pop(true); // Return true to trigger refresh
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi cập nhật lệnh: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2B46),
      appBar: AppBar(
        title: const Text('Chỉnh sửa Lệnh Xuất Kho', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: const Color(0xFF0F2B46),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00875A)))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('THÔNG TIN CHUNG'),
                const SizedBox(height: 12),
                _buildGeneralInfoCard(),
                
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionTitle('DANH SÁCH SẢN PHẨM'),
                    TextButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add, color: Color(0xFF00875A), size: 18),
                      label: const Text('Thêm dòng', style: TextStyle(color: Color(0xFF00875A))),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                ...List.generate(_items.length, (index) => _buildItemCard(index)),
                
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _update,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00875A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('CẬP NHẬT LỆNH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
    );
  }

  Widget _buildGeneralInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16325B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Dealer
          _buildDropdownField(
            label: 'Đại lý (Khách hàng)',
            isRequired: true,
            value: _selectedDealerId,
            items: _dealers,
            hint: 'Chọn đại lý...',
            onChanged: (val) => setState(() => _selectedDealerId = val),
          ),
          const SizedBox(height: 16),
          
          // Warehouse
          _buildDropdownField(
            label: 'Kho Xuất Hàng',
            isRequired: true,
            value: _selectedWarehouseId,
            items: _warehouses,
            hint: 'Chọn nhà kho...',
            onChanged: (val) => setState(() => _selectedWarehouseId = val),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Thời gian dự kiến', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _selectDate,
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F2B46),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _expectedDate != null ? DateFormat('dd/MM/yyyy').format(_expectedDate!) : 'Chọn ngày',
                              style: TextStyle(color: _expectedDate != null ? Colors.white : Colors.white54, fontSize: 14),
                            ),
                            const Icon(Icons.calendar_today, color: Colors.white54, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mức ưu tiên', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F2B46),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          dropdownColor: const Color(0xFF16325B),
                          value: _priority,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          items: const [
                            DropdownMenuItem(value: 'HIGH', child: Text('Cao')),
                            DropdownMenuItem(value: 'MEDIUM', child: Text('Trung bình')),
                            DropdownMenuItem(value: 'LOW', child: Text('Thấp')),
                          ],
                          onChanged: (val) => setState(() => _priority = val!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ghi chú chung', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Nhập ghi chú vận chuyển...',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF0F2B46),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00875A))),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16325B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sản phẩm #${index + 1}', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
              if (_items.length > 1)
                InkWell(
                  onTap: () => _removeItem(index),
                  child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                )
            ],
          ),
          const SizedBox(height: 12),
          _buildProductDropdown(
            value: item.productId.isEmpty ? null : item.productId,
            onChanged: (val) => setState(() => item.productId = val ?? ''),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Số lượng', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F2B46),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, color: Colors.white, size: 16),
                            onPressed: item.quantity > 1 ? () {
                              setState(() {
                                item.quantity--;
                                item.qtyController.text = item.quantity.toString();
                              });
                            } : null,
                          ),
                          Expanded(
                            child: TextField(
                              controller: item.qtyController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (val) {
                                final parsed = int.tryParse(val);
                                if (parsed != null && parsed > 0) {
                                  item.quantity = parsed;
                                }
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.white, size: 16),
                            onPressed: () {
                              setState(() {
                                item.quantity++;
                                item.qtyController.text = item.quantity.toString();
                              });
                            },
                          ),
                        ],
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
                    const Text('Ghi chú', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 48,
                      child: TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Ghi chú...',
                          hintStyle: const TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: const Color(0xFF0F2B46),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00875A))),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onChanged: (val) => item.notes = val,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<dynamic> items,
    required String hint,
    required Function(String?) onChanged,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              if (isRequired) const TextSpan(text: '* ', style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
              TextSpan(text: label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F2B46),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              dropdownColor: const Color(0xFF16325B),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              value: value,
              hint: Text(hint, style: const TextStyle(color: Colors.white24, fontSize: 14)),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item['id'],
                  child: Text(item['name'] ?? item['id']),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductDropdown({
    required String? value,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2B46),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          dropdownColor: const Color(0xFF16325B),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
          value: value,
          hint: const Text('Chọn sản phẩm...', style: TextStyle(color: Colors.white24, fontSize: 14)),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: _products.map((item) {
            return DropdownMenuItem<String>(
              value: item.id,
              child: Text(item.name),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
