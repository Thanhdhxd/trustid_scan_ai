import 'package:flutter/material.dart';
import '../../data/vietnam_provinces_code.dart';

/// Bottom sheet search selector for provinces, using offline data.
class ProvinceSelector extends StatefulWidget {
  final String? selectedProvinceName;
  final ValueChanged<ProvinceCode> onSelected;
  final String label;

  const ProvinceSelector({
    super.key,
    this.selectedProvinceName,
    required this.onSelected,
    this.label = 'Tỉnh / Thành phố đóng gói',
  });

  @override
  State<ProvinceSelector> createState() => _ProvinceSelectorState();
}

class _ProvinceSelectorState extends State<ProvinceSelector> {
  void _openSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F2B46),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProvinceSearchSheet(
        onSelected: (p) {
          Navigator.pop(context);
          widget.onSelected(p);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _openSearch,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
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
          suffixIcon: const Icon(Icons.arrow_drop_down, color: Color(0xFF94A3B8)),
        ),
        child: Text(
          widget.selectedProvinceName ?? 'Chọn tỉnh...',
          style: TextStyle(
            color: widget.selectedProvinceName != null
                ? const Color(0xFFE8EDF3)
                : const Color(0xFF64748B),
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _ProvinceSearchSheet extends StatefulWidget {
  final ValueChanged<ProvinceCode> onSelected;
  const _ProvinceSearchSheet({required this.onSelected});

  @override
  State<_ProvinceSearchSheet> createState() => _ProvinceSearchSheetState();
}

class _ProvinceSearchSheetState extends State<_ProvinceSearchSheet> {
  String _query = '';

  List<ProvinceCode> get _filtered {
    if (_query.isEmpty) return vietnamProvinceCodes;
    final q = _query.toLowerCase();
    return vietnamProvinceCodes
        .where((p) => p.name.toLowerCase().contains(q) || p.code.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                style: const TextStyle(color: Color(0xFFE8EDF3)),
                decoration: InputDecoration(
                  hintText: 'Tìm tỉnh/thành...',
                  hintStyle: const TextStyle(color: Color(0xFF64748B)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFF16325B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final p = _filtered[i];
                    return ListTile(
                      title: Text(p.name, style: const TextStyle(color: Color(0xFFE8EDF3))),
                      trailing: Text(p.code, style: const TextStyle(color: Color(0xFF00875A), fontWeight: FontWeight.bold)),
                      onTap: () => widget.onSelected(p),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
