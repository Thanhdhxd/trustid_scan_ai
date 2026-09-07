import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/supply_repository.dart';

/// Dropdown selector for warehouses, loaded from API via SupplyRepository.
class WarehouseSelector extends ConsumerStatefulWidget {
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final String label;
  final bool showAddButton;

  const WarehouseSelector({
    super.key,
    this.selectedId,
    required this.onChanged,
    this.label = 'Kho lưu trữ',
    this.showAddButton = false,
  });

  @override
  ConsumerState<WarehouseSelector> createState() => _WarehouseSelectorState();
}

class _WarehouseSelectorState extends ConsumerState<WarehouseSelector> {
  List<dynamic> _warehouses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ref.read(supplyRepositoryProvider).getWarehouses();
      if (mounted) {
        final unique = <String, dynamic>{};
        for (final w in list) {
          final id = w['id']?.toString() ?? '';
          if (id.isNotEmpty) unique[id] = w;
        }
        setState(() { _warehouses = unique.values.toList(); _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(color: Color(0xFF00875A), backgroundColor: Color(0xFF16325B)),
      );
    }

    return DropdownButtonFormField<String>(
      value: widget.selectedId != null && _warehouses.any((w) => w['id'] == widget.selectedId)
          ? widget.selectedId
          : null,
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: const Color(0xFF0F2B46),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00875A)),
        ),
      ),
      dropdownColor: const Color(0xFF16325B),
      style: const TextStyle(color: Color(0xFFE8EDF3), fontSize: 15),
      isExpanded: true,
      menuMaxHeight: 300,
      items: _warehouses.map((w) {
        return DropdownMenuItem<String>(
          value: w['id'],
          child: Text(w['name'] ?? 'Kho', overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: widget.onChanged,
    );
  }

  /// Expose loaded warehouses for parent to use
  List<dynamic> get warehouses => _warehouses;
}
