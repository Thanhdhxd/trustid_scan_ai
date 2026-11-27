import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';
import '../../../data/supply_repository.dart';
import '../../../domain/bag_mapping.dart';
import '../../../domain/packaging_receipt.dart';
import '../../production_order/constants/prod_order_constants.dart';
import '../../production_order/constants/prod_order_helpers.dart';

/// BottomSheet hiển thị danh sách từng gói bên trong một bao (`GET /supply/bag-mappings/:id/packets`).
Future<void> showBagPacketDetailSheet(
  BuildContext context, {
  required BagMapping bag,
  required bool canReplace,
  required ValueChanged<String> onTapReplaceSerial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: kProdOrderSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _BagPacketDetailSheet(
      bag: bag,
      canReplace: canReplace,
      onTapReplaceSerial: onTapReplaceSerial,
    ),
  );
}

class _BagPacketDetailSheet extends ConsumerStatefulWidget {
  final BagMapping bag;
  final bool canReplace;
  final ValueChanged<String> onTapReplaceSerial;

  const _BagPacketDetailSheet({
    required this.bag,
    required this.canReplace,
    required this.onTapReplaceSerial,
  });

  @override
  ConsumerState<_BagPacketDetailSheet> createState() =>
      _BagPacketDetailSheetState();
}

class _BagPacketDetailSheetState extends ConsumerState<_BagPacketDetailSheet> {
  BagPacketDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPackets();
  }

  Future<void> _loadPackets() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await ref
          .read(supplyRepositoryProvider)
          .getBagMappingPackets(widget.bag.id);
      if (!mounted) return;
      setState(() {
        _detail = BagPacketDetail.fromJson(raw);
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

  Color _packetStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'REPLACED':
        return Colors.redAccent;
      case 'REPLACEMENT':
        return kProdOrderAmber;
      default:
        return kProdOrderPrimaryLight;
    }
  }

  String _packetStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'REPLACED':
        return 'Đã thay';
      case 'REPLACEMENT':
        return 'Thay thế';
      default:
        return 'Hợp lệ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final packets = _detail?.packets ?? const <BagPacketItem>[];

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.inventory_2, color: kProdOrderPrimaryLight, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chi tiết gói • ${widget.bag.bagSerial}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Tổng ${widget.bag.packetCount} gói${widget.bag.packetSerialStart != null ? ' (${widget.bag.packetSerialStart} → ${widget.bag.packetSerialEnd ?? ''})' : ''}',
                        style: const TextStyle(color: kProdOrderTextGray, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: kProdOrderTextGray),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: kProdOrderPrimary),
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _loadPackets,
                        icon: const Icon(Icons.refresh, color: kProdOrderPrimaryLight),
                        label: const Text('Thử lại', style: TextStyle(color: kProdOrderPrimaryLight)),
                      ),
                    ],
                  ),
                ),
              )
            else if (packets.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'Không có dữ liệu chi tiết gói trong bao này.',
                    style: TextStyle(color: kProdOrderTextGray, fontSize: 13),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: packets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, idx) {
                    final pkt = packets[idx];
                    final sColor = _packetStatusColor(pkt.status);
                    final canReplaceThis =
                        widget.canReplace && pkt.status != 'REPLACED';

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: kProdOrderBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundColor: sColor.withValues(alpha: 0.18),
                            child: Text(
                              '${pkt.stt > 0 ? pkt.stt : idx + 1}',
                              style: TextStyle(
                                color: sColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pkt.serial,
                                  style: TextStyle(
                                    color: pkt.status == 'REPLACED'
                                        ? kProdOrderTextGray
                                        : Colors.white,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    decoration: pkt.status == 'REPLACED'
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: sColor.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _packetStatusLabel(pkt.status),
                                        style: TextStyle(
                                          color: sColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (pkt.scannedAt != null) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        formatProdOrderDate(pkt.scannedAt),
                                        style: const TextStyle(
                                          color: kProdOrderTextGray,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (canReplaceThis)
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onTapReplaceSerial(pkt.serial);
                              },
                              icon: const Icon(
                                Icons.swap_horiz,
                                size: 16,
                                color: kProdOrderAmber,
                              ),
                              label: const Text(
                                'Thay',
                                style: TextStyle(
                                  color: kProdOrderAmber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
