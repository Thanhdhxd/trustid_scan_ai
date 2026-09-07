import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/core/widgets/skeleton_loader.dart';
import '../../data/supply_repository.dart';
import 'package:trustid_scan_ai/scan/scanner_screen.dart';

const Color _kPrimary = Color(0xFF00875A);
const Color _kBg = Color(0xFF0F2B46);
const Color _kSurface = Color(0xFF16325B);
const Color _kText = Color(0xFFE8EDF3);
const Color _kGray = Color(0xFF94A3B8);

class SemiFinishedExportScreen extends ConsumerStatefulWidget {
  const SemiFinishedExportScreen({super.key});
  @override
  ConsumerState<SemiFinishedExportScreen> createState() => _State();
}

class _State extends ConsumerState<SemiFinishedExportScreen> {
  bool _loading = true, _saving = false, _lookingUp = false;
  String? _error, _successCode;
  List<Map<String, dynamic>> _batches = [], _warehouses = [];
  String _warehouseId = '', _scanMode = 'BATCH', _notes = '';
  final _taxCtrl = TextEditingController();
  final _scanCtrl = TextEditingController();
  Map<String, dynamic>? _tenant;
  List<Map<String, dynamic>> _items = [];

  List<Map<String, dynamic>> _partners = [];
  String? _selectedPartnerId;

  // Add Partner Dialog state
  final _searchPartnerCtrl = TextEditingController();
  List<Map<String, dynamic>> _partnerSearchResults = [];
  bool _searchingPartner = false;
  Map<String, dynamic>? _selectedSearchResult;
  Timer? _partnerSearchDebounce;

  @override
  void initState() { super.initState(); _loadData(); }
  @override
  void dispose() { 
    _taxCtrl.dispose(); 
    _scanCtrl.dispose(); 
    _searchPartnerCtrl.dispose();
    _partnerSearchDebounce?.cancel();
    super.dispose(); 
  }

  double _d(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
  String _kg(double v) => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)} kg';
  bool _isAvail(dynamic b) {
    if (b is! Map) return false;
    final m = b;
    return (m['batchType'] ?? m['batch_type'] ?? '').toString().toUpperCase() == 'SEMI_FINISHED' &&
        m['status'] == 'COMPLETED' && _d(m['availableQuantity'] ?? m['available_quantity']) > 0.001;
  }

  Future<void> _loadData() async {
    try {
      final repo = ref.read(supplyRepositoryProvider);
      final r = await Future.wait([
        repo.getBatches(),
        repo.getWarehouses(),
        repo.getB2BPartners(),
      ]);
      if (!mounted) return;
      _batches = (r[0] as List).where(_isAvail).map((b) => Map<String, dynamic>.from(b)).toList();
      final whs = (r[1] as List).map((w) => Map<String, dynamic>.from(w)).toList();
      _partners = (r[2] as List).map((p) => Map<String, dynamic>.from(p)).toList();

      final uniqueWhs = <String, Map<String, dynamic>>{};
      for (final w in whs) {
        final id = w['id']?.toString() ?? '';
        if (id.isNotEmpty) uniqueWhs[id] = w;
      }
      _warehouses = uniqueWhs.values.toList();
      if (_warehouses.isNotEmpty) _warehouseId = _warehouses.firstWhere((w) => w['isDefault'] == true, orElse: () => _warehouses.first)['id'] ?? '';

      if (_partners.isNotEmpty) {
        _selectedPartnerId = _partners.first['id']?.toString();
        _tenant = _partners.first['partnerTenant'];
      }

      setState(() => _loading = false);
    } catch (e) { if (mounted) setState(() { _error = '$e'; _loading = false; }); }
  }

  Map<String, dynamic>? _findBatch(String id) =>
      _batches.cast<Map<String, dynamic>?>().firstWhere((b) => b!['id'] == id, orElse: () => null);

  Future<void> _saveB2BPartner(String partnerTenantId) async {
    setState(() => _lookingUp = true);
    try {
      final repo = ref.read(supplyRepositoryProvider);
      await repo.createB2BPartner({'partnerTenantId': partnerTenantId});
      final freshPartners = await repo.getB2BPartners();
      setState(() {
        _partners = freshPartners.map((p) => Map<String, dynamic>.from(p)).toList();
        final newlyAdded = _partners.firstWhere(
          (p) => p['partnerTenantId'] == partnerTenantId,
          orElse: () => _partners.last,
        );
        _selectedPartnerId = newlyAdded['id']?.toString();
        _tenant = newlyAdded['partnerTenant'];
        _lookingUp = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu đối tác B2B thành công!'), backgroundColor: _kPrimary));
      }
    } catch (e) {
      setState(() {
        _error = 'Lỗi lưu đối tác: $e';
        _lookingUp = false;
      });
    }
  }

  Future<void> _deleteB2BPartner(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _kSurface,
        title: const Text('Xác nhận xóa', style: TextStyle(color: Colors.white)),
        content: const Text('Xóa đối tác này khỏi danh sách?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final repo = ref.read(supplyRepositoryProvider);
      await repo.removeB2BPartner(id);
      final freshPartners = await repo.getB2BPartners();
      setState(() {
        _partners = freshPartners.map((p) => Map<String, dynamic>.from(p)).toList();
        if (_selectedPartnerId == id) {
          _selectedPartnerId = _partners.isNotEmpty ? _partners.first['id']?.toString() : null;
          _tenant = _partners.isNotEmpty ? _partners.first['partnerTenant'] : null;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa đối tác khỏi danh sách.'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      setState(() => _error = 'Lỗi xóa đối tác: $e');
    }
  }

  void _openAddPartnerDialog() {
    _searchPartnerCtrl.clear();
    _partnerSearchResults = [];
    _selectedSearchResult = null;
    _searchingPartner = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: _kSurface,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Thêm đối tác B2B', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: _kGray),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchPartnerCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: _deco('Tên hoặc MST đối tác...').copyWith(
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search, color: _kPrimary),
                          onPressed: () async {
                            final q = _searchPartnerCtrl.text.trim();
                            if (q.length < 3) return;
                            setModalState(() => _searchingPartner = true);
                            try {
                              final results = await ref.read(supplyRepositoryProvider).searchActiveTenants(q);
                              setModalState(() {
                                _partnerSearchResults = results.map((r) => Map<String, dynamic>.from(r)).toList();
                                _searchingPartner = false;
                              });
                            } catch (e) {
                              setModalState(() => _searchingPartner = false);
                            }
                          },
                        ),
                      ),
                      onChanged: (val) {
                        if (_partnerSearchDebounce?.isActive ?? false) _partnerSearchDebounce!.cancel();
                        _partnerSearchDebounce = Timer(const Duration(milliseconds: 500), () async {
                          final q = val.trim();
                          if (q.length < 3) {
                            setModalState(() {
                              _partnerSearchResults = [];
                            });
                            return;
                          }
                          setModalState(() => _searchingPartner = true);
                          try {
                            final results = await ref.read(supplyRepositoryProvider).searchActiveTenants(q);
                            setModalState(() {
                              _partnerSearchResults = results.map((r) => Map<String, dynamic>.from(r)).toList();
                              _searchingPartner = false;
                            });
                          } catch (e) {
                            setModalState(() => _searchingPartner = false);
                          }
                        });
                      },
                      onSubmitted: (q) async {
                        if (q.trim().length < 3) return;
                        setModalState(() => _searchingPartner = true);
                        try {
                          final results = await ref.read(supplyRepositoryProvider).searchActiveTenants(q.trim());
                          setModalState(() {
                            _partnerSearchResults = results.map((r) => Map<String, dynamic>.from(r)).toList();
                            _searchingPartner = false;
                          });
                        } catch (e) {
                          setModalState(() => _searchingPartner = false);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_searchingPartner)
                      const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: _kPrimary)))
                    else if (_partnerSearchResults.isNotEmpty)
                      Flexible(
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(8)),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _partnerSearchResults.length,
                            separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                            itemBuilder: (context, index) {
                              final r = _partnerSearchResults[index];
                              final isSelected = _selectedSearchResult?['id'] == r['id'];
                              return ListTile(
                                dense: true,
                                title: Text(r['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Text('MST: ${r['taxCode'] ?? ''}', style: const TextStyle(color: _kGray)),
                                trailing: isSelected ? const Icon(Icons.check_circle, color: _kPrimary) : null,
                                onTap: () {
                                  setModalState(() {
                                    _selectedSearchResult = r;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      )
                    else if (_searchPartnerCtrl.text.trim().length >= 3)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Không tìm thấy doanh nghiệp phù hợp', style: TextStyle(color: _kGray, fontSize: 13)),
                      ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: _selectedSearchResult == null
                      ? null
                      : () async {
                          final partnerId = _selectedSearchResult!['id']?.toString() ?? '';
                          if (partnerId.isEmpty) return;
                          Navigator.pop(context);
                          await _saveB2BPartner(partnerId);
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
                  child: const Text('Lưu đối tác', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _onScan(String code) async {
    setState(() => _error = null);
    if (code.isEmpty) return;

    if (_scanMode == 'PALLET') {
      try {
        final repo = ref.read(supplyRepositoryProvider);
        final list = await repo.getSFPallets(search: code);
        final pallet = list.firstWhere(
          (p) => (p['palletCode'] ?? p['pallet_code'] ?? '').toString().toUpperCase() == code.toUpperCase(),
          orElse: () => null,
        );
        if (pallet == null) {
          setState(() => _error = 'Không tìm thấy pallet BTP "$code"');
          return;
        }
        final detail = await repo.getSFPalletDetail(pallet['id'].toString());
        final pItems = detail['items'] as List?;
        if (pItems == null || pItems.isEmpty) {
          setState(() => _error = 'Pallet này đang trống');
          return;
        }

        int addedCount = 0;
        for (final itemVal in pItems) {
          final palletItem = Map<String, dynamic>.from(itemVal);
          final bId = palletItem['batchId'] ?? palletItem['batch_id'] ?? '';
          if (bId.toString().isEmpty) continue;
          final batch = _findBatch(bId.toString());
          if (batch == null) continue;

          final serial = palletItem['itemSerial'] ?? '';
          final pc = (batch['packCount'] ?? batch['pack_count'] ?? 1) as int;
          final tw = _d(batch['outputWeight'] ?? batch['output_weight'] ?? batch['totalQuantity']);
          final pw = pc > 0 ? tw / pc : tw;
          
          final ex = _items.cast<Map<String, dynamic>?>().firstWhere((i) => i!['batch_id'] == batch['id'] && i['serials'] != null, orElse: () => null);
          setState(() {
            if (ex != null) {
              final s = List<String>.from(ex['serials'] ?? []);
              if (!s.contains(serial)) {
                s.add(serial);
                ex['serials'] = s;
                ex['expected_quantity'] = (s.length * pw);
                addedCount++;
              }
            } else {
              _items.add({
                'batch_id': batch['id'],
                'expected_quantity': pw,
                'batch_code': batch['batchCode'] ?? batch['batch_code'],
                'serials': [serial]
              });
              addedCount++;
            }
          });
        }
        if (addedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã thêm $addedCount SP từ pallet ${pallet['palletCode'] ?? code}'), backgroundColor: _kPrimary));
        } else {
          setState(() => _error = 'Không có sản phẩm hợp lệ trong pallet (hết tồn hoặc lô chưa complete).');
        }
      } catch (e) {
        setState(() => _error = '$e');
      }
      return;
    }

    try {
      final r = await ref.read(supplyRepositoryProvider).lookupSerials([code]);
      if (r.isEmpty) { setState(() => _error = 'Không tìm thấy mã.'); return; }
      final item = Map<String, dynamic>.from(r.first);
      final bId = item['batchId'] ?? item['batch_id'] ?? '';
      final batch = _findBatch(bId);
      if (batch == null) { setState(() => _error = 'Lô không khả dụng.'); return; }
      _scanMode == 'BATCH' ? _addBatch(batch) : _addItem(batch, item);
    } catch (e) { setState(() => _error = '$e'); }
  }

  void _addBatch(Map<String, dynamic> b) {
    if (_items.any((i) => i['batch_id'] == b['id'])) { setState(() => _error = 'Lô đã có.'); return; }
    setState(() => _items.add({'batch_id': b['id'], 'expected_quantity': _d(b['availableQuantity'] ?? b['available_quantity']), 'batch_code': b['batchCode'] ?? b['batch_code']}));
  }

  void _addItem(Map<String, dynamic> b, Map<String, dynamic> si) {
    final serial = si['serialNumber'] ?? '';
    final pc = (b['packCount'] ?? b['pack_count'] ?? 1) as int;
    final tw = _d(b['outputWeight'] ?? b['output_weight'] ?? b['totalQuantity']);
    final pw = pc > 0 ? tw / pc : tw;
    final ex = _items.cast<Map<String, dynamic>?>().firstWhere((i) => i!['batch_id'] == b['id'] && i['serials'] != null, orElse: () => null);
    setState(() {
      if (ex != null) {
        final s = List<String>.from(ex['serials'] ?? []);
        if (s.contains(serial)) { _error = 'Bao đã có.'; return; }
        s.add(serial); ex['serials'] = s; ex['expected_quantity'] = (s.length * pw);
      } else {
        _items.add({'batch_id': b['id'], 'expected_quantity': pw, 'batch_code': b['batchCode'] ?? b['batch_code'], 'serials': [serial]});
      }
    });
  }

  double get _totalW => _items.fold(0.0, (s, i) => s + _d(i['expected_quantity']));

  Future<void> _submit() async {
    if (_tenant == null) return setState(() => _error = 'Chọn đối tác.');
    if (_warehouseId.isEmpty) return setState(() => _error = 'Chọn kho xuất.');
    if (_items.isEmpty) return setState(() => _error = 'Thêm ít nhất 1 lô.');
    setState(() { _saving = true; _error = null; });
    try {
      final repo = ref.read(supplyRepositoryProvider);
      final t = await repo.createTransfer({
        'to_tenant_id': _tenant!['id'],
        'notes': _notes,
        'status': 'PENDING',
        'items': _items.map((i) => {
          'batch_id': i['batch_id'],
          'expected_quantity': i['expected_quantity'],
          if (i['serials'] != null) 'serials': i['serials'],
        }).toList()
      });
      final c = await repo.confirmTransferExport(t['id'], _warehouseId);
      setState(() { _successCode = c['transferCode'] ?? t['transferCode'] ?? t['id']; _items = []; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xuất kho'), backgroundColor: _kPrimary));
    } catch (e) { setState(() => _error = '$e'); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  InputDecoration _deco(String? h) => InputDecoration(hintText: h, hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
    filled: true, fillColor: _kBg, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white10)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white10)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kPrimary)));

  Widget _card(List<Widget> c) => Container(width: double.infinity, padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.06))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: c));

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(color: _kGray, fontSize: 12, fontWeight: FontWeight.w700)));

  Future<void> _showCameraScanner() async {
    final String? result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const ScannerScreen(
          title: 'Quét xuất kho',
          returnCode: true,
        ),
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      _onScan(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: _kBg,
      appBar: AppBar(title: const Text('Xuất kho bán thành phẩm', style: TextStyle(color: _kText, fontWeight: FontWeight.w800, fontSize: 17)), backgroundColor: _kBg, elevation: 0, iconTheme: const IconThemeData(color: _kGray)),
      body: _loading ? const SkeletonForm() :
        SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(bottom: 16), child: Text('Quét nguyên lô hoặc từng bao để lập phiếu B2B.', style: TextStyle(color: _kGray, fontSize: 13))),
          if (_error != null) Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.redAccent.withOpacity(0.3))),
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
          if (_successCode != null) Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: _kPrimary.withOpacity(0.3))),
            child: Text('Xuất kho thành công!\nMã: $_successCode', style: const TextStyle(color: _kPrimary, fontSize: 13, fontWeight: FontWeight.w700))),

          _card([_label('Kho xuất'), DropdownButtonFormField<String>(value: (_warehouseId.isNotEmpty && _warehouses.any((w) => w['id'] == _warehouseId)) ? _warehouseId : null, decoration: _deco(null), dropdownColor: _kSurface, style: const TextStyle(color: _kText, fontSize: 14), isExpanded: true,
            items: _warehouses.map((w) => DropdownMenuItem(value: w['id'] as String, child: Text(w['name'] ?? ''))).toList(), onChanged: (v) => setState(() => _warehouseId = v ?? '')),
            const SizedBox(height: 14), _label('Đối tác nhận'),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedPartnerId,
                    decoration: _deco('Chọn đối tác...'),
                    dropdownColor: _kSurface,
                    style: const TextStyle(color: _kText, fontSize: 14),
                    isExpanded: true,
                    selectedItemBuilder: (BuildContext context) {
                      return _partners.map<Widget>((p) {
                        final name = p['alias'] ?? p['partnerTenant']?['name'] ?? '';
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            name,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList();
                    },
                    items: _partners.map((p) {
                      final name = p['alias'] ?? p['partnerTenant']?['name'] ?? '';
                      final taxCode = p['partnerTenant']?['taxCode'] ?? '';
                      return DropdownMenuItem<String>(
                        value: p['id'] as String,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                                  Text('MST: $taxCode', style: const TextStyle(color: _kGray, fontSize: 10, fontFamily: 'monospace')),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                Navigator.pop(context);
                                _deleteB2BPartner(p['id']);
                              },
                            )
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedPartnerId = v;
                        final p = _partners.firstWhere((element) => element['id'] == v);
                        _tenant = p['partnerTenant'];
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _openAddPartnerDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                    ),
                    child: const Text('Thêm', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            if (_tenant != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text('✅ ${_tenant!['name'] ?? _tenant!['id']}', style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.w800, fontSize: 15)))]),

          _card([Row(children: [
            Expanded(child: _modeBtn('Nguyên lô', _scanMode == 'BATCH', () => setState(() => _scanMode = 'BATCH'))),
            const SizedBox(width: 6),
            Expanded(child: _modeBtn('Từng bao', _scanMode == 'ITEM', () => setState(() => _scanMode = 'ITEM'))),
            const SizedBox(width: 6),
            Expanded(child: _modeBtn('Pallet BTP', _scanMode == 'PALLET', () => setState(() => _scanMode = 'PALLET'))),
          ]),
            const SizedBox(height: 12), Row(children: [Expanded(child: TextField(controller: _scanCtrl, style: const TextStyle(color: _kText, fontSize: 14),
              decoration: _deco(_scanMode == 'BATCH' ? 'Nhập mã lô' : _scanMode == 'ITEM' ? 'Nhập serial/QR bao' : 'Nhập mã pallet BTP'),
              onSubmitted: (v) { _onScan(v.trim()); _scanCtrl.clear(); })), const SizedBox(width: 8),
              SizedBox(height: 48, child: ElevatedButton(onPressed: () { _onScan(_scanCtrl.text.trim()); _scanCtrl.clear(); }, style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white), child: const Text('Thêm', style: TextStyle(fontWeight: FontWeight.bold))))])]),

          _card([_label('Thêm nguyên lô'), _BatchDrop(batches: _batches, onAdd: _addBatch)]),

          _card([Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Danh sách xuất', style: TextStyle(color: _kText, fontWeight: FontWeight.w900, fontSize: 15)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text(_kg(_totalW), style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w800)))]),
            const SizedBox(height: 8), if (_items.isEmpty) const Text('Chưa có lô.', style: TextStyle(color: _kGray)),
            ..._items.asMap().entries.map((e) { final i = e.value; final serials = i['serials'] as List?;
              return Container(margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
                child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i['batch_code'] ?? '', style: const TextStyle(color: _kText, fontWeight: FontWeight.w800, fontSize: 13)),
                  Text(serials != null ? '${serials.length} bao' : 'Nguyên lô', style: const TextStyle(color: _kGray, fontSize: 11)),
                  Text(_kg(_d(i['expected_quantity'])), style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.w800))])),
                  IconButton(onPressed: () => setState(() => _items.removeAt(e.key)), icon: const Icon(Icons.close, color: Colors.redAccent, size: 18))])); })]),

          _card([_label('Ghi chú'), TextField(style: const TextStyle(color: _kText, fontSize: 14), decoration: _deco('Ghi chú'), maxLines: 3, onChanged: (v) => _notes = v)]),
        ])),
      bottomNavigationBar: _loading ? null : Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
        decoration: BoxDecoration(color: _kBg, border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08)))),
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
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
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
                      Text('Quét xuất', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
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
                  onPressed: _saving ? null : _submit,
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

  Widget _modeBtn(String l, bool s, VoidCallback t) => Material(color: s ? _kPrimary : _kBg, borderRadius: BorderRadius.circular(10),
    child: InkWell(onTap: t, borderRadius: BorderRadius.circular(10), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), alignment: Alignment.center,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: s ? _kPrimary : Colors.white10)),
      child: Text(l, style: TextStyle(color: s ? Colors.white : _kGray, fontWeight: FontWeight.w700, fontSize: 13)))));
}

class _BatchDrop extends StatefulWidget {
  final List<Map<String, dynamic>> batches;
  final ValueChanged<Map<String, dynamic>> onAdd;
  const _BatchDrop({required this.batches, required this.onAdd});
  @override State<_BatchDrop> createState() => _BatchDropState();
}
class _BatchDropState extends State<_BatchDrop> {
  String? _id;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: DropdownButtonFormField<String>(value: _id, decoration: InputDecoration(hintText: 'Chọn lô', hintStyle: const TextStyle(color: Color(0xFF64748B)), filled: true, fillColor: _kBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white10)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white10))), dropdownColor: _kSurface, style: const TextStyle(color: _kText, fontSize: 14), isExpanded: true, menuMaxHeight: 300,
        items: widget.batches.map((b) => DropdownMenuItem(value: b['id'] as String, child: Text('${b['batchCode'] ?? b['batch_code']}', overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setState(() => _id = v))),
      const SizedBox(width: 8), SizedBox(height: 48, child: ElevatedButton(onPressed: () {
        if (_id == null) return; widget.onAdd(widget.batches.firstWhere((b) => b['id'] == _id)); setState(() => _id = null);
      }, style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white), child: const Text('Thêm', style: TextStyle(fontWeight: FontWeight.bold))))]);
  }
}
