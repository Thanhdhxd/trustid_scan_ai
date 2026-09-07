import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/supply/data/dealer_providers.dart';
import 'package:trustid_scan_ai/supply/data/dealer_repository.dart';
import 'package:intl/intl.dart';

final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

class PosCheckoutSheet extends ConsumerStatefulWidget {
  const PosCheckoutSheet({super.key});

  @override
  ConsumerState<PosCheckoutSheet> createState() => _PosCheckoutSheetState();
}

class _PosCheckoutSheetState extends ConsumerState<PosCheckoutSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  bool _isCheckingOut = false;

  bool _isSavingCustomer = false;
  final TextEditingController _newNameController = TextEditingController();
  final TextEditingController _newPhoneController = TextEditingController();
  final TextEditingController _newAddressController = TextEditingController();

  Future<void> _searchCustomer(String q) async {
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final repo = ref.read(dealerRepositoryProvider);
      final results = await repo.searchCustomers(q);
      if (mounted) setState(() => _searchResults = results);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _selectCustomer(Map<String, dynamic> customer) async {
    ref.read(dealerCheckoutProvider.notifier).setCustomer(customer);
    _searchController.clear();
    setState(() => _searchResults = []);
    FocusScope.of(context).unfocus();

    // Re-resolve prices for loyalty customer
    final cartItems = ref.read(dealerCartProvider);
    final repo = ref.read(dealerRepositoryProvider);
    final customerId = customer['id']?.toString();
    if (customerId == null || customerId.isEmpty) return;

    for (var item in cartItems) {
      try {
        final newInfo = await repo.lookupPrice(item.serialNumber, customerId: customerId);
        final newPrice = (newInfo['finalPrice'] ?? newInfo['sellingPrice'] ?? newInfo['price'] ?? item.price);
        final newBase = (newInfo['basePrice'] ?? newInfo['sellingPrice'] ?? newInfo['price'] ?? item.basePrice);
        final newDisc = (newInfo['discountPercent'] ?? item.discountPercent);
        ref.read(dealerCartProvider.notifier).updatePrice(item.serialNumber, (newPrice as num).toDouble());
      } catch (_) {}
    }
  }

  void _showAddCustomerDialog() {
    _newNameController.clear();
    _newPhoneController.clear();
    _newAddressController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Đăng ký khách mới', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.redAccent),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _newNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Tên khách hàng (*)',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF16325B),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPhoneController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'Số điện thoại (*)',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF16325B),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newAddressController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Địa chỉ (Tùy chọn)',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF16325B),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSavingCustomer ? null : () async {
                      if (_newNameController.text.isEmpty || _newPhoneController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập Tên và Số điện thoại', style: TextStyle(color: Colors.white)), backgroundColor: Colors.orange));
                        return;
                      }
                      setModalState(() => _isSavingCustomer = true);
                      try {
                        final repo = ref.read(dealerRepositoryProvider);
                        final data = await repo.createCustomer({
                          'name': _newNameController.text.trim(),
                          'phone': _newPhoneController.text.trim(),
                          'address': _newAddressController.text.trim(),
                        });
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu khách hàng mới'), backgroundColor: Colors.green));
                        _selectCustomer(data);
                        Navigator.pop(context);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
                      } finally {
                        if (mounted) setModalState(() => _isSavingCustomer = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00875A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: _isSavingCustomer
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Lưu và Chọn', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _checkout() async {
    final cartItems = ref.read(dealerCartProvider);
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Giỏ hàng trống!'), backgroundColor: Colors.orange));
      return;
    }

    final zeroPriceItem = cartItems.any((i) => i.price <= 0);
    if (zeroPriceItem) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: const Color(0xFF16325B),
          title: const Text('Giá 0đ', style: TextStyle(color: Colors.white)),
          content: const Text('Có sản phẩm đang có giá 0đ. Tiếp tục?', style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy', style: TextStyle(color: Colors.white54))),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Tiếp tục', style: TextStyle(color: Colors.blueAccent))),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final checkoutState = ref.read(dealerCheckoutProvider);
    setState(() => _isCheckingOut = true);
    try {
      final repo = ref.read(dealerRepositoryProvider);

      // Build customer payload safely
      final Map<String, dynamic> payloadInfo;
      if (checkoutState.type == CustomerType.loyalty && checkoutState.selectedCustomer != null) {
        payloadInfo = {
          'id': checkoutState.selectedCustomer!['id'],
          'name': checkoutState.selectedCustomer!['name'] ?? 'Khách quen',
          'phone': checkoutState.selectedCustomer!['phone'],
          'address': checkoutState.selectedCustomer!['address'],
        }..removeWhere((key, value) => value == null);
      } else {
        payloadInfo = {'name': 'Khách lẻ'};
      }

      final totalAmount = cartItems.fold<double>(0, (sum, e) => sum + (e.price * e.quantity));
      final totalQuantity = cartItems.fold<int>(0, (sum, e) => sum + e.quantity);

      final payload = {
        'customerInfo': payloadInfo,
        'paymentMethod': checkoutState.paymentMethod,
        'totalAmount': totalAmount,
        'totalPrice': totalAmount,
        'finalAmount': totalAmount,
        'amount': totalAmount,
        'totalQuantity': totalQuantity,
        'items': cartItems.map((e) {
          final info = e.productInfo;
          final lineTotal = e.price * e.quantity;
          return {
            'serialNumber': e.serialNumber,
            'qrCode': e.qrCode,
            'productId': info['productId'] ?? info['id'], // Some APIs use id as productId
            'productName': info['productName'] ?? info['name'],
            'unitPrice': e.price,
            'price': e.isBag ? lineTotal : e.price,
            'lineTotal': lineTotal,
            'totalPrice': lineTotal,
            'totalAmount': lineTotal,
            'subtotal': lineTotal,
            'amount': lineTotal,
            'basePrice': e.isBag ? (e.basePrice * e.quantity) : e.basePrice,
            'unitBasePrice': e.basePrice,
            'discountPercent': e.discountPercent,
            'discountAmount': info['discountAmount'] ?? 0,
            'groupName': info['groupName'] ?? '',
            'originalPrice': info['sellingPrice'] ?? info['price'] ?? e.basePrice,
            'quantity': e.quantity,
            'bagQuantity': e.isBag ? e.quantity : 1,
            'isBag': e.isBag,
            'packets': e.packets,
            'packetCount': e.packets.length,
          };
        }).toList(),
      };

      await repo.checkoutSale(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanh toán thành công!'), backgroundColor: Colors.green));
        ref.read(dealerCartProvider.notifier).clearCart();
        ref.read(dealerCheckoutProvider.notifier).clear();
        
        // Invalidate dashboard providers so the data refreshes when returning to dashboard
        ref.invalidate(dealerDashboardStatsProvider);
        ref.invalidate(dealerTopProductsProvider);
        ref.invalidate(dealerActivityProvider);
      }
    } catch (e) {
      if (mounted) {
        String errMsg = e.toString();
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map && data['message'] != null) {
            errMsg = data['message'].toString();
            if (data['errors'] != null) {
              errMsg += '\\n${data['errors']}';
            }
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi: $errMsg'), 
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
      }
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  Color _hexToColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return Colors.blueAccent;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return Colors.blueAccent;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _newNameController.dispose();
    _newPhoneController.dispose();
    _newAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checkoutState = ref.watch(dealerCheckoutProvider);
    final cartItems = ref.watch(dealerCartProvider);
    final total = cartItems.fold<double>(0, (sum, e) => sum + e.price * e.quantity);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          // --- CUSTOMER SECTION ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Thông tin khách hàng', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => context.push('/dealer/customers'),
                child: const Text('Quản lý', style: TextStyle(color: Colors.blueAccent)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: RadioListTile<CustomerType>(
                  title: const Text('Khách lẻ', style: TextStyle(color: Colors.white, fontSize: 14)),
                  value: CustomerType.retail,
                  groupValue: checkoutState.type,
                  activeColor: Colors.blueAccent,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => ref.read(dealerCheckoutProvider.notifier).setType(val!),
                ),
              ),
              Expanded(
                child: RadioListTile<CustomerType>(
                  title: const Text('Khách quen', style: TextStyle(color: Colors.white, fontSize: 14)),
                  value: CustomerType.loyalty,
                  groupValue: checkoutState.type,
                  activeColor: Colors.blueAccent,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => ref.read(dealerCheckoutProvider.notifier).setType(val!),
                ),
              )
            ],
          ),
          if (checkoutState.type == CustomerType.loyalty) ...[
            if (checkoutState.selectedCustomer == null) ...[
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Tìm tên hoặc SĐT khách...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: _isSearching
                      ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
                ),
                onChanged: _searchCustomer,
              ),
              if (_searchResults.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final c = _searchResults[index];
                      return ListTile(
                        title: Text(c['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        trailing: Text(c['phone'] ?? '', style: const TextStyle(color: Colors.white54)),
                        onTap: () => _selectCustomer(c),
                      );
                    },
                  ),
                ),
              Center(
                child: TextButton.icon(
                  onPressed: _showAddCustomerDialog,
                  icon: const Icon(Icons.add, color: Colors.greenAccent),
                  label: const Text('Thêm khách hàng mới', style: TextStyle(color: Colors.greenAccent)),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1), 
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8)
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(checkoutState.selectedCustomer!['name'] ?? '', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('SĐT: ${checkoutState.selectedCustomer!['phone'] ?? ''}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          if (checkoutState.selectedCustomer!['address'] != null && checkoutState.selectedCustomer!['address'].toString().isNotEmpty)
                            Text('ĐC: ${checkoutState.selectedCustomer!['address']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          
                          if (checkoutState.selectedCustomer!['group'] != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _hexToColor(checkoutState.selectedCustomer!['group']['color']?.toString()),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    checkoutState.selectedCustomer!['group']['name'] ?? 'Nhóm',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if ((num.tryParse(checkoutState.selectedCustomer!['group']['discountPercent']?.toString() ?? '0') ?? 0) > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Text(
                                      'CK ${(num.tryParse(checkoutState.selectedCustomer!['group']['discountPercent']?.toString() ?? '0') ?? 0).toString().replaceAll(RegExp(r'\\.0$'), '')}%',
                                      style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                      onPressed: () => ref.read(dealerCheckoutProvider.notifier).setCustomer(null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  ],
                ),
              )
            ]
          ],
          const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // Fixed bottom bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- TOTAL AMOUNT ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tổng tiền:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(formatCurrency.format(total), style: const TextStyle(color: Colors.greenAccent, fontSize: 26, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: Colors.white12, height: 24),

                // --- PAYMENT METHOD ---
                const Text('Thanh toán bằng:', style: TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: const Color(0xFF16325B), borderRadius: BorderRadius.circular(8)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: checkoutState.paymentMethod,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF16325B),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Tiền mặt')),
                        DropdownMenuItem(value: 'transfer', child: Text('Chuyển khoản / Quẹt thẻ')),
                      ],
                      onChanged: (v) {
                        if (v != null) ref.read(dealerCheckoutProvider.notifier).setPaymentMethod(v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                CheckboxListTile(
                  title: const Text('Thanh toán và in hóa đơn', style: TextStyle(color: Colors.white, fontSize: 14)),
                  value: checkoutState.autoPrint,
                  onChanged: (val) {
                    if (val != null) ref.read(dealerCheckoutProvider.notifier).setAutoPrint(val);
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Colors.blueAccent,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isCheckingOut || cartItems.isEmpty ? null : _checkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00875A),
                      disabledBackgroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isCheckingOut
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('THANH TOÁN', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
