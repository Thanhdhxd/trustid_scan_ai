import 'package:flutter/material.dart';

const Color kPrimaryColor = Color(0xFF00875A);
const Color kSurfaceDark = Color(0xFF16325B);
const Color kTextLight = Color(0xFFE8EDF3);
const Color kTextGray = Color(0xFF94A3B8);

class MultiSelectDropdown extends StatefulWidget {
  final String? label;
  final String hintText;
  final List<dynamic> items; // Can be a list of maps, objects, or strings
  final List<String> selectedIds; // Currently selected IDs
  final Function(List<String>) onChanged; // Callback when selection changes
  final String Function(dynamic) idMapper; // How to get ID from item
  final String Function(dynamic) titleMapper; // How to get Title from item
  final String Function(dynamic)? subtitleMapper; // How to get Subtitle from item
  final bool hideLabel;

  const MultiSelectDropdown({
    super.key,
    this.label,
    required this.hintText,
    required this.items,
    required this.selectedIds,
    required this.onChanged,
    required this.idMapper,
    required this.titleMapper,
    this.subtitleMapper,
    this.hideLabel = false,
  });

  @override
  State<MultiSelectDropdown> createState() => _MultiSelectDropdownState();
}

class _MultiSelectDropdownState extends State<MultiSelectDropdown> {
  void _openSelectionBottomSheet() {
    // Make a local copy of selections to mutate before saving
    final List<String> localSelectedIds = List.from(widget.selectedIds);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F2B46),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label ?? 'Chọn danh sách', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextLight)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: widget.items.isEmpty
                        ? const Center(child: Text('Không có dữ liệu.', style: TextStyle(color: kTextGray)))
                        : ListView.builder(
                            itemCount: widget.items.length,
                            itemBuilder: (ctx, idx) {
                              final item = widget.items[idx];
                              final id = widget.idMapper(item);
                              final title = widget.titleMapper(item);
                              final subtitle = widget.subtitleMapper?.call(item) ?? '';
                              final isSelected = localSelectedIds.contains(id);

                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (val) {
                                  setSheetState(() {
                                    if (val == true) {
                                      localSelectedIds.add(id);
                                    } else {
                                      localSelectedIds.remove(id);
                                    }
                                  });
                                },
                                title: Text(title, style: const TextStyle(color: kTextLight)),
                                subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(color: kTextGray)) : null,
                                activeColor: kPrimaryColor,
                                checkColor: Colors.white,
                                side: const BorderSide(color: kTextGray),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kTextLight, 
                            side: const BorderSide(color: kTextGray),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Đóng'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            widget.onChanged(localSelectedIds);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor, 
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Xác nhận', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _removeChip(String id) {
    final newList = List<String>.from(widget.selectedIds)..remove(id);
    widget.onChanged(newList);
  }

  @override
  Widget build(BuildContext context) {
    final selectedItems = widget.items.where((e) => widget.selectedIds.contains(widget.idMapper(e))).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null && !widget.hideLabel) ...[
          Text(widget.label!, style: const TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
        ],
        InkWell(
          onTap: _openSelectionBottomSheet,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 48.0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: kSurfaceDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: selectedItems.isEmpty
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.hintText, 
                          style: const TextStyle(color: Colors.white54, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down, color: kTextGray),
                    ],
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedItems.map((item) {
                      final id = widget.idMapper(item);
                      final title = widget.titleMapper(item);
                      return Chip(
                        label: Text(title, style: const TextStyle(color: kPrimaryColor, fontSize: 13, fontWeight: FontWeight.bold)),
                        deleteIcon: const Icon(Icons.close, color: kPrimaryColor, size: 16),
                        onDeleted: () => _removeChip(id),
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: const BorderSide(color: kPrimaryColor),
                        ),
                        padding: const EdgeInsets.all(4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
          ),
        ),
      ],
    );
  }
}
