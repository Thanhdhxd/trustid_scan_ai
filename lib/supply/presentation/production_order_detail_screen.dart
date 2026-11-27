import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/core/utils/app_toast.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';
import 'package:trustid_scan_ai/core/utils/permission_helper.dart';
import '../data/supply_repository.dart';
import '../domain/packaging_receipt.dart';
import '../domain/production_order.dart';
import '../domain/production_ticket.dart';
import 'order_list_screen.dart';
import 'production_order/constants/prod_order_constants.dart';
import 'production_order/constants/prod_order_helpers.dart';
import 'production_order/dialogs/prod_order_cancel_dialog.dart';
import 'production_order/dialogs/prod_order_complete_dialog.dart';

/// Màn hình Chi tiết Lệnh Sản Xuất (`STANDARD` và `BAG_PACKAGING`) theo đặc tả `FS-PRO-02`.
class ProductionOrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  const ProductionOrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<ProductionOrderDetailScreen> createState() =>
      _ProductionOrderDetailScreenState();
}

class _ProductionOrderDetailScreenState
    extends ConsumerState<ProductionOrderDetailScreen> {
  ProductionOrder? _order;
  Map<String, dynamic>? _rawOrder;
  bool _loading = true;
  bool _creatingChild = false;
  bool _retrying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = _order == null;
      _error = null;
    });
    try {
      final data = await ref
          .read(supplyRepositoryProvider)
          .getProductionOrderDetail(widget.orderId);
      if (!mounted) return;
      setState(() {
        _rawOrder = data;
        _order = ProductionOrder.fromJson(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = parseSupplyHttpError(e).message;
      });
    }
  }

  Future<void> _retryGenerate() async {
    setState(() => _retrying = true);
    try {
      await ref.read(supplyRepositoryProvider).retryGenerateCodes(widget.orderId);
      if (!mounted) return;
      AppToast.success(context, 'Đã gửi yêu cầu sinh lại mã QR.');
      await _loadDetail();
    } catch (e) {
      if (mounted) AppToast.error(context, parseSupplyHttpError(e).message);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _createNewReceiptOrTicket() async {
    final order = _order;
    if (order == null || _creatingChild) return;

    setState(() => _creatingChild = true);
    try {
      final repo = ref.read(supplyRepositoryProvider);
      if (order.isBagPackaging) {
        final created = await repo.createReceipt(orderId: order.id);
        final receiptMap = created['receipt'] is Map
            ? Map<String, dynamic>.from(created['receipt'] as Map)
            : created;
        final receiptId = receiptMap['id']?.toString() ?? '';
        if (!mounted) return;
        AppToast.success(
          context,
          'Đã tạo phiếu đóng bao ${receiptMap['receiptCode'] ?? ''}',
        );
        if (receiptId.isNotEmpty) {
          await context.push('/manager/bag-linking/${order.id}?receiptId=$receiptId');
        }
      } else {
        final created = await repo.createProductionTicket(orderId: order.id);
        final ticketId = created['id']?.toString() ?? '';
        if (!mounted) return;
        AppToast.success(
          context,
          'Đã tạo phiếu đóng gói ${created['ticketCode'] ?? ''}',
        );
        if (ticketId.isNotEmpty) {
          await context.push('/manager/standard-packaging/${order.id}?ticketId=$ticketId');
        }
      }
      await _loadDetail();
    } catch (e) {
      if (mounted) AppToast.error(context, parseSupplyHttpError(e).message);
    } finally {
      if (mounted) setState(() => _creatingChild = false);
    }
  }

  void _openBagReceipt(PackagingReceipt receipt) async {
    await context.push('/manager/bag-linking/${widget.orderId}?receiptId=${receipt.id}');
    _loadDetail();
  }

  Future<void> _openStandardTicket(ProductionTicket ticket) async {
    await context.push('/manager/standard-packaging/${widget.orderId}?ticketId=${ticket.id}');
    _loadDetail();
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final canManage = PermissionHelper.canManageProductionOrders(ref);
    final canPallet = PermissionHelper.canManagePallets(ref);

    return Scaffold(
      backgroundColor: kProdOrderBg,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                order?.orderCode ?? 'Chi tiết Lệnh Sản Xuất',
                style: const TextStyle(color: kProdOrderText, fontSize: 15.5, fontWeight: FontWeight.bold),
              ),
            ),
            if (order?.productName != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  order!.productName!,
                  style: const TextStyle(color: kProdOrderTextGray, fontSize: 12),
                ),
              ),
          ],
        ),
        backgroundColor: kProdOrderBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: kProdOrderTextGray),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kProdOrderTextGray),
            onPressed: _loadDetail,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kProdOrderPrimary))
          : _error != null && order == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _loadDetail, child: const Text('Thử lại')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDetail,
                  color: kProdOrderPrimary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (order!.isGenerating || order.isGenerationFailed)
                          _buildGenerationBanner(order, canManage: canManage),
                        _buildOrderInfoCard(order),
                        const SizedBox(height: 12),
                        _buildSummaryProgressCard(order),
                        const SizedBox(height: 12),
                        _buildActionsCard(order, canManage: canManage, canPallet: canPallet),
                        const SizedBox(height: 16),
                        _buildDocumentsList(order),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildGenerationBanner(ProductionOrder order, {required bool canManage}) {
    final failed = order.isGenerationFailed;
    final color = failed ? Colors.redAccent : kProdOrderAmber;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(failed ? Icons.error_outline : Icons.hourglass_top, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              failed
                  ? 'Sinh mã QR thất bại. Bấm "Thử lại sinh mã" hoặc kiểm tra hạn mức mã.'
                  : 'Hệ thống đang sinh mã QR nền. Kéo xuống hoặc bấm Làm mới để cập nhật.',
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
          if (failed && canManage)
            ElevatedButton(
              onPressed: _retrying ? null : _retryGenerate,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
              child: Text(_retrying ? '...' : 'Thử lại'),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard(ProductionOrder order) {
    final statusColor = prodOrderStatusColor(order.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kProdOrderSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (order.isBagPackaging ? kProdOrderPrimary : Colors.lightBlueAccent)
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  prodOrderTypeLabel(order.orderType),
                  style: TextStyle(
                    color: order.isBagPackaging
                        ? kProdOrderPrimaryLight
                        : Colors.lightBlueAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  prodOrderStatusLabel(order.status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 20),
          _infoRow('Sản phẩm', '${order.productName ?? '—'}${order.productSku != null ? ' (${order.productSku})' : ''}'),
          _infoRow('Nguồn nguyên liệu', prodOrderSourceLabel(order.sourceType)),
          _infoRow('Kho lưu thành phẩm', order.warehouseName ?? '—'),
          _infoRow(
            'Quy cách',
            '${order.unitWeightKg} kg/gói${order.isBagPackaging ? ' • ${order.packagingSpec} gói/bao' : ''}',
          ),
          _infoRow(
            order.isCompleted ? 'NSX / HSD chính thức' : 'NSX / HSD dự kiến',
            '${formatProdOrderDate(order.mfgDate ?? order.plannedDate)} → ${formatProdOrderDate(order.expiryDate)}',
          ),
          if (order.plannedUnits > 0)
            _infoRow(
              'Số mã gói',
              '${order.plannedUnits}${order.sparePacketQuantity > 0 ? ' + ${order.sparePacketQuantity} dự phòng' : ''}',
            ),
          if (order.isBagPackaging && order.totalBags > 0)
            _infoRow(
              'Số mã bao',
              '${order.totalBags}${order.spareBagQuantity > 0 ? ' + ${order.spareBagQuantity} dự phòng' : ''}',
            ),
          if (order.outputBatchCode != null)
            _infoRow('Mã lô thành phẩm', order.outputBatchCode!),
          if (order.creatorName != null) _infoRow('Người lập', order.creatorName!),
          if (order.notes != null) _infoRow('Ghi chú', order.notes!),
          if (order.isCompleted && order.closeType != null) ...[
            const Divider(color: Colors.white12, height: 18),
            _infoRow(
              'Hình thức chốt',
              order.closeType == 'STOPPED' ? 'Hoàn thành (Dừng sớm)' : 'Hoàn thành bình thường',
            ),
            if (order.stopReasonCode != null)
              _infoRow('Lý do dừng', _stopReasonLabel(order.stopReasonCode!)),
            if (order.stopNote != null) _infoRow('Chi tiết dừng', order.stopNote!),
            if (order.remainderAction != null)
              _infoRow('Xử lý phần dư', _remainderActionLabel(order.remainderAction!)),
            if (order.lossWeightKg > 0)
              _infoRow('Hao hụt ghi nhận', '${order.lossWeightKg.toStringAsFixed(2)} kg'),
            if (order.lossReason != null) _infoRow('Lý do hao hụt', order.lossReason!),
          ],
          if (order.isCancelled && order.cancelReason != null) ...[
            const Divider(color: Colors.white12, height: 18),
            _infoRow('Lý do hủy', order.cancelReason!),
          ],
        ],
      ),
    );
  }

  String _stopReasonLabel(String code) {
    switch (code) {
      case 'OUT_OF_MATERIAL':
        return 'Hết nguyên liệu / bán thành phẩm';
      case 'MACHINE_FAULT':
        return 'Sự cố máy móc / thiết bị';
      case 'QUALITY_ISSUE':
        return 'Vấn đề chất lượng (QC)';
      case 'OTHER':
        return 'Lý do khác';
      default:
        return code;
    }
  }

  String _remainderActionLabel(String action) {
    switch (action) {
      case 'REFUND':
        return 'Hoàn trả lô nguyên liệu gốc';
      case 'SURPLUS':
        return 'Nhập kho dư phẩm (Surplus)';
      case 'LOSS':
        return 'Hao hụt toàn bộ';
      default:
        return action;
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: kProdOrderTextGray, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryProgressCard(ProductionOrder order) {
    final summary = order.summary;
    final committedPackets = summary?.committedPackets ?? order.actualUnits;
    final activePackets = summary?.activeScannedPackets ?? 0;
    final totalPacketProgress = committedPackets + activePackets;
    final remainingKg = summary?.remainingWeightKg ??
        ((order.plannedWeightKg - order.actualWeightKg).clamp(0.0, double.infinity));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kProdOrderSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tiến độ thực hiện',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statBox(
                'Đã nhập kho',
                '${order.actualWeightKg.toStringAsFixed(1)} / ${order.plannedWeightKg.toStringAsFixed(1)} kg',
                kProdOrderPrimaryLight,
              ),
              const SizedBox(width: 8),
              _statBox(
                'Còn lại',
                '${remainingKg.toStringAsFixed(1)} kg',
                remainingKg > 0 ? kProdOrderAmber : Colors.greenAccent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _statBox(
                'Gói (gồm phiếu mở)',
                '$totalPacketProgress / ${order.plannedUnits}',
                Colors.lightBlueAccent,
              ),
              if (order.isBagPackaging) ...[
                const SizedBox(width: 8),
                _statBox(
                  'Bao đã đóng',
                  '${summary?.packedBags ?? order.linkedBags} / ${order.totalBags}',
                  Colors.tealAccent,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: order.progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation(kProdOrderPrimaryLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: kProdOrderBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: kProdOrderTextGray, fontSize: 11)),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(color: accent, fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(
    ProductionOrder order, {
    required bool canManage,
    required bool canPallet,
  }) {
    final summary = order.summary;
    final canActiveOperate =
        order.status == 'CODES_READY' || order.status == 'IN_PROGRESS' || order.status == 'APPROVED';

    final canCreateChild = canManage &&
        canActiveOperate &&
        (order.isBagPackaging
            ? (summary?.canCreateReceipt ?? ((summary?.unlinkedBagsCount ?? 1) > 0))
            : ((summary?.remainingWeightKg ?? 1) > 0));

    final canShowPallet = order.isBagPackaging &&
        canPallet &&
        !order.isGenerating &&
        !order.isGenerationFailed &&
        !order.isCancelled;

    final hasCompleted = summary?.hasCompletedReceiptOrTicket ?? false;
    final canCompleteOrder =
        canManage && canActiveOperate && (summary?.canComplete ?? hasCompleted);
    final canCancelOrder = canManage && !order.isCompleted && !order.isCancelled && (summary?.canCancel ?? !hasCompleted);

    if (!canCreateChild && !canShowPallet && !canCompleteOrder && !canCancelOrder) {
      return const SizedBox.shrink();
    }

    final remainingKg = summary?.remainingWeightKg ??
        (order.plannedWeightKg - order.actualWeightKg).clamp(0.0, double.infinity);

    final hasSecondaryLeft = canShowPallet;
    final hasSecondaryRight = canCompleteOrder || canCancelOrder;

    Widget buildPalletBtn() => SizedBox(
          height: 44,
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await context.push('/manager/pallet-linking/${order.id}');
              if (mounted) {
                OrderListScreen.clearStaticCache();
                _loadDetail();
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.lightBlueAccent,
              backgroundColor: Colors.lightBlueAccent.withValues(alpha: 0.08),
              side: BorderSide(color: Colors.lightBlueAccent.withValues(alpha: 0.45)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            icon: const Icon(Icons.palette_outlined, size: 18),
            label: const Text(
              'Đóng Pallet',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );

    Widget buildCompleteBtn() {
      final isStop = remainingKg > 0.001;
      final btnColor = isStop ? Colors.orange.shade700 : kProdOrderPrimary;
      return SizedBox(
        height: 44,
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            final productMap = _rawOrder?['product'] is Map
                ? Map<String, dynamic>.from(_rawOrder!['product'] as Map)
                : null;
            showProdOrderCompleteDialog(
              context,
              ref: ref,
              order: order,
              closeType: isStop ? 'STOPPED' : 'NORMAL',
              productData: productMap,
              onCompleted: () {
                OrderListScreen.clearStaticCache();
                _loadDetail();
              },
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: btnColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          icon: Icon(
            isStop ? Icons.stop_circle_outlined : Icons.check_circle_outline,
            size: 18,
          ),
          label: Text(
            isStop ? 'Dừng sớm' : 'Chốt lệnh',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    Widget buildCancelBtn() => SizedBox(
          height: 44,
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              showProdOrderCancelDialog(
                context,
                ref: ref,
                orderId: order.id,
                orderCode: order.orderCode,
                onCancelled: () {
                  OrderListScreen.clearStaticCache();
                  AppToast.success(context, 'Đã hủy Lệnh Sản Xuất.');
                  Navigator.of(context).pop();
                },
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              backgroundColor: Colors.redAccent.withValues(alpha: 0.08),
              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.45)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text(
              'Hủy Lệnh',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kProdOrderSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Thao tác Lệnh Sản Xuất',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (canCreateChild) ...[
            SizedBox(
              height: 46,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _creatingChild ? null : _createNewReceiptOrTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kProdOrderPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add, size: 20),
                label: Text(
                  _creatingChild
                      ? 'Đang tạo...'
                      : (order.isBagPackaging ? 'Tạo phiếu đóng bao' : 'Tạo phiếu đóng gói'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (hasSecondaryLeft || hasSecondaryRight) const SizedBox(height: 10),
          ],
          if (hasSecondaryLeft && hasSecondaryRight)
            Row(
              children: [
                Expanded(child: buildPalletBtn()),
                const SizedBox(width: 10),
                Expanded(
                  child: canCompleteOrder ? buildCompleteBtn() : buildCancelBtn(),
                ),
              ],
            )
          else if (hasSecondaryLeft)
            buildPalletBtn()
          else if (canCompleteOrder)
            buildCompleteBtn()
          else if (canCancelOrder)
            buildCancelBtn(),
          if (canCompleteOrder && canCancelOrder) ...[
            const SizedBox(height: 10),
            buildCancelBtn(),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentsList(ProductionOrder order) {
    final isBag = order.isBagPackaging;
    final items = isBag ? order.packagingReceipts : order.tickets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isBag
              ? 'Danh sách Phiếu Đóng Bao (${order.packagingReceipts.length})'
              : 'Danh sách Phiếu Đóng Gói (${order.tickets.length})',
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kProdOrderSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Chưa có phiếu nào được tạo cho lệnh này.',
              style: TextStyle(color: kProdOrderTextGray, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          )
        else if (isBag)
          ...order.packagingReceipts.map(_buildReceiptCard)
        else
          ...order.tickets.map(_buildTicketCard),
      ],
    );
  }

  Widget _buildReceiptCard(PackagingReceipt receipt) {
    final statusColor = prodOrderStatusColor(receipt.status);
    final statusLabel = receipt.isPacking
        ? 'Đang đóng bao'
        : (receipt.isCompleted ? 'Đã lưu & nhập kho' : 'Đã hủy');

    return Card(
      color: kProdOrderSurface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => _openBagReceipt(receipt),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.16),
          child: Icon(Icons.receipt_long, color: statusColor, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                receipt.receiptCode,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${receipt.totalBags} bao • ${receipt.totalPackets} gói • ${formatProdOrderDate(receipt.packingTime ?? receipt.createdAt)}',
          style: const TextStyle(color: kProdOrderTextGray, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: kProdOrderTextGray),
      ),
    );
  }

  Widget _buildTicketCard(ProductionTicket ticket) {
    final statusColor = prodOrderStatusColor(ticket.status);
    final statusLabel = ticket.isOpen
        ? (ticket.status == 'OPEN' ? 'Mới mở' : 'Đang đóng gói')
        : (ticket.isCompleted ? 'Đã lưu & nhập kho' : 'Đã hủy');

    return Card(
      color: kProdOrderSurface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => _openStandardTicket(ticket),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.16),
          child: Icon(Icons.qr_code_2_rounded, color: statusColor, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                ticket.ticketCode,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${ticket.scannedUnits} gói • ${(ticket.isCompleted ? ticket.actualWeightKg : ticket.scannedWeightKg).toStringAsFixed(1)} kg • ${formatProdOrderDate(ticket.createdAt)}',
          style: const TextStyle(color: kProdOrderTextGray, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: kProdOrderTextGray),
      ),
    );
  }
}
