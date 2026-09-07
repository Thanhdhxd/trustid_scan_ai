import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/material.dart';
import '../../../data/farm_repository.dart';

class MaterialStockDialog extends ConsumerStatefulWidget {
  final FarmMaterial material;
  final bool isImport; // true = Nhập kho, false = Phân bổ
  final VoidCallback onSaved;

  const MaterialStockDialog({super.key, required this.material, required this.isImport, required this.onSaved});

  @override
  ConsumerState<MaterialStockDialog> createState() => _MaterialStockDialogState();
}

class _MaterialStockDialogState extends ConsumerState<MaterialStockDialog> {
  static const Color kPrimaryColor = Color(0xFF00875A);
  static const Color kBackgroundDark = Color(0xFF0F2B46);
  static const Color kSurfaceDark = Color(0xFF16325B);
  static const Color kTextLight = Color(0xFFE8EDF3);
  static const Color kTextGray = Color(0xFF94A3B8);

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountCtrl;
  late TextEditingController _notesCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: '1');
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _adjustAmount(double delta) {
    double current = double.tryParse(_amountCtrl.text) ?? 0;
    current += delta;
    if (current < 0) current = 0;
    _amountCtrl.text = current.toStringAsFixed(current.truncateToDouble() == current ? 0 : 2);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Số lượng phải lớn hơn 0')));
      return;
    }

    if (!widget.isImport && amount > widget.material.stockQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Số lượng phân bổ không được vượt quá tồn kho hiện tại')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final actualAmount = widget.isImport ? amount : -amount;
      await ref.read(farmRepositoryProvider).adjustMaterialStock(widget.material.id, actualAmount, _notesCtrl.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.isImport ? 'Nhập kho thành công' : 'Phân bổ thành công'),
          backgroundColor: kPrimaryColor,
          duration: const Duration(seconds: 2),
        ));
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 450),
        decoration: BoxDecoration(
          color: kBackgroundDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: kSurfaceDark,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
              ),
              child: Row(
                children: [
                  Icon(widget.isImport ? Icons.download : Icons.outbox, color: widget.isImport ? kPrimaryColor : Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.isImport ? 'Nhập kho vật tư' : 'Phân bổ vật tư',
                      style: const TextStyle(color: kTextLight, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: kTextGray, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info Box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.material.name, style: const TextStyle(color: kTextLight, fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(color: kTextGray, fontSize: 14),
                                children: [
                                  TextSpan(text: 'Mã: ${widget.material.code ?? '---'} • Tồn hiện tại: '),
                                  TextSpan(text: '${widget.material.stockQuantity} ${widget.material.unit}', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Input Amount
                      Text(widget.isImport ? 'Số lượng nhập *' : 'Số lượng phân bổ *', style: const TextStyle(color: kTextGray, fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          InkWell(
                            onTap: () => _adjustAmount(-1),
                            child: Container(
                              height: 48, width: 48,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: const Icon(Icons.remove, color: kTextGray),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                border: Border(
                                  top: BorderSide(color: Colors.white.withOpacity(0.1)),
                                  bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                                ),
                              ),
                              child: TextFormField(
                                controller: _amountCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: kTextLight, fontSize: 16, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.only(bottom: 14), // Adjusted to center vertically
                                ),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _adjustAmount(1),
                            child: Container(
                              height: 48, width: 48,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: const Icon(Icons.add, color: kTextGray),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Notes
                      const Text('Ghi chú', style: TextStyle(color: kTextGray, fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 3,
                        style: const TextStyle(color: kTextLight, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Nhập ghi chú...',
                          hintStyle: TextStyle(color: kTextGray.withOpacity(0.5), fontSize: 14),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.2),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kPrimaryColor)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.white.withOpacity(0.1))),
                    ),
                    child: const Text('Hủy', style: TextStyle(color: kTextLight)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Xác nhận', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
