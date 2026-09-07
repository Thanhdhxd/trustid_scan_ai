import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:trustid_scan_ai/supply/data/dealer_providers.dart';
import 'package:trustid_scan_ai/supply/data/dealer_repository.dart';
import 'package:trustid_scan_ai/scan/scanner_screen.dart';
import 'widgets/pos_scanner_bar.dart';
import 'widgets/pos_cart_sheet.dart';
import 'widgets/pos_checkout_sheet.dart';

class DealerPosScreen extends ConsumerStatefulWidget {
  const DealerPosScreen({super.key});

  @override
  ConsumerState<DealerPosScreen> createState() => _DealerPosScreenState();
}

class _DealerPosScreenState extends ConsumerState<DealerPosScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(
          title: 'Quét mã Sản phẩm',
          instruction: 'Di chuyển camera đến mã QR hoặc barcode của sản phẩm cần bán',
        ),
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      await _processCode(result);
    }
  }

  Future<void> _processCode(String serial) async {
    try {
      final repo = ref.read(dealerRepositoryProvider);
      final customerState = ref.read(dealerCheckoutProvider);
      final productInfo = await repo.lookupPrice(serial, customerId: customerState.selectedCustomer?['id']?.toString());
      final price = (productInfo['finalPrice'] ?? productInfo['sellingPrice'] ?? productInfo['price'] ?? 0.0) as num;
      final basePrice = (productInfo['basePrice'] ?? productInfo['sellingPrice'] ?? productInfo['price'] ?? 0.0) as num;
      final discountPercent = (productInfo['discountPercent'] ?? 0.0) as num;
      final isBag = productInfo['isBag'] == true;
      final packets = (productInfo['packets'] as List?) ?? [];
      final qrCode = productInfo['qrCode'] ?? serial;
      final resolvedSerial = productInfo['serialNumber'] ?? serial;

      int resolvedQty = 1;
      if (isBag) {
        if (productInfo['bagQuantity'] != null && (productInfo['bagQuantity'] as num).toInt() > 1) {
          resolvedQty = (productInfo['bagQuantity'] as num).toInt();
        } else if (productInfo['bag_quantity'] != null && (productInfo['bag_quantity'] as num).toInt() > 1) {
          resolvedQty = (productInfo['bag_quantity'] as num).toInt();
        } else if (packets.isNotEmpty) {
          resolvedQty = packets.length;
        }
      }

      ref.read(dealerCartProvider.notifier).addItem(
        CartItem(
          serialNumber: resolvedSerial,
          qrCode: qrCode,
          productInfo: productInfo,
          price: price.toDouble(),
          basePrice: basePrice.toDouble(),
          discountPercent: discountPercent.toDouble(),
          isBag: isBag,
          packets: packets,
          quantity: resolvedQty,
        )
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã thêm sản phẩm vào giỏ!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errMsg = e.toString();
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map && data['message'] != null) {
            errMsg = data['message'].toString();
            if (data['errors'] != null) {
              errMsg += '\n${data['errors']}';
            }
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errMsg), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Bán lẻ POS', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1E293B),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blueAccent,
              unselectedLabelColor: Colors.white54,
              indicatorColor: Colors.blueAccent,
              tabs: const [
                Tab(text: 'Giỏ hàng'),
                Tab(text: 'Thanh toán'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                PosCartSheet(
                  onCheckout: () => _tabController.animateTo(1),
                  onOpenScanner: _openScanner,
                ),
                const PosCheckoutSheet(),
              ],
            ),
          )
        ],
      ),
    );
  }
}

