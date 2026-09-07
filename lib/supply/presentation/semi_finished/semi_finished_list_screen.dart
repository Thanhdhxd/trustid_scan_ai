import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/core/widgets/skeleton_loader.dart';
import '../../data/supply_repository.dart';

const Color _kPrimary = Color(0xFF00875A);
const Color _kBg = Color(0xFF0F2B46);
const Color _kSurface = Color(0xFF16325B);
const Color _kText = Color(0xFFE8EDF3);
const Color _kGray = Color(0xFF94A3B8);

class SemiFinishedListScreen extends ConsumerStatefulWidget {
  const SemiFinishedListScreen({super.key});

  @override
  ConsumerState<SemiFinishedListScreen> createState() => _SemiFinishedListScreenState();
}

class _SemiFinishedListScreenState extends ConsumerState<SemiFinishedListScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _batches = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ref.read(supplyRepositoryProvider).getBatches();
      final list = (data is List ? data : [])
          .where((b) {
            final type = (b['batchType'] ?? b['batch_type'] ?? '').toString().toUpperCase();
            final status = (b['status'] ?? '').toString().toUpperCase();
            return type == 'SEMI_FINISHED' && status != 'CANCELLED';
          })
          .map((b) => Map<String, dynamic>.from(b))
          .toList();
      list.sort((a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));
      if (mounted) setState(() { _batches = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _formatKg(double v) => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)} kg';

  String _statusLabel(String? s) {
    switch ((s ?? '').toUpperCase()) {
      case 'COMPLETED': return 'Hoàn thành';
      case 'PENDING': return 'Đang xử lý';
      case 'IN_WAREHOUSE': return 'Trong kho';
      case 'EXPORTED': return 'Đã xuất';
      default: return s ?? '';
    }
  }

  Color _statusColor(String? s) {
    switch ((s ?? '').toUpperCase()) {
      case 'COMPLETED':
      case 'IN_WAREHOUSE': return _kPrimary;
      case 'EXPORTED': return Colors.orange;
      case 'PENDING': return Colors.blue;
      default: return _kGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Bán Thành Phẩm', style: TextStyle(color: _kText, fontWeight: FontWeight.w800)),
        backgroundColor: _kBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kGray),
      ),
      body: Column(
        children: [
          // Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                _ActionBtn(
                  icon: Icons.inventory_2,
                  label: 'Đóng gói',
                  color: _kPrimary,
                  onTap: () async {
                    await context.push('/manager/semi-finished/packaging');
                    _load();
                  },
                ),

                const SizedBox(width: 8),
                _ActionBtn(
                  icon: Icons.upload,
                  label: 'Xuất B2B',
                  color: Colors.orange,
                  onTap: () async {
                    await context.push('/manager/semi-finished/export');
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  icon: Icons.download,
                  label: 'Nhập B2B',
                  color: Colors.blue,
                  onTap: () async {
                    await context.push('/manager/semi-finished/import');
                    _load();
                  },
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const SingleChildScrollView(child: SkeletonListView(count: 6))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _load, child: const Text('Thử lại')),
                          ],
                        ),
                      )
                    : _batches.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.inbox, size: 56, color: _kGray),
                                const SizedBox(height: 12),
                                const Text('Chưa có lô bán thành phẩm', style: TextStyle(color: _kGray, fontSize: 15)),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    await context.push('/manager/semi-finished/packaging');
                                    _load();
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Đóng gói mới'),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: _kPrimary,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: _batches.length,
                              itemBuilder: (_, i) => _buildCard(_batches[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> b) {
    final code = b['batchCode'] ?? b['batch_code'] ?? '';
    final product = b['product'];
    final productName = product?['name'] ?? 'Chưa rõ sản phẩm';
    final status = b['status'] ?? '';
    final available = _num(b['availableQuantity'] ?? b['available_quantity']);
    final input = _num(b['inputWeight'] ?? b['input_weight']);
    final output = _num(b['outputWeight'] ?? b['output_weight']);
    final loss = input > 0 ? ((input - output) / input * 100) : 0.0;
    final packCount = b['packCount'] ?? b['pack_count'] ?? 0;
    final parentBatch = b['parentBatch'] ?? b['parent_batch'];
    final parentCode = parentBatch?['batchCode'] ?? parentBatch?['batch_code'] ?? '';
    final warehouseName = b['warehouse']?['name'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetail(b),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(code, style: const TextStyle(color: _kText, fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(productName, style: const TextStyle(color: _kGray, fontSize: 13)),
              if (parentCode.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('Lô nguồn: $parentCode', style: const TextStyle(color: _kGray, fontSize: 11)),
              ],
              if (warehouseName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('Kho: $warehouseName', style: const TextStyle(color: _kGray, fontSize: 11)),
              ],
              const SizedBox(height: 10),
              // Stats row
              Row(
                children: [
                  _MiniStat(label: 'Tồn', value: _formatKg(available), color: _kPrimary),
                  const SizedBox(width: 12),
                  _MiniStat(label: 'Output', value: _formatKg(output)),
                  const SizedBox(width: 12),
                  _MiniStat(label: 'Hao hụt', value: '${loss.toStringAsFixed(1)}%', color: loss > 5 ? Colors.redAccent : _kGray),
                  const SizedBox(width: 12),
                  _MiniStat(label: 'Bao', value: '$packCount'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> b) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) {
          final code = b['batchCode'] ?? b['batch_code'] ?? '';
          return Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(code, style: const TextStyle(color: _kText, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(b['product']?['name'] ?? '', style: const TextStyle(color: _kGray, fontSize: 14)),
                const SizedBox(height: 16),
                _DetailRow('Trạng thái', _statusLabel(b['status'])),
                _DetailRow('Input', _formatKg(_num(b['inputWeight'] ?? b['input_weight']))),
                _DetailRow('Output', _formatKg(_num(b['outputWeight'] ?? b['output_weight']))),
                _DetailRow('Tồn kho', _formatKg(_num(b['availableQuantity'] ?? b['available_quantity']))),
                _DetailRow('Số bao', '${b['packCount'] ?? b['pack_count'] ?? 0}'),
                Builder(
                  builder: (context) {
                    final pCount = b['packCount'] ?? b['pack_count'] ?? 0;
                    final outW = _num(b['outputWeight'] ?? b['output_weight']);
                    var pkgW = _num(b['packageWeight'] ?? b['package_weight']);
                    if (pkgW == 0 && pCount > 0) pkgW = outW / pCount;
                    return _DetailRow('Quy cách', '${_formatKg(pkgW)}/bao');
                  }
                ),
                if ((b['parentBatch'] ?? b['parent_batch'])?['batchCode'] != null)
                  _DetailRow('Lô nguồn', (b['parentBatch'] ?? b['parent_batch'])['batchCode']),
                if (b['warehouse']?['name'] != null)
                  _DetailRow('Kho', b['warehouse']['name']),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _MiniStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(color: color ?? _kText, fontSize: 13, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: _kGray, fontSize: 10)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: _kGray, fontSize: 13)),
          Text(value, style: const TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
