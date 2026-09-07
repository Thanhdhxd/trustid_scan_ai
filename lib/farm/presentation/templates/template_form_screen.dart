import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/core/theme/app_colors.dart';
import '../../data/farm_repository.dart';
import '../../domain/template.dart';
import '../../domain/material.dart';

const Color kPrimaryColor = Color(0xFF00875A);
const Color kBackgroundDark = Color(0xFF0F2B46);
const Color kSurfaceDark = Color(0xFF16325B);
const Color kTextLight = Color(0xFFE8EDF3);
const Color kTextGray = Color(0xFF94A3B8);

class TemplateFormScreen extends ConsumerStatefulWidget {
  final ProcessTemplate? template;
  const TemplateFormScreen({super.key, this.template});

  @override
  ConsumerState<TemplateFormScreen> createState() => _TemplateFormScreenState();
}

class _StageGroup {
  String name;
  List<ProcessTaskConfig> tasks;
  _StageGroup(this.name, this.tasks);
}

class _TemplateFormScreenState extends ConsumerState<TemplateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  List<_StageGroup> _stages = [];
  List<FarmMaterial> _materials = [];
  bool _isLoading = false;

  final List<String> _jobTypes = [
    'Làm đất',
    'Xuống giống',
    'Bón phân',
    'Tưới nước',
    'Phun thuốc',
    'Chăm sóc',
    'Thu hoạch',
    'Khác'
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.template?.name ?? '');
    _loadMaterials();

    if (widget.template != null && widget.template!.tasksConfig.isNotEmpty) {
      final stageNames = widget.template!.tasksConfig.map((e) => e.stage).toSet();
      for (var sName in stageNames) {
        final tasks = widget.template!.tasksConfig.where((e) => e.stage == sName).toList();
        _stages.add(_StageGroup(sName, tasks));
      }
    } else {
      _stages.add(_StageGroup('', [_emptyTask()]));
    }
  }

  ProcessTaskConfig _emptyTask() {
    return ProcessTaskConfig(
      stage: '',
      dayOffset: 0,
      title: '',
      isMandatory: false,
      jobType: 'Chăm sóc',
      materialIds: [],
    );
  }

  Future<void> _loadMaterials() async {
    try {
      final repo = ref.read(farmRepositoryProvider);
      final list = await repo.getMaterials();
      setState(() {
        _materials = list;
      });
    } catch (e) {
      debugPrint('Lỗi tải vật tư: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_stages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng thêm ít nhất 1 giai đoạn')));
      return;
    }

    // Form validator handles empty fields now

    setState(() => _isLoading = true);
    
    // Flatten
    final List<ProcessTaskConfig> flatTasks = [];
    for (var s in _stages) {
      for (var t in s.tasks) {
        flatTasks.add(ProcessTaskConfig(
          stage: s.name,
          dayOffset: t.dayOffset,
          title: t.title,
          description: t.description,
          isMandatory: t.isMandatory,
          jobType: t.jobType,
          materialIds: t.materialIds,
          suggestedMaterials: _materials.where((m) => t.materialIds.contains(m.id)).map((e) => e.name).toList(),
        ));
      }
    }

    try {
      final repo = ref.read(farmRepositoryProvider);
      final payload = {
        'name': _nameCtrl.text,
        'tasks_config': flatTasks.map((e) => e.toJson()).toList(),
      };

      if (widget.template == null) {
        await repo.createTemplate(payload);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo quy trình thành công'), backgroundColor: kPrimaryColor));
      } else {
        await repo.updateTemplate(widget.template!.id, payload);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật quy trình thành công'), backgroundColor: kPrimaryColor));
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMaterialPicker(ProcessTaskConfig task, VoidCallback onUpdate) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, controller) {
                return Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Chọn vật tư gợi ý', style: TextStyle(color: kTextLight, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: controller,
                        itemCount: _materials.length,
                        itemBuilder: (ctx, i) {
                          final m = _materials[i];
                          final isSelected = task.materialIds.contains(m.id);
                          return CheckboxListTile(
                            activeColor: kPrimaryColor,
                            checkColor: Colors.white,
                            title: Text(m.name, style: const TextStyle(color: kTextLight)),
                            subtitle: Text(m.unit, style: const TextStyle(color: kTextGray, fontSize: 12)),
                            value: isSelected,
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  task.materialIds.add(m.id);
                                } else {
                                  task.materialIds.remove(m.id);
                                }
                              });
                              onUpdate(); // Update parent state
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Xong', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRequiredLabel(String text, {double fontSize = 13}) {
    return RichText(
      text: TextSpan(
        text: '* ',
        style: TextStyle(color: Colors.red, fontSize: fontSize, fontWeight: FontWeight.w500),
        children: [
          TextSpan(text: text, style: TextStyle(color: kTextGray, fontSize: fontSize, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      appBar: AppBar(
        title: Text(widget.template == null ? 'Tạo quy trình' : 'Cập nhật quy trình', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kTextLight)),
        backgroundColor: kBackgroundDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextLight),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2))
                : const Text('Lưu', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildRequiredLabel('Tên quy trình'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              style: const TextStyle(color: kTextLight),
              decoration: InputDecoration(
                hintText: 'VD: Quy trình lúa Đông Xuân',
                hintStyle: const TextStyle(color: kTextGray),
                filled: true,
                fillColor: kSurfaceDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập tên' : null,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Các giai đoạn canh tác', style: TextStyle(color: kTextLight, fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _stages.add(_StageGroup('', [_emptyTask()])));
                  },
                  icon: const Icon(Icons.add, color: kPrimaryColor, size: 18),
                  label: const Text('Thêm GĐ', style: TextStyle(color: kPrimaryColor)),
                )
              ],
            ),
            const SizedBox(height: 8),
            
            ..._stages.asMap().entries.map((stageEntry) {
              final sIdx = stageEntry.key;
              final stage = stageEntry.value;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: stage.name,
                            onChanged: (v) => stage.name = v,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập tên giai đoạn' : null,
                            style: const TextStyle(color: kTextLight, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              label: _buildRequiredLabel('Tên giai đoạn'),
                              hintText: 'VD: Giai đoạn 1: Làm đất (0-7 ngày)',
                              hintStyle: TextStyle(color: kTextGray.withOpacity(0.5)),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.2),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                          onPressed: () => setState(() => _stages.removeAt(sIdx)),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    ...stage.tasks.asMap().entries.map((taskEntry) {
                      final tIdx = taskEntry.key;
                      final task = taskEntry.value;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12, left: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kSurfaceDark,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Ngày offset', style: TextStyle(color: kTextGray, fontSize: 11)),
                                      const SizedBox(height: 4),
                                      TextFormField(
                                        initialValue: task.dayOffset.toString(),
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(color: kTextLight, fontSize: 14),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          filled: true,
                                          fillColor: Colors.black.withOpacity(0.2),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                                        ),
                                        onChanged: (v) => _stages[sIdx].tasks[tIdx] = ProcessTaskConfig(
                                          stage: task.stage, dayOffset: int.tryParse(v) ?? 0, title: task.title, description: task.description, isMandatory: task.isMandatory, jobType: task.jobType, materialIds: task.materialIds,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildRequiredLabel('Loại công việc', fontSize: 11),
                                      const SizedBox(height: 4),
                                      Container(
                                        height: 36,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _jobTypes.contains(task.jobType) ? task.jobType : 'Khác',
                                            dropdownColor: kSurfaceDark,
                                            isExpanded: true,
                                            icon: const Icon(Icons.arrow_drop_down, color: kTextGray),
                                            style: const TextStyle(color: kTextLight, fontSize: 13),
                                            items: _jobTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                            onChanged: (v) {
                                              if (v != null) {
                                                setState(() {
                                                  _stages[sIdx].tasks[tIdx] = ProcessTaskConfig(
                                                    stage: task.stage, dayOffset: task.dayOffset, title: task.title, description: task.description, isMandatory: task.isMandatory, jobType: v, materialIds: task.materialIds,
                                                  );
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.close, color: kTextGray, size: 18),
                                  onPressed: () => setState(() => _stages[sIdx].tasks.removeAt(tIdx)),
                                )
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              initialValue: task.title,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập tên công việc' : null,
                              style: const TextStyle(color: kTextLight, fontSize: 14),
                              decoration: InputDecoration(
                                label: _buildRequiredLabel('Tên công việc (Chi tiết)'),
                                isDense: true,
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.2),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                              ),
                              onChanged: (v) => _stages[sIdx].tasks[tIdx] = ProcessTaskConfig(
                                stage: task.stage, dayOffset: task.dayOffset, title: v, description: task.description, isMandatory: task.isMandatory, jobType: task.jobType, materialIds: task.materialIds,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              initialValue: task.description ?? '',
                              style: const TextStyle(color: kTextLight, fontSize: 14),
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Mô tả chi tiết...',
                                labelStyle: const TextStyle(color: kTextGray, fontSize: 13),
                                isDense: true,
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.2),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                              ),
                              onChanged: (v) => _stages[sIdx].tasks[tIdx] = ProcessTaskConfig(
                                stage: task.stage, dayOffset: task.dayOffset, title: task.title, description: v, isMandatory: task.isMandatory, jobType: task.jobType, materialIds: task.materialIds,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _showMaterialPicker(task, () => setState((){})),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        task.materialIds.isEmpty ? 'Chọn vật tư gợi ý...' : '${task.materialIds.length} vật tư được chọn',
                                        style: TextStyle(color: task.materialIds.isEmpty ? kTextGray : kPrimaryColor, fontSize: 13),
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down, color: kTextGray),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: task.isMandatory,
                                    activeColor: kPrimaryColor,
                                    onChanged: (v) {
                                      setState(() {
                                        _stages[sIdx].tasks[tIdx] = ProcessTaskConfig(
                                          stage: task.stage, dayOffset: task.dayOffset, title: task.title, description: task.description, isMandatory: v ?? false, jobType: task.jobType, materialIds: task.materialIds,
                                        );
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text('Bắt buộc thực hiện', style: TextStyle(color: kTextGray, fontSize: 13)),
                              ],
                            )
                          ],
                        ),
                      );
                    }).toList(),
                    
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() => _stages[sIdx].tasks.add(_emptyTask()));
                        },
                        icon: const Icon(Icons.add, size: 16, color: kTextGray),
                        label: const Text('Thêm công việc', style: TextStyle(color: kTextGray)),
                      ),
                    )
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
