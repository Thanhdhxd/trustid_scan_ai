import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/prod_order_constants.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';

typedef LotSearchFetcher = Future<List<Map<String, dynamic>>> Function(String search);

/// BottomSheet chọn lô nguyên liệu nguồn hỗ trợ tìm kiếm trực tiếp từ server (Remote Search).
class ProdOrderLotPickerSheet extends StatefulWidget {
  final bool isFarm;
  final String title;
  final String productName;
  final String? selectedKey;
  final LotSearchFetcher onFetchLots;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const ProdOrderLotPickerSheet({
    super.key,
    required this.isFarm,
    required this.title,
    required this.productName,
    required this.selectedKey,
    required this.onFetchLots,
    required this.onSelect,
  });

  static Future<void> show({
    required BuildContext context,
    required bool isFarm,
    required String title,
    required String productName,
    required String? selectedKey,
    required LotSearchFetcher onFetchLots,
    required ValueChanged<Map<String, dynamic>> onSelect,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: kProdOrderBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ProdOrderLotPickerSheet(
        isFarm: isFarm,
        title: title,
        productName: productName,
        selectedKey: selectedKey,
        onFetchLots: onFetchLots,
        onSelect: onSelect,
      ),
    );
  }

  @override
  State<ProdOrderLotPickerSheet> createState() => _ProdOrderLotPickerSheetState();
}

class _ProdOrderLotPickerSheetState extends State<ProdOrderLotPickerSheet> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _fetchLots('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLots(String query) async {
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.onFetchLots(query.trim());
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _items = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _loading = false;
        _error = parseSupplyHttpError(e).message;
      });
    }
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchLots(val);
    });
  }

  double _extractRemainingKg(Map<String, dynamic> lot) {
    final raw = widget.isFarm
        ? (lot['remainingQuantityKg'] ?? lot['quantityKg'] ?? lot['totalQuantity'] ?? 0)
        : (lot['availableQuantity'] ??
            lot['remainingQuantityKg'] ??
            lot['totalQuantity'] ??
            lot['totalUnitsExpected'] ??
            lot['quantity'] ??
            0);
    return double.tryParse(raw.toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sản phẩm: ${widget.productName}',
                          style: const TextStyle(color: kProdOrderTextGray, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: prodOrderInputDeco(
                  null,
                  hint: 'Tìm theo mã lô hoặc tên sản phẩm...',
                  prefixIcon: const Icon(Icons.search, color: kProdOrderTextGray, size: 18),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: kProdOrderTextGray, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _fetchLots('');
                          },
                        )
                      : null,
                ),
                onChanged: (val) {
                  setState(() {});
                  _onSearchChanged(val);
                },
              ),
              const Divider(color: Colors.white12, height: 20),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: kProdOrderPrimary),
                  ),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => _fetchLots(_searchCtrl.text),
                          icon: const Icon(Icons.refresh, color: kProdOrderPrimaryLight),
                          label: const Text('Thử lại', style: TextStyle(color: kProdOrderPrimaryLight)),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.inventory_2_outlined, color: Colors.white24, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Không tìm thấy lô nguồn khả dụng (> 0 kg).',
                          style: TextStyle(
                            color: kProdOrderTextGray.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final lot = _items[idx];
                      final code = (lot['batchCode'] ?? lot['batch_code'] ?? '').toString();
                      final id = lot['id']?.toString();
                      final key = widget.isFarm ? code : id;
                      final isSelected = key != null && key == widget.selectedKey;
                      final pName = (lot['product']?['name'] ??
                              lot['productName'] ??
                              widget.productName)
                          .toString();
                      final remainingKg = _extractRemainingKg(lot);

                      final dateStr =
                          lot['harvestDate'] ?? lot['createdAt'] ?? lot['created_at'];
                      String formattedDate = '';
                      if (dateStr != null) {
                        final d = DateTime.tryParse(dateStr.toString());
                        if (d != null) {
                          formattedDate = DateFormat('dd/MM/yyyy').format(d.toLocal());
                        }
                      }

                      return InkWell(
                        onTap: () {
                          widget.onSelect(lot);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? kProdOrderPrimary.withValues(alpha: 0.15)
                                : kProdOrderSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? kProdOrderPrimaryLight
                                  : Colors.white.withValues(alpha: 0.08),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? kProdOrderPrimary.withValues(alpha: 0.3)
                                      : kProdOrderFieldBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  widget.isFarm
                                      ? Icons.agriculture_rounded
                                      : Icons.local_shipping_rounded,
                                  color: isSelected ? kProdOrderPrimaryLight : Colors.white70,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      code,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      formattedDate.isNotEmpty
                                          ? '$pName • $formattedDate'
                                          : pName,
                                      style: const TextStyle(
                                        color: kProdOrderTextGray,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F3B5C),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.lightBlueAccent.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Còn lại',
                                      style: TextStyle(
                                        color: kProdOrderTextGray,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: remainingKg.toStringAsFixed(1),
                                            style: TextStyle(
                                              color: remainingKg > 0
                                                  ? Colors.greenAccent
                                                  : Colors.orangeAccent,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const TextSpan(
                                            text: ' kg',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: kProdOrderPrimaryLight,
                                  size: 20,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
