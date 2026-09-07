import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/scan/scanner_screen.dart';
import '../../data/export_order_repository.dart';
import '../../data/supply_repository.dart';
import '../../domain/export_order.dart';

class ExportOrderScanScreen extends ConsumerStatefulWidget {
  final String orderId;
  const ExportOrderScanScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  ConsumerState<ExportOrderScanScreen> createState() => _ExportOrderScanScreenState();
}

class _ExportOrderScanScreenState extends ConsumerState<ExportOrderScanScreen> {
  bool _isLoading = true;
  bool _isProcessingScan = false;
  ExportOrder? _order;
  List<dynamic> _scanLogs = [];
  Timer? _debounce;

  bool _isUnscanMode = false;
  bool _isInfoExpanded = true;
  final TextEditingController _manualInputCtrl = TextEditingController();

  List<dynamic> _dealers = [];
  List<dynamic> _warehouses = [];

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _manualInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDetail() async {
    try {
      final repo = ref.read(exportOrderRepositoryProvider);
      final order = await repo.getDetail(widget.orderId);
      final logs = await repo.getScanLogs(widget.orderId);
      final supplyRepo = ref.read(supplyRepositoryProvider);
      
      List<dynamic> loadedDealers = [];
      List<dynamic> loadedWarehouses = [];
      
      try {
        loadedDealers = await supplyRepo.getDealers(limit: 100);
      } catch (e) {
        // Ignore expected permission errors silently
      }
      
      try {
        loadedWarehouses = await supplyRepo.getWarehouses(limit: 100);
      } catch (e) {
        // Ignore expected permission errors silently
      }

      if ((order.dealerName == null || order.dealerName!.isEmpty) && order.dealerId.isNotEmpty) {
        final foundDealer = loadedDealers.any((d) => d['id'] == order.dealerId);
        if (!foundDealer) {
          try {
            final dealerDetail = await supplyRepo.getDealerDetail(order.dealerId);
            loadedDealers.add(dealerDetail);
          } catch (e) {
            debugPrint('Failed to load specific dealer: $e');
          }
        }
      }

      setState(() {
        _order = order;
        _scanLogs = logs;
        _dealers = loadedDealers;
        _warehouses = loadedWarehouses;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        Navigator.pop(context);
      }
    }
  }

  void _playSound(bool isSuccess) {}

  Future<void> _openCameraScanner() async {
    if (_isProcessingScan || _order == null) return;
    
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ScannerScreen(
          title: _isUnscanMode ? 'Quét Xóa hàng xuất kho' : 'Quét hàng xuất kho',
          instruction: _isUnscanMode ? 'Quét mã để TRỪ khỏi phiếu' : 'Di chuyển camera đến mã sản phẩm/bao/pallet...',
        ),
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      _manualInputCtrl.text = result;
      _handleManualScan();
    }
  }

  Future<void> _handleManualScan() async {
    final code = _manualInputCtrl.text.trim();
    if (code.isEmpty || _isProcessingScan || _order == null) return;
    
    setState(() => _isProcessingScan = true);
    FocusScope.of(context).unfocus();
    
    try {
      if (_isUnscanMode) {
        final repo = ref.read(exportOrderRepositoryProvider);
        
        // Find matching bag
        final matchedBag = _scanLogs.firstWhere(
            (i) => i['bagCode'] == code || i['bagSerial'] == code, orElse: () => null);
            
        if (matchedBag != null) {
          await repo.unscanBox(widget.orderId, matchedBag['bagCode']);
          _playSound(true);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã xóa bao ${matchedBag['bagCode']} khỏi phiếu'), backgroundColor: Colors.orange, duration: const Duration(seconds: 1)));
        } else {
          // Find matching item
          final matchedItem = _scanLogs.firstWhere(
              (i) => i['itemSerial'] == code || i['fullQrCode'] == code, orElse: () => null);
              
          if (matchedItem != null) {
            if (matchedItem['bagCode'] != null && matchedItem['bagCode'].toString().isNotEmpty) {
              await repo.unscanBox(widget.orderId, matchedItem['bagCode']);
              _playSound(true);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã xóa bao ${matchedItem['bagCode']} khỏi phiếu'), backgroundColor: Colors.orange, duration: const Duration(seconds: 1)));
            } else {
              await repo.unscanItem(widget.orderId, matchedItem['itemSerial']);
              _playSound(true);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã xóa mã $code khỏi phiếu'), backgroundColor: Colors.orange, duration: const Duration(seconds: 1)));
            }
          } else {
            throw Exception('Sản phẩm chưa được quét hoặc đã bị hủy');
          }
        }
      } else {
        await ref.read(exportOrderRepositoryProvider).scanItem(widget.orderId, code);
        _playSound(true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã quét thành công!'), duration: Duration(seconds: 1)));
      }
      _manualInputCtrl.clear();
      await _fetchDetail();
    } catch (e) {
      if (mounted) {
        String errMsg = 'Đã có lỗi xảy ra: $e';
        if (e.runtimeType.toString() == 'DioException' || e.runtimeType.toString() == 'DioError') {
          try {
            dynamic dioError = e;
            if (dioError.response?.data != null && dioError.response?.data is Map) {
              final Map data = dioError.response!.data;
              if (data.containsKey('message')) {
                errMsg = data['message'].toString();
              } else if (data.containsKey('error')) {
                errMsg = data['error'].toString();
              } else {
                errMsg = dioError.message?.toString() ?? 'Lỗi kết nối Server';
              }
            } else {
              errMsg = dioError.message?.toString() ?? 'Lỗi kết nối Server';
            }
          } catch (_) {}
        }
        _playSound(false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $errMsg'), backgroundColor: Colors.red));
      }
    } finally {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() => _isProcessingScan = false);
      });
    }
  }
  
  bool _isFullyPicked() {
    if (_order == null || _order!.items.isEmpty) return false;
    for (var item in _order!.items) {
      if (item.scannedQuantity < item.expectedQuantity) return false;
    }
    return true;
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: const Color(0xFF16325B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Cảnh báo hủy lệnh', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(c, false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Hành động này sẽ Hủy lệnh xuất kho và giải phóng (trả lại) toàn bộ sản phẩm đã quét về kho khả dụng. Bạn có chắc chắn muốn hủy lệnh này?',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(c, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Bỏ qua'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(c, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00875A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Đồng ý hủy'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    
    if (confirmed == true) {
      try {
        setState(() => _isLoading = true);
        await ref.read(exportOrderRepositoryProvider).cancel(widget.orderId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã hủy lệnh xuất kho.')));
          context.pop();
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi hủy lệnh: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _finishPicking() async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (c) => const _FinishPickingDialog(),
    );
    
    if (payload != null) {
      try {
        setState(() => _isLoading = true);
        final repo = ref.read(exportOrderRepositoryProvider);
        await repo.finishPicking(widget.orderId);
        
        if (payload['createDelivery'] == true) {
          await repo.createDelivery(widget.orderId, {
            'vehicleId': payload['vehicleId'],
            'isExternalDriver': payload['isExternalDriver'],
            'driverName': payload['driverName'],
            'driverPhone': payload['driverPhone'],
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã hoàn thành xuất kho thành công!')));
          context.pop();
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F2B46),
        appBar: AppBar(
          title: const Text('Thực thi xuất kho', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF0F2B46),
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF00875A))),
      );
    }
    
    final isDone = _isFullyPicked();
    final isCompleted = _order?.status == 'EXPORTED';

    return Scaffold(
      backgroundColor: const Color(0xFF0F2B46),
      appBar: AppBar(
        title: const Text('Thực thi xuất kho', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F2B46),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. General Info Card
          _buildGeneralInfoCard(),
          
          // 2. Scan Input Box
          if (isCompleted)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00875A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00875A), width: 1.5),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle, color: Color(0xFF00875A)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Lệnh xuất kho này đã hoàn tất.',
                      style: TextStyle(color: Color(0xFF00875A), fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF16325B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isUnscanMode ? Colors.redAccent : Colors.white12),
              ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.qr_code_scanner, color: Colors.greenAccent, size: 20),
                    const SizedBox(width: 8),
                    const Text('Quét QR Code', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    const Text('Quét xóa', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    Switch(
                      value: _isUnscanMode,
                      onChanged: (val) => setState(() => _isUnscanMode = val),
                      activeColor: Colors.redAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualInputCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: _isUnscanMode ? 'Quét mã cần XÓA khỏi phiếu...' : 'Quét mã qr sản phẩm, mã bao, mã pallet...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF0F2B46),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.greenAccent)),
                        ),
                        onChanged: (val) {
                          if (val.trim().isNotEmpty && val.trim().length > 5) {
                            _debounce?.cancel();
                            _debounce = Timer(const Duration(milliseconds: 300), () {
                              if (mounted && _manualInputCtrl.text.trim().isNotEmpty) {
                                _handleManualScan();
                              }
                            });
                          }
                        },
                        onSubmitted: (_) => _handleManualScan(),
                        readOnly: _isProcessingScan,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _isProcessingScan ? null : _openCameraScanner,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        decoration: BoxDecoration(
                          color: _isUnscanMode ? Colors.redAccent.withOpacity(0.1) : const Color(0xFF00875A).withOpacity(0.1),
                          border: Border.all(color: _isUnscanMode ? Colors.redAccent : const Color(0xFF00875A)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            if (_isProcessingScan)
                              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            else
                              Icon(Icons.qr_code_scanner, size: 20, color: _isUnscanMode ? Colors.redAccent : const Color(0xFF00875A)),
                            const SizedBox(width: 6),
                            Text(_isUnscanMode ? 'Xóa' : 'Quét', style: TextStyle(color: _isUnscanMode ? Colors.redAccent : const Color(0xFF00875A), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 3. Progress List
          Expanded(
            child: Container(
              color: const Color(0xFF16325B),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    color: const Color(0xFF0F2B46).withOpacity(0.5),
                    child: Row(
                      children: const [
                        Icon(Icons.info_outline, color: Colors.orange, size: 18),
                        SizedBox(width: 8),
                        Text('Danh sách hàng cần lấy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                      ],
                    ),
                  ),
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white12)),
                    ),
                    child: Row(
                      children: const [
                        Expanded(flex: 3, child: Text('Sản phẩm', style: TextStyle(color: Colors.white54, fontSize: 13))),
                        Expanded(flex: 1, child: Text('Yêu cầu', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 13))),
                        Expanded(flex: 1, child: Text('Đã quét', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 13))),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _order?.items.length ?? 0,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                      itemBuilder: (context, index) {
                        final item = _order!.items[index];
                        final itemDone = item.scannedQuantity >= item.expectedQuantity;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.product?['name'] ?? item.productId, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text('Đơn vị: ${item.unitName ?? 'Gói'}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${item.expectedQuantity}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                    if (item.conversionFactor > 1) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '= ${item.expectedQuantity * item.conversionFactor} gói',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '${item.scannedQuantity}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14, 
                                    fontWeight: FontWeight.bold,
                                    color: itemDone ? const Color(0xFF00875A) : Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (!isCompleted)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF16325B),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))]
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Hủy Lệnh', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _cancelOrder,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle_outline, size: 16),
                              label: const Text('Hoàn Tất Xuất Kho', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00875A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _finishPicking,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGeneralInfoCard() {
    if (_order == null) return const SizedBox();
    
    // Resolve names
    String dealerName = _order!.dealerName ?? _order!.dealerId;
    String dealerAddress = 'Không có thông tin';
    for (var d in _dealers) {
      if (d['id'] == _order!.dealerId) {
        dealerName = d['name'] ?? dealerName;
        dealerAddress = '${d['contactPerson'] ?? ''} - ${d['address'] ?? 'Không có địa chỉ'}';
        break;
      }
    }
    
    String warehouseName = _order!.warehouseName ?? _order!.sourceWarehouseId;
    for (var w in _warehouses) {
      if (w['id'] == _order!.sourceWarehouseId) {
        warehouseName = w['name'] ?? warehouseName;
        break;
      }
    }
    
    final now = DateTime.now();
    final String exportDate = '${now.day}/${now.month}/${now.year}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16325B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('THÔNG TIN CHUNG', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
              InkWell(
                onTap: () => setState(() => _isInfoExpanded = !_isInfoExpanded),
                child: Icon(_isInfoExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.white54, size: 20),
              )
            ],
          ),
          if (_isInfoExpanded) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _infoItem('Số PXK', _order!.orderCode.replaceFirst('LXH', 'PXK'), Colors.greenAccent)),
                Expanded(child: _infoItem('Số LXH', _order!.orderCode, Colors.white)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _infoItem('Kho xuất', warehouseName, Colors.white)),
                Expanded(child: _infoItem('Đại lý', dealerName, Colors.white)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _infoItem('Ngày xuất', exportDate, Colors.white)),
                Expanded(child: _infoItem('Người xuất kho', 'Demo (Hệ thống)', Colors.white)),
              ],
            ),
            const SizedBox(height: 12),
            _infoItem('Người nhận & Địa chỉ', dealerAddress, Colors.white70),
          ]
        ],
      ),
    );
  }
  Widget _infoItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _FinishPickingDialog extends ConsumerStatefulWidget {
  const _FinishPickingDialog({Key? key}) : super(key: key);

  @override
  ConsumerState<_FinishPickingDialog> createState() => _FinishPickingDialogState();
}

class _FinishPickingDialogState extends ConsumerState<_FinishPickingDialog> {
  bool _createDelivery = true;
  bool _isExternalDriver = false;
  String? _vehicleId;
  final _driverNameCtrl = TextEditingController();
  final _driverPhoneCtrl = TextEditingController();
  
  List<dynamic> _vehicles = [];
  bool _isLoadingVehicles = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }
  
  Future<void> _loadVehicles() async {
    try {
      final repo = ref.read(supplyRepositoryProvider);
      final vehicles = await repo.getVehicles(limit: 1000);
      if (mounted) {
        setState(() {
          _vehicles = vehicles;
          _isLoadingVehicles = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingVehicles = false);
      }
    }
  }

  @override
  void dispose() {
    _driverNameCtrl.dispose();
    _driverPhoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF16325B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text('Hoàn tất xuất kho & Tạo phiếu giao hàng', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Hệ thống sẽ trừ tồn kho và đánh dấu đã xuất.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              InkWell(
                onTap: () => setState(() => _createDelivery = !_createDelivery),
                child: Row(
                  children: [
                    Icon(_createDelivery ? Icons.check_box : Icons.check_box_outline_blank, color: const Color(0xFF00875A)),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Tạo Phiếu Giao Hàng (PGH) luôn', style: TextStyle(color: Color(0xFF00875A), fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              
              if (_createDelivery) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Chọn xe giao hàng:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _isLoadingVehicles
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00875A)))
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F2B46),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _vehicleId != null ? const Color(0xFF00875A) : Colors.white24,
                                ),
                              ),
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _vehicleId,
                                underline: const SizedBox(),
                                dropdownColor: const Color(0xFF0F2B46),
                                iconEnabledColor: Colors.white70,
                                hint: const Text(
                                  'Chọn xe...',
                                  style: TextStyle(color: Colors.white60, fontSize: 13),
                                ),
                                // selectedItemBuilder controls the text shown when an item is selected
                                selectedItemBuilder: (ctx) => _vehicles.map<Widget>((v) {
                                  final plate = v['licensePlate'] ?? v['license_plate'] ?? '';
                                  final type = v['type'] ?? 'Xe tải';
                                  final driver = v['defaultDriver']?['fullName'] ?? v['defaultDriver']?['full_name'] ?? 'Chưa gán';
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '$plate ($type) - $driver',
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                items: _vehicles.map((v) {
                                  final plate = v['licensePlate'] ?? v['license_plate'] ?? v['id'] ?? '';
                                  final type = v['type'] ?? 'Xe tải';
                                  final driverName = v['defaultDriver']?['fullName'] ?? v['defaultDriver']?['full_name'] ?? 'Chưa gán lái xe';
                                  return DropdownMenuItem<String>(
                                    value: v['id']?.toString(),
                                    child: Text(
                                      '$plate ($type) - $driverName',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _vehicleId = val),
                              ),
                            ),
                      const SizedBox(height: 8),
                      
                      // Hiển thị lái xe mặc định khi chọn xe và không dùng lái thuê
                      if (_vehicleId != null && !_isExternalDriver) Builder(
                        builder: (_) {
                          final v = _vehicles.cast<dynamic>().firstWhere(
                            (x) => x['id']?.toString() == _vehicleId, orElse: () => null);
                          final driverName = v?['defaultDriver']?['fullName'] ?? v?['defaultDriver']?['full_name'];
                          if (driverName == null) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF00875A)),
                                const SizedBox(width: 4),
                                Text('Lái xe: $driverName',
                                  style: const TextStyle(color: Color(0xFF00875A), fontSize: 13, fontStyle: FontStyle.italic)),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      
                      InkWell(
                        onTap: () => setState(() => _isExternalDriver = !_isExternalDriver),
                        child: Row(
                          children: [
                            Icon(_isExternalDriver ? Icons.check_box : Icons.check_box_outline_blank, color: const Color(0xFF00875A)),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('Lái xe thuê ngoài (không có tài khoản)', style: TextStyle(color: Color(0xFF00875A), fontWeight: FontWeight.bold, fontSize: 13))),
                          ],
                        ),
                      ),
                      
                      if (_isExternalDriver) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _driverNameCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Tên lái xe',
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: const Color(0xFF0F2B46),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _driverPhoneCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Số điện thoại',
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: const Color(0xFF0F2B46),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Lái xe thuê ngoài → đại lý sẽ nhận hàng trực tiếp (không cần lái xe quét)',
                            style: TextStyle(color: Colors.orange, fontSize: 13),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Đóng'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, {
                          'createDelivery': _createDelivery,
                          'vehicleId': _vehicleId,
                          'isExternalDriver': _createDelivery ? _isExternalDriver : false,
                          'driverName': _createDelivery && _isExternalDriver ? _driverNameCtrl.text.trim() : null,
                          'driverPhone': _createDelivery && _isExternalDriver ? _driverPhoneCtrl.text.trim() : null,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00875A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Xác nhận Xuất Kho'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
