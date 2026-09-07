import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/core/widgets/skeleton_loader.dart';
import '../../data/supply_repository.dart';
import '../widgets/qr_scan_input.dart';
import 'package:trustid_scan_ai/scan/scanner_screen.dart';

const Color _kPrimary = Color(0xFF00875A);
const Color _kBg = Color(0xFF0F2B46);
const Color _kSurface = Color(0xFF16325B);
const Color _kText = Color(0xFFE8EDF3);
const Color _kGray = Color(0xFF94A3B8);

class SemiFinishedImportScreen extends ConsumerStatefulWidget {
  const SemiFinishedImportScreen({super.key});
  @override
  ConsumerState<SemiFinishedImportScreen> createState() => _State();
}

class _State extends ConsumerState<SemiFinishedImportScreen> {
  bool _loading = true, _saving = false;
  String? _error;
  List<Map<String, dynamic>> _transfers = [], _warehouses = [], _allTransfers = [];
  String _warehouseId = '';
  final TextEditingController _manualScanCtrl = TextEditingController();

  // Selected transfer
  Map<String, dynamic>? _transfer;
  String _importMode = 'FULL'; // FULL or PARTIAL
  Map<String, double> _receivedQty = {}; // batchId -> received qty

  final _scanFocus = FocusNode();

  @override
  void initState() { super.initState(); _loadData(); }
  @override
  void dispose() { _scanFocus.dispose(); _manualScanCtrl.dispose(); super.dispose(); }

  double _d(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
  String _kg(double v) => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)} kg';

  Future<void> _loadData() async {
    try {
      final repo = ref.read(supplyRepositoryProvider);
      final r = await Future.wait([repo.getTransfers(), repo.getWarehouses()]);
      if (!mounted) return;
      final allTransfers = (r[0] as List).map((t) => Map<String, dynamic>.from(t)).toList();
      _allTransfers = allTransfers;
      // Only show transfers that can be imported (EXPORTED or IMPORTING)
      _transfers = allTransfers.where((t) {
        final s = (t['status'] ?? '').toString().toUpperCase();
        return s == 'EXPORTED' || s == 'IMPORTING' || s == 'PENDING';
      }).toList();
      final whs = (r[1] as List).map((w) => Map<String, dynamic>.from(w)).toList();
      final uniqueWhs = <String, Map<String, dynamic>>{};
      for (final w in whs) {
        final id = w['id']?.toString() ?? '';
        if (id.isNotEmpty) uniqueWhs[id] = w;
      }
      _warehouses = uniqueWhs.values.toList();
      if (_warehouses.isNotEmpty) _warehouseId = _warehouses.firstWhere((w) => w['isDefault'] == true, orElse: () => _warehouses.first)['id'] ?? '';
      setState(() => _loading = false);
    } catch (e) { if (mounted) setState(() { _error = '$e'; _loading = false; }); }
  }

  void _selectTransfer(Map<String, dynamic> t) {
    final items = (t['items'] ?? t['transfer_items'] ?? []) as List;
    final qtyMap = <String, double>{};
    for (final item in items) {
      final bId = item['batchId'] ?? item['batch_id'] ?? '';
      qtyMap[bId] = _d(item['expectedQuantity'] ?? item['expected_quantity']);
    }
    setState(() { _transfer = t; _receivedQty = qtyMap; _importMode = 'FULL'; });
  }

  void _onScanCode(String code) {
    // Try to match by transferCode
    final byCode = _transfers.cast<Map<String, dynamic>?>().firstWhere(
      (t) => (t!['transferCode'] ?? t['transfer_code'] ?? '') == code, orElse: () => null);
    if (byCode != null) { _selectTransfer(byCode); return; }

    // Try to match by scanning a serial inside a transfer
    for (final t in _transfers) {
      final items = (t['items'] ?? t['transfer_items'] ?? []) as List;
      for (final item in items) {
        final serials = item['serials'] as List?;
        if (serials != null && serials.any((s) => s.toString() == code)) {
          _selectTransfer(t);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã tìm phiếu ${t['transferCode'] ?? t['transfer_code'] ?? ''}'), backgroundColor: _kPrimary),
          );
          return;
        }
      }
    }

    setState(() => _error = 'Không tìm thấy phiếu từ mã "$code".');
  }

  List<Map<String, dynamic>> get _transferItems {
    if (_transfer == null) return [];
    return (((_transfer!['items'] ?? _transfer!['transfer_items']) as List?) ?? [])
        .map((i) => Map<String, dynamic>.from(i)).toList();
  }

  Future<void> _submit() async {
    if (_transfer == null) return setState(() => _error = 'Chọn phiếu nhập.');
    if (_warehouseId.isEmpty) return setState(() => _error = 'Chọn kho nhập.');
    setState(() { _saving = true; _error = null; });
    try {
      final repo = ref.read(supplyRepositoryProvider);
      await repo.confirmTransferImport({
        'transfer_id': _transfer!['id'],
        'import_mode': _importMode,
        'target_warehouse_id': _warehouseId,
        if (_importMode == 'PARTIAL')
          'received_items': _receivedQty.entries.map((e) => {'batch_id': e.key, 'received_quantity': e.value}).toList(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nhập kho thành công!'), backgroundColor: _kPrimary));
        context.pop();
      }
    } catch (e) { setState(() => _error = '$e'); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  InputDecoration _deco(String? h) => InputDecoration(hintText: h, hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
    filled: true, fillColor: _kBg, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white10)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white10)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kPrimary)));

  Widget _card(List<Widget> c) => Container(width: double.infinity, padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: c));

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(color: _kGray, fontSize: 12, fontWeight: FontWeight.w700)));

  Future<void> _showCameraScanner() async {
    final String? result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const ScannerScreen(
          title: 'Quét phiếu nhập',
          returnCode: true,
        ),
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      _onScanCode(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: _kBg,
      appBar: AppBar(title: const Text('Nhập kho bán thành phẩm', style: TextStyle(color: _kText, fontWeight: FontWeight.w800, fontSize: 17)), backgroundColor: _kBg, elevation: 0, iconTheme: const IconThemeData(color: _kGray)),
      body: _loading ? const SkeletonForm() :
        SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(bottom: 16), child: Text('Nạp phiếu xuất B2B rồi xác nhận nhập kho.', style: TextStyle(color: _kGray, fontSize: 13))),
          if (_error != null) Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3))),
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),

          // Step 1: Scan to load transfer
          _card([_label('Nạp phiếu'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualScanCtrl,
                    style: const TextStyle(color: _kText, fontSize: 14),
                    decoration: _deco('Nhập mã phiếu hoặc serial bao'),
                    onSubmitted: (v) { _onScanCode(v.trim()); _manualScanCtrl.clear(); },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () { _onScanCode(_manualScanCtrl.text.trim()); _manualScanCtrl.clear(); },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kPrimary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Nạp', style: TextStyle(color: _kPrimary, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12), _label('Hoặc chọn phiếu đang chờ'),
            DropdownButtonFormField<String>(value: (_transfer != null && _transfers.any((t) => t['id'] == _transfer!['id'])) ? _transfer!['id'] : null, decoration: _deco('Chọn phiếu'), dropdownColor: _kSurface,
              style: const TextStyle(color: _kText, fontSize: 14), isExpanded: true, menuMaxHeight: 300,
              items: (() {
                final unique = <String, Map<String, dynamic>>{};
                for (final t in _transfers) {
                  final id = t['id']?.toString() ?? '';
                  if (id.isNotEmpty) unique[id] = t;
                }
                return unique.values.map((t) => DropdownMenuItem(value: t['id'] as String,
                  child: Text('${t['transferCode'] ?? t['transfer_code'] ?? t['id'].toString().substring(0, 8)} - ${t['status']}', overflow: TextOverflow.ellipsis))).toList();
              })(),
              onChanged: (v) { if (v != null) _selectTransfer(_transfers.firstWhere((t) => t['id'] == v)); })]),

          _card([_label('Kho nhập về'),
            DropdownButtonFormField<String>(value: (_warehouseId.isNotEmpty && _warehouses.any((w) => w['id'] == _warehouseId)) ? _warehouseId : null, decoration: _deco(null), dropdownColor: _kSurface,
              style: const TextStyle(color: _kText, fontSize: 14), isExpanded: true,
              items: _warehouses.map((w) => DropdownMenuItem(value: w['id'] as String, child: Text(w['name'] ?? ''))).toList(),
              onChanged: (v) => setState(() => _warehouseId = v ?? '')),
          ]),

          if (_transfer == null) ...[
            _card([
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Phiếu đang chờ nhập', style: TextStyle(color: _kGray, fontSize: 14, fontWeight: FontWeight.bold)),
                  const Icon(Icons.settings, color: _kGray, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Builder(builder: (context) {
                final pending = _transfers.where((t) => t['status'] != 'COMPLETED').toList();
                if (pending.isEmpty) return const Text('Không có phiếu đang chờ.', style: TextStyle(color: _kGray, fontSize: 13));
                return Column(children: pending.map((t) => _buildTransferItem(t)).toList());
              }),
            ]),
            _card([
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Đã nhập gần đây', style: TextStyle(color: _kGray, fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              Builder(builder: (context) {
                final completed = _allTransfers.where((t) => t['status'] == 'COMPLETED').take(5).toList();
                if (completed.isEmpty) return const Text('Chưa có lịch sử.', style: TextStyle(color: _kGray, fontSize: 13));
                return Column(children: completed.map((t) => _buildTransferItem(t)).toList());
              }),
            ]),
          ] else ...[

            _card([_label('2. Thông tin phiếu'),
              _infoRow('Mã phiếu', _transfer!['transferCode'] ?? _transfer!['transfer_code'] ?? ''),
              _infoRow('Trạng thái', _transfer!['status'] ?? ''),
              _infoRow('Đơn vị xuất', _transfer!['fromTenant']?['name'] ?? _transfer!['from_tenant_name'] ?? '--'),
              if (_transfer!['createdAt'] != null) _infoRow('Ngày tạo', _transfer!['createdAt'].toString().substring(0, 10)),
              const SizedBox(height: 12), _label('Chế độ nhập'),
              Row(children: [
                _radioBtn('Toàn bộ', _importMode == 'FULL', () => setState(() => _importMode = 'FULL')),
                const SizedBox(width: 12),
                _radioBtn('Một phần', _importMode == 'PARTIAL', () => setState(() => _importMode = 'PARTIAL')),
              ]),
            ]),

            // Step 3: Items
            _card([_label('3. Kiểm đếm hàng hóa'),
              ..._transferItems.map((item) {
                final bId = item['batchId'] ?? item['batch_id'] ?? '';
                final expected = _d(item['expectedQuantity'] ?? item['expected_quantity']);
                final received = _receivedQty[bId] ?? expected;
                final batchCode = item['batch']?['batchCode'] ?? item['batch']?['batch_code'] ?? bId.toString().substring(0, 8);
                return Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(batchCode, style: const TextStyle(color: _kText, fontWeight: FontWeight.w800, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('Xuất: ${_kg(expected)}', style: const TextStyle(color: _kGray, fontSize: 12)),
                    ])),
                    SizedBox(width: 100, child: _importMode == 'PARTIAL'
                      ? TextField(
                          controller: TextEditingController(text: received.toString()),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: _kText, fontSize: 14),
                          decoration: _deco(null),
                          onChanged: (v) => _receivedQty[bId] = double.tryParse(v) ?? 0,
                        )
                      : Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(8)),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(_kg(expected), style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 4), const Icon(Icons.check_circle, color: _kPrimary, size: 16)]))),
                  ]));
              }),
            ]),
          ],
        ])),
      bottomNavigationBar: _loading ? null : Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
        decoration: BoxDecoration(color: _kBg, border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08)))),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kText,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Quay lại', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _showCameraScanner,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner, size: 20),
                      SizedBox(height: 2),
                      Text('Quét phiếu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : () {
                    if (_transfer == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn/quét phiếu nhập trước', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
                    } else {
                      _submit();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Lưu lại', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.2)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: _kGray, fontSize: 13)),
      Text(value, style: const TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.w700))]));

  Widget _radioBtn(String label, bool selected, VoidCallback onTap) => GestureDetector(onTap: onTap,
    child: Row(children: [
      Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? _kPrimary : _kGray, size: 20),
      const SizedBox(width: 6), Text(label, style: TextStyle(color: selected ? _kText : _kGray, fontSize: 13, fontWeight: FontWeight.w600))]));

  Widget _buildTransferItem(Map<String, dynamic> t) {
    String dateStr = '';
    if (t['createdAt'] != null) {
      try {
        final d = DateTime.parse(t['createdAt'].toString()).toLocal();
        dateStr = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t['transferCode'] ?? t['transfer_code'] ?? t['id'].toString().substring(0, 8), style: const TextStyle(color: _kText, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 4),
          Text('${t['status']} - $dateStr', style: const TextStyle(color: _kGray, fontSize: 11)),
        ],
      ),
    );
  }
}
