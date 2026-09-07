import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/theme/app_colors.dart';
import '../../../data/farm_repository.dart';
import '../../../domain/crop_cycle.dart';

class HarvestModal extends ConsumerStatefulWidget {
  final CropCycle cycle;
  final VoidCallback onSaved;

  const HarvestModal({super.key, required this.cycle, required this.onSaved});

  @override
  ConsumerState<HarvestModal> createState() => _HarvestModalState();
}

class _HarvestModalState extends ConsumerState<HarvestModal> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(farmRepositoryProvider);
      await repo.createHarvest(
        cropCycleId: widget.cycle.id,
        quantityKg: double.parse(_quantityController.text.trim()),
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo lô thu hoạch thành công!')));
        widget.onSaved();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kBackgroundDark,
      title: const Text('Thu hoạch Vụ mùa', style: TextStyle(color: kTextLight)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vụ mùa: ${widget.cycle.name}', style: const TextStyle(color: kTextGray)),
            const SizedBox(height: 16),
            const Text('Sản lượng thu hoạch (kg) *', style: TextStyle(color: kTextGray, fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: kTextLight),
              decoration: InputDecoration(
                filled: true,
                fillColor: kSurfaceDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                hintText: 'VD: 1000',
                hintStyle: const TextStyle(color: kTextGray),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Nhập sản lượng';
                if (double.tryParse(v) == null) return 'Sản lượng không hợp lệ';
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text('Ghi chú (Tùy chọn)', style: TextStyle(color: kTextGray, fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              style: const TextStyle(color: kTextLight),
              maxLines: 2,
              decoration: InputDecoration(
                filled: true,
                fillColor: kSurfaceDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                hintText: 'Nhập ghi chú...',
                hintStyle: const TextStyle(color: kTextGray),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy', style: TextStyle(color: kTextGray)),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
          child: _isSubmitting 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Thu hoạch', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
