import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/constants/api_constants.dart';
import '../core/theme/trustid_colors.dart';
import '../home/widgets/consumer_theme.dart';
import 'traceability_repository.dart';
import 'risk_repository.dart';
import 'scanner_screen.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final String code;
  final bool fromHistory;

  const ResultScreen({super.key, required this.code, this.fromHistory = false});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

typedef TraceabilityScreen = ResultScreen;

class _ResultScreenState extends ConsumerState<ResultScreen> {
  late Future<Map<String, dynamic>> _dataFuture;
  RiskResult? _risk;
  final _traceRepo = TraceabilityRepository();
  final _riskRepo = RiskRepository();

  // --- UI STATE FOR DESCRIPTION EXPANSION ---
  bool _isDescriptionExpanded = false;
  
  // --- UI STATE FOR MAP LAYER ---
  bool _showSatelliteMap = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadWithLocation();
  }

  Future<Map<String, dynamic>> _loadWithLocation() async {
    // 1. Lấy vị trí GPS thời gian thực (hỗ trợ cả Mobile thực tế lẫn Sensors trong Chrome DevTools)
    double lat = 21.0285;
    double lng = 105.8542;
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 2),
          ),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (_) {
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          lat = lastPos.latitude;
          lng = lastPos.longitude;
        }
      } catch (_) {}
    }

    // 2. Tải song song dữ liệu truy xuất và điểm rủi ro AI
    try {
      final traceFuture = _traceRepo.getPublicTraceability(widget.code);
      final riskFuture = _riskRepo
          .getRiskScore(
            code: widget.code,
            lat: lat,
            long: lng,
          )
          .catchError(
            (_) => RiskResult(
              anomalyScore: 0.0,
              level: 'NORMAL',
              distanceKm: 0.0,
              minutesSincePrev: 0.0,
              scanCount: 1,
            ),
          );

      final results = await Future.wait([traceFuture, riskFuture]);
      if (mounted) {
        setState(() {
          _risk = results[1] as RiskResult;
        });
      }

      final traceData = results[0] as Map<String, dynamic>;

      // 4. Lưu lịch sử quét vào Hive
      if (!widget.fromHistory) {
        _traceRepo.logScan(
          code: widget.code,
          lat: lat ?? 21.0285,
          long: lng ?? 105.8542,
        );

        try {
          final box = Hive.box('scan_history');
          final header = traceData['header_block'] as Map<String, dynamic>?;
          final origin = traceData['origin_block'] as Map<String, dynamic>?;
          box.add({
            'code': widget.code,
            'productName': header?['product_name'] ?? 'Sản phẩm: ',
            'thumbnailUrl': header?['thumbnail_url'],
            'supplierName': origin?['supplier_name'],
            'scanTime': DateTime.now().toIso8601String(),
            'riskLevel': _risk?.level ?? 'NORMAL',
          });
        } catch (_) {}
      }

      return traceData;
    } catch (e) {
      throw Exception(e);
    }
  }

  void _fetchFreshGpsInBackground() {
    Future.microtask(() async {
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return;
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(timeLimit: Duration(seconds: 3)),
          );
        }
      } catch (_) {}
    });
  }

  Widget build(BuildContext context) {
    

    return Scaffold(
      backgroundColor: ConsumerTheme.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Thông tin truy xuất',
          style: TextStyle(color: ConsumerTheme.white),
        ),
        backgroundColor: ConsumerTheme.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ConsumerTheme.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: ConsumerTheme.actionBlue),
            );
          }

          if (snapshot.hasError) {
            final errorStr = snapshot.error.toString();
            final isNotFound = errorStr.contains('không tồn tại') || errorStr.contains('404');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isNotFound ? Icons.warning_amber_rounded : Icons.cloud_off_rounded,
                      color: isNotFound ? Colors.orange : Colors.redAccent,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isNotFound ? 'Không tìm thấy thông tin sản phẩm' : 'Không thể kết nối máy chủ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ConsumerTheme.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isNotFound
                          ? 'Sản phẩm mã:  không tồn tại trên hệ thống\nVui lòng quét mã khác.'
                          : 'Đã xảy ra lỗi khi tải dữ liệu truy xuất từ hệ thống công ty.\n',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ConsumerTheme.textGrey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!isNotFound) ...[
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ConsumerTheme.actionBlue,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Thử lại', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              setState(() {
                                _dataFuture = _loadWithLocation();
                              });
                            },
                          ),
                          const SizedBox(width: 12),
                        ],
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(isNotFound ? 'Quay lại quét mã' : 'Đóng'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
          final data = snapshot.data!;
          final config = data['layout_config'] ?? {};
          final header = data['header_block'];

          return SingleChildScrollView(
            padding: EdgeInsets.all(0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Hero Image
                if (header != null) _buildHeroImage(header),

                // 2. Product Info Card
                if (header != null)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _buildProductInfoCard(header),
                  ),

                // 2.5 AI Risk Assessment Banner
                if (_risk != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildRiskBanner(),
                  ),
                ],

                // 3. Asset Details Table (caretaker, owner, etc.)
                if (header != null && header['asset_details'] != null) ...[
                  SizedBox(height: 12),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _buildAssetDetails(header, header['asset_details']),
                  ),
                ],

                // 3.5 Blockchain Verification Block
                SizedBox(height: 12),
                _buildBlockchainVerification(data),

                // 3.5 Warehouse Info
                if (data['current_warehouse'] != null) ...[
                  SizedBox(height: 12),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _buildWarehouseInfo(data['current_warehouse']),
                  ),
                ],

                // 4. Map Section
                Builder(
                  builder: (context) {
                    Map<String, dynamic>? mapData;
                    String mapTitle = 'ĐỊNH VỊ ĐỊA LÝ GOOGLE MAPS';

                    final warehouse = data['current_warehouse'];
                    final origin = data['origin_block'];

                    // Prioritize current warehouse location if available, otherwise origin/farm location (matches Web portal behavior)
                    final hasWarehouseCoords = warehouse != null &&
                        (warehouse['coordinates'] != null || warehouse['latitude'] != null || warehouse['lat'] != null);
                    final hasOriginCoords = origin != null &&
                        (origin['coordinates'] != null || origin['latitude'] != null || origin['lat'] != null);

                    if (hasWarehouseCoords) {
                      mapData = warehouse as Map<String, dynamic>;
                      final type = mapData['type']?.toString();
                      if (type == 'PRODUCTION') {
                        mapTitle = 'ĐỊNH VỊ ĐỊA LÝ NHÀ MÁY ĐÓNG GÓI';
                      } else if (type == 'DISTRIBUTION') {
                        mapTitle = 'ĐỊNH VỊ ĐỊA LÝ ĐẠI LÝ PHÂN PHỐI';
                      } else {
                        mapTitle = 'ĐỊNH VỊ ĐỊA LÝ KHO LƯU TRỮ';
                      }
                    } else if (hasOriginCoords) {
                      mapData = origin as Map<String, dynamic>;
                      mapTitle = origin['title']?.toString() ?? 'ĐỊNH VỊ ĐỊA LÝ VÙNG TRỒNG';
                    }

                    if (config['show_map'] != false && mapData != null) {
                      return Column(
                        children: [
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildMapSection(
                              mapData,
                              data['scan_locations'] as List?,
                              title: mapTitle,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    }
                    return const SizedBox(height: 16);
                  },
                ),

                if (config['show_alert'] != false && data['alert_block'] != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildAlert(data['alert_block']),
                  ),
                  const SizedBox(height: 16),
                ],

                // 5. Expandable Accordion Sections
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // 1) Hành trình sản phẩm
                      if (config['show_farm_info'] != false && data['journey_steps'] != null)
                        _ExpandableSection(
                          title: 'Hành trình sản phẩm',
                          subtitle: 'Bước hiện tại được đánh dấu nổi bật',
                          initiallyExpanded: true,
                          child: _buildProductJourneySection(data),
                        ),

                      // 2) Nhật ký điện tử
                      if (config['show_farm_info'] != false && data['timeline_block'] != null)
                        Builder(
                          builder: (context) {
                            final allEvents = data['timeline_block'] as List;
                            final farmingEvents = allEvents.where((e) => e['icon_type'] == 'farm').toList();
                            if (farmingEvents.isEmpty) return const SizedBox.shrink();
                            return _ExpandableSection(
                              title: 'Nhật ký điện tử',
                              initiallyExpanded: true,
                              child: _buildTimeline(
                                farmingEvents,
                                title: '',
                                fullData: data,
                              ),
                            );
                          },
                        ),

                      // 3) Đóng gói & phân phối
                      if (config['show_farm_info'] != false && data['timeline_block'] != null)
                        Builder(
                          builder: (context) {
                            final allEvents = data['timeline_block'] as List;
                            final packingEvents = allEvents.where((e) => e['icon_type'] != 'farm').toList();
                            if (packingEvents.isEmpty) return const SizedBox.shrink();
                            return _ExpandableSection(
                              title: 'Đóng gói & phân phối',
                              initiallyExpanded: true,
                              child: _buildTimeline(
                                packingEvents,
                                title: '',
                                fullData: data,
                              ),
                            );
                          },
                        ),

                      // 4) Nguồn gốc
                      if (config['show_farm_info'] != false && (data['origin_block'] != null || data['production_block'] != null))
                        _ExpandableSection(
                          title: 'Nguồn gốc',
                          initiallyExpanded: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (data['origin_block'] != null)
                                _buildOrigin(data['origin_block'], showTitle: false),
                              if (data['origin_block'] != null && data['production_block'] != null)
                                const SizedBox(height: 16),
                              if (data['production_block'] != null)
                                _buildProductionInfo(data['production_block']),
                            ],
                          ),
                        ),

                      // 4.1) Các khối dữ liệu mở rộng (Kiểm định chất lượng, Đặc tính sinh học, Chứng nhận lưu hành, Thông tin đóng gói - Ảnh 2, 3, 4)
                      if (data['custom_blocks'] is List)
                        for (final block in (data['custom_blocks'] as List))
                          if (block is Map && block['fields'] is List && (block['fields'] as List).isNotEmpty)
                            _ExpandableSection(
                              title: block['title']?.toString() ?? '',
                              initiallyExpanded: true,
                              child: _buildCustomBlockGrid(block['fields'] as List),
                            ),

                      // 4.2) Đặc điểm vận hành kỹ thuật (Ảnh 5)
                      if (_hasTechnicalSpecs(data))
                        _ExpandableSection(
                          title: 'Đặc điểm vận hành kỹ thuật',
                          initiallyExpanded: true,
                          child: _buildTechnicalOperationTable(_getTechnicalSpecs(data)),
                        ),

                      // 5) Mô tả sản phẩm
                      if (header != null && header['description'] != null && (header['description'] as String).isNotEmpty)
                        _ExpandableSection(
                          title: 'Mô tả sản phẩm',
                          initiallyExpanded: true,
                          child: _buildArticleSection(header),
                        ),
                    ],
                  ),
                ),

                // 7.5 Product Detail Images (Outside description box)
                if (header != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildProductDetailImagesSection(header),
                  ),

                if (config['show_documents'] != false &&
                    data['document_block'] != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildDocuments(data['document_block'] as List),
                  ),
                  
                // Bottom padding for nav bar
                SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
      // Simulate Bottom Navigation Bar to keep "consistency" and allow quick scan
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: ConsumerTheme.backgroundDark,
          border: Border(
            top: BorderSide(color: ConsumerTheme.actionBlue.withOpacity(0.3)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: 0,
          onTap: (index) async {
            if (index == 0) {
              Navigator.pop(context);
            } else if (index == 1) {
              Navigator.pop(context);
            } else if (index == 2) {
              final result = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => const ScannerScreen(returnCode: true),
                ),
              );
              if (result != null && result.isNotEmpty && mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ResultScreen(code: result),
                  ),
                );
              }
            } else if (index == 3) {
              Navigator.pop(context);
            } else if (index == 4) {
              Navigator.pop(context);
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: ConsumerTheme.backgroundDark,
          selectedItemColor: ConsumerTheme.white.withOpacity(0.5), // Muted
          unselectedItemColor: ConsumerTheme.textGrey,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Trang chủ',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'Lịch sử',
            ),
            BottomNavigationBarItem(
              icon: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: ConsumerTheme.actionBlue,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ConsumerTheme.backgroundDark,
                    width: 6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ConsumerTheme.actionBlue.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.qr_code_scanner,
                  color: ConsumerTheme.textDark,
                  size: 32,
                ),
              ),
              label: '',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag),
              label: 'Cửa hàng',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Tài khoản',
            ),
          ],
        ),
      ),
    );
  }


  String _resolveImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return '';
    String url = rawUrl.trim();

    // Fallback for stringified json arrays (e.g. backend sends '["url"]' instead of 'url')
    if (url.startsWith('[') && url.endsWith(']')) {
      final inner = url.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll("'", "");
      final parts = inner.split(',');
      if (parts.isNotEmpty && parts.first.trim().isNotEmpty) {
        url = parts.first.trim();
      } else {
        return '';
      }
    }

    if (url.startsWith('http')) return Uri.encodeFull(url);
    
    final baseUrl = ApiConstants.baseUrl;
    final cleanUrl = url.startsWith('/') ? url : '/$url';
    return Uri.encodeFull('$baseUrl$cleanUrl');
  }

  Widget _buildHeroImage(Map<String, dynamic> header) {
    final imageUrl = _resolveImageUrl(header['thumbnail_url'] as String?);
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 280,
          color: Colors.grey[900],
          child: imageUrl.isNotEmpty
              ? Image.network(imageUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(child: Icon(Icons.broken_image, color: Colors.white38, size: 48)))
              : Center(child: Icon(Icons.image_not_supported, color: Colors.white38, size: 48)),
        ),
        // Status badge overlay
        if (header['status'] != null)
          Positioned(
            top: 16, right: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _statusColor(header['status']).withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(header['status'], style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ACTIVE': return Colors.green;
      case 'PLANTED': return const Color(0xFF00875A);
      case 'SOLD': return Colors.blue;
      default: return Colors.orange;
    }
  }

  Widget _buildProductInfoCard(Map<String, dynamic> header) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final double price = double.tryParse(header['price']?.toString() ?? '0') ?? 0;
    final priceString = price > 0 ? currencyFormat.format(price) : null;
    final batchCode = header['batch_code'] ?? header['lot_number'] ?? header['lot'] ?? header['batch'];
    final mfgDate = header['manufacture_date'] ?? header['mfg_date'];
    final expDate = header['expiry_date'] ?? header['exp_date'];

    return Container(
      transform: Matrix4.translationValues(0, -30, 0),
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E40),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            header['product_name'] ?? 'Unknown Product',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (header['gtin'] != null && header['gtin'].toString().isNotEmpty)
                _buildInfoBadge(Icons.qr_code, 'GTIN: ${header['gtin']}'),
              if (batchCode != null && batchCode.toString().isNotEmpty)
                _buildInfoBadge(Icons.layers, 'Mã lô: $batchCode'),
              if (header['category_name'] != null && header['category_name'].toString().isNotEmpty)
                _buildInfoBadge(Icons.category, '${header['category_name']}'),
              if (priceString != null)
                _buildInfoBadge(Icons.payments, priceString, color: const Color(0xFF1EC983)),
            ],
          ),
          if (mfgDate != null || expDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (mfgDate != null)
                  Expanded(
                    child: Text('NSX: $mfgDate', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                if (expDate != null)
                  Expanded(
                    child: Text('HSD: $expDate', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
              ],
            ),
          ],
          if (header['short_description'] != null && (header['short_description'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(header['short_description'], style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? ConsumerTheme.actionBlue).withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: (color ?? ConsumerTheme.actionBlue).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color ?? ConsumerTheme.actionBlue),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color ?? ConsumerTheme.actionBlue,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetDetails(Map<String, dynamic> header, Map<String, dynamic> asset) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final double price = double.tryParse(header['price']?.toString() ?? '0') ?? 0;
    final priceString = price > 0 ? currencyFormat.format(price) : 'Liên hệ';
    String? plantedAt;
    if (asset['planted_at'] != null) {
      try { plantedAt = DateFormat('dd/MM/yyyy').format(DateTime.parse(asset['planted_at'])); } catch (_) {}
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thông tin Truy xuất Sản phẩm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ConsumerTheme.actionBlue)),
          Divider(color: Colors.white10),
          if (header['category_name'] != null) _rowDetail('Danh mục', header['category_name']),
          _rowDetail('Giá bán', priceString, isHighlight: true),
          if (asset['caretaker_name'] != null) _rowDetail('Người chăm sóc', asset['caretaker_name']),
          if (asset['owner_name'] != null) _rowDetail('Chủ sở hữu', asset['owner_name']),
          if (plantedAt != null) _rowDetail('Ngày trồng/Gắn mã', plantedAt),
          if (asset['location_lat'] != null) _rowDetail('Tọa độ GPS', '${asset['location_lat']}, ${asset['location_long']}'),
        ],
      ),
    );
  }



  Widget _buildMapSection(
    Map<String, dynamic> origin,
    List? scanLocations, {
    String title = 'ĐỊNH VỊ ĐỊA LÝ GOOGLE MAPS',
  }) {
    String? coordStr = origin['coordinates']?.toString();
    if (coordStr == null || coordStr.isEmpty) {
      if (origin['latitude'] != null && origin['longitude'] != null) {
        coordStr = '${origin['latitude']}, ${origin['longitude']}';
      } else if (origin['lat'] != null && origin['lng'] != null) {
        coordStr = '${origin['lat']}, ${origin['lng']}';
      }
    }
    if (coordStr == null) return const SizedBox.shrink();
    final parts = coordStr.split(',');
    if (parts.length < 2) return const SizedBox.shrink();
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return const SizedBox.shrink();
    final point = LatLng(lat, lng);

    // Parse scan location markers
    final List<Marker> scanMarkers = [];
    if (scanLocations != null) {
      for (final sl in scanLocations) {
        if (sl is Map && sl['lat'] != null && sl['lng'] != null) {
          final sLat = double.tryParse(sl['lat'].toString());
          final sLng = double.tryParse(sl['lng'].toString());
          if (sLat != null && sLng != null) {
            scanMarkers.add(Marker(
              point: LatLng(sLat, sLng),
              width: 32,
              height: 32,
              child: const Icon(Icons.person_pin_circle, color: Color(0xFF00875A), size: 32),
            ));
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: ConsumerTheme.textGrey,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                child: SizedBox(
                  height: 200,
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: point,
                          initialZoom: 16.0,
                          minZoom: 5.0,
                          cameraConstraint: CameraConstraint.contain(
                            bounds: LatLngBounds(
                              const LatLng(8.0, 102.0),
                              const LatLng(23.5, 109.5),
                            ),
                          ),
                          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: _showSatelliteMap
                                ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                                : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                            userAgentPackageName: 'zps.trustid.com.vn',
                            maxZoom: 22,
                            maxNativeZoom: 20,
                          ),
                          MarkerLayer(markers: [
                            Marker(point: point, width: 40, height: 40, child: Icon(Icons.location_on, color: Colors.redAccent, size: 40)),
                          ]),
                        ],
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: ConsumerTheme.backgroundDark.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: IconButton(
                            icon: Icon(
                              _showSatelliteMap ? Icons.map : Icons.satellite_alt,
                              color: ConsumerTheme.actionBlue,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _showSatelliteMap = !_showSatelliteMap;
                              });
                            },
                            tooltip: _showSatelliteMap ? 'Bản đồ đường phố' : 'Bản đồ vệ tinh',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, color: Color(0xFF1EC983), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tọa độ vệ tinh:  $lat, $lng',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArticleSection(Map<String, dynamic> header) {
    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mô tả sản phẩm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ConsumerTheme.actionBlue)),
          SizedBox(height: 8),
          _isDescriptionExpanded
              ? HtmlWidget(
                  header['description'], 
                  textStyle: TextStyle(color: Colors.white70, height: 1.5),
                  customStylesBuilder: (element) {
                    return {'color': 'white', 'background-color': 'transparent'};
                  },
                )
              : Container(
                  height: 120,
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(),
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) => LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.white, Colors.white.withOpacity(0)],
                      stops: [0.6, 1.0],
                    ).createShader(bounds),
                    blendMode: BlendMode.dstIn,
                    child: SingleChildScrollView(
                      physics: NeverScrollableScrollPhysics(),
                      child: HtmlWidget(
                        header['description'], 
                        textStyle: TextStyle(color: Colors.white70, height: 1.5),
                        customStylesBuilder: (element) {
                          return {'color': 'white', 'background-color': 'transparent'};
                        },
                      ),
                    ),
                  ),
                ),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(_isDescriptionExpanded ? 'Thu gọn' : 'Xem thêm',
                    style: TextStyle(color: ConsumerTheme.actionBlue, fontStyle: FontStyle.italic, decoration: TextDecoration.underline)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductDetailImagesSection(Map<String, dynamic> header) {
    // Parse list of images from header
    final List<String> imageUrls = [];
    void addImages(dynamic raw) {
      if (raw == null) return;
      if (raw is List) {
        for (var item in raw) {
          if (item != null && item.toString().isNotEmpty) {
            imageUrls.add(item.toString());
          }
        }
      } else if (raw is String) {
        final str = raw.trim();
        if (str.startsWith('[') && str.endsWith(']')) {
          final inner = str.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll("'", "");
          final parts = inner.split(',');
          for (var p in parts) {
            if (p.trim().isNotEmpty) imageUrls.add(p.trim());
          }
        } else if (str.isNotEmpty) {
          imageUrls.add(str);
        }
      }
    }

    addImages(header['images']);
    addImages(header['product_images']);
    if (header['product'] is Map) {
      addImages(header['product']['images']);
    }

    if (imageUrls.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HÌNH ẢNH CHI TIẾT SẢN PHẨM',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: ConsumerTheme.textGrey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: imageUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final url = _resolveImageUrl(imageUrls[index]);
                if (url.isEmpty) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => Dialog(
                        backgroundColor: Colors.transparent,
                        child: InteractiveViewer(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(url, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      url,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 120,
                        height: 120,
                        color: Colors.white10,
                        child: const Icon(Icons.broken_image, color: Colors.white24),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductJourneySection(Map<String, dynamic> data) {
    final steps = data['journey_steps'] as List? ?? [];
    if (steps.isEmpty) return const SizedBox.shrink();

    int currentStepIndex = -1;
    for (int i = 0; i < steps.length; i++) {
      final s = steps[i];
      if (s is Map && (s['status'] == 'in_progress' || s['status'] == 'current')) {
        currentStepIndex = i;
        break;
      }
    }

    if (currentStepIndex == -1) {
      int lastCompletedIndex = -1;
      for (int i = 0; i < steps.length; i++) {
        final s = steps[i];
        if (s is Map && s['status'] == 'completed') {
          lastCompletedIndex = i;
        }
      }
      if (lastCompletedIndex >= 0 && lastCompletedIndex + 1 < steps.length) {
        currentStepIndex = lastCompletedIndex + 1;
      } else if (lastCompletedIndex == steps.length - 1) {
        currentStepIndex = lastCompletedIndex;
      } else {
        currentStepIndex = 0;
      }
    }

    final stages = <_JourneyStage>[];
    for (int i = 0; i < steps.length; i++) {
      final s = steps[i];
      if (s is! Map) continue;

      final key = s['key']?.toString() ?? '';
      final title = s['title']?.toString() ?? '';
      final statusStr = s['status']?.toString() ?? '';
      final timeStr = s['time']?.toString() ?? '';
      final description = s['description']?.toString() ?? '';

      IconData icon = Icons.circle;
      if (key == 'planting') icon = Icons.grass;
      else if (key == 'care') icon = Icons.spa;
      else if (key == 'harvest') icon = Icons.agriculture;
      else if (key == 'semi_finished_packaging' || key == 'packaging') icon = Icons.inventory_2;
      else if (key == 'finished_packaging') icon = Icons.inventory_2;
      else if (key == 'dealer_distribution' || key == 'distribution') icon = Icons.local_shipping;

      String dateFormatted = '';
      if (timeStr.isNotEmpty) {
        try {
          dateFormatted = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(timeStr).toLocal());
        } catch (_) {}
      }

      final isCompleted = statusStr == 'completed';
      final isCurrent = (i == currentStepIndex && !isCompleted);

      stages.add(_JourneyStage(
        title: title,
        subtitle: description,
        date: dateFormatted,
        isCompleted: isCompleted,
        isCurrent: isCurrent,
        icon: icon,
      ));
    }

    if (stages.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
            children: List.generate(stages.length, (index) {
              final stage = stages[index];
              final isLast = index == stages.length - 1;

              Color stateColor = Colors.white.withOpacity(0.05);
              Color iconColor = Colors.white30;
              Color borderColor = Colors.white24;
              Widget stateIcon = Icon(stage.icon, size: 18, color: iconColor);
              String stateText = 'Chưa bắt đầu';
              Color stateTextColor = Colors.white38;

              if (stage.isCompleted) {
                stateColor = const Color(0xFF064E3B).withOpacity(0.5);
                iconColor = const Color(0xFF10B981);
                borderColor = const Color(0xFF059669);
                stateIcon = const Icon(Icons.check, size: 18, color: Color(0xFF10B981));
                stateText = 'Hoàn thành';
                stateTextColor = Colors.white54;
              } else if (stage.isCurrent) {
                stateColor = const Color(0xFF78350F).withOpacity(0.3);
                iconColor = const Color(0xFFEAB308);
                borderColor = const Color(0xFFEAB308);
                stateIcon = const Icon(Icons.priority_high, size: 18, color: Color(0xFFEAB308));
                stateText = 'Hiện tại';
                stateTextColor = const Color(0xFFEAB308);
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: stateColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: borderColor,
                            width: 2,
                          ),
                        ),
                        child: Center(child: stateIcon),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 56,
                          color: stage.isCompleted && stages[index + 1].isCompleted 
                              ? const Color(0xFF059669) 
                              : Colors.white12,
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: stage.isCurrent 
                            ? const Color(0xFF1E293B) 
                            : Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: stage.isCurrent 
                              ? const Color(0xFFEAB308).withOpacity(0.5) 
                              : Colors.white.withOpacity(0.05),
                          width: stage.isCurrent ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  stage.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                    color: (stage.isCompleted || stage.isCurrent) ? Colors.white : Colors.white38,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                stateText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: stateTextColor,
                                  fontWeight: stage.isCurrent ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          if (stage.date.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              stage.date,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (stage.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              stage.subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: (stage.isCompleted || stage.isCurrent) ? Colors.white70 : Colors.white38,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        );
  }

  Widget _buildCustomBlockGrid(List fields) {
    final validFields = fields.where((f) => f is Map).toList();
    if (validFields.isEmpty) return const SizedBox.shrink();

    // Nhóm các trường thành từng cặp 2 cột
    final rows = <List>[];
    for (int i = 0; i < validFields.length; i += 2) {
      final pair = [validFields[i]];
      if (i + 1 < validFields.length) {
        pair.add(validFields[i + 1]);
      }
      rows.add(pair);
    }

    return Column(
      children: List.generate(rows.length, (rowIndex) {
        final pair = rows[rowIndex];
        final isLastRow = rowIndex == rows.length - 1;

        Widget buildItem(Map f) {
          final key = f['key']?.toString() ?? f['label']?.toString() ?? '';
          final value = f['value']?.toString() ?? '';

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  key.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: isLastRow ? 0 : 12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: buildItem(pair[0]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: pair.length > 1
                      ? buildItem(pair[1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  bool _hasTechnicalSpecs(Map<String, dynamic> data) {
    return _getTechnicalSpecs(data).isNotEmpty;
  }

  Map<String, String> _getTechnicalSpecs(Map<String, dynamic> data) {
    final specs = <String, String>{};

    // Extract from v2 custom_fields (List of {label, value})
    final v2Fields = (data['custom_fields'] is List ? data['custom_fields'] : null) ?? data['v2_custom_fields'];
    if (v2Fields is List) {
      for (final item in v2Fields) {
        if (item is Map) {
          final label = item['label']?.toString() ?? '';
          final value = item['value']?.toString() ?? '';
          if (value.isNotEmpty) {
            if (label == 'seedOwner') specs['Chủ hạt giống'] = value;
            else if (label == 'plantingDate') {
              try {
                specs['Ngày gieo trồng'] = DateFormat('dd/MM/yyyy').format(DateTime.parse(value).toLocal());
              } catch (_) {
                specs['Ngày gieo trồng'] = value;
              }
            } else if (label == 'seedBatchCode') specs['Mã lô hạt giống'] = value;
            else if (label == 'packaging_date') {
              try {
                specs['Ngày đóng gói'] = DateFormat('dd/MM/yyyy').format(DateTime.parse(value).toLocal());
              } catch (_) {
                specs['Ngày đóng gói'] = value;
              }
            } else if (label == 'processingUnit') specs['Nhà máy chế biến'] = value;
            else if (label == 'production_address') specs['Địa chỉ sản xuất'] = value;
          }
        }
      }
    }

    // Fallback / supplement from custom_fields
    if (!specs.containsKey('Ngày gieo trồng') && data['custom_fields'] is Map && data['custom_fields']['plantingDate'] != null) {
      final val = data['custom_fields']['plantingDate'].toString();
      try {
        specs['Ngày gieo trồng'] = DateFormat('dd/MM/yyyy').format(DateTime.parse(val).toLocal());
      } catch (_) {
        specs['Ngày gieo trồng'] = val;
      }
    }
    if (!specs.containsKey('Ngày đóng gói') && data['custom_fields'] is Map && data['custom_fields']['packaging_date'] != null) {
      final val = data['custom_fields']['packaging_date'].toString();
      try {
        specs['Ngày đóng gói'] = DateFormat('dd/MM/yyyy').format(DateTime.parse(val).toLocal());
      } catch (_) {
        specs['Ngày đóng gói'] = val;
      }
    }
    if (!specs.containsKey('Mã lô hạt giống') && data['custom_fields'] is Map && data['custom_fields']['seedBatchCode'] != null) {
      specs['Mã lô hạt giống'] = data['custom_fields']['seedBatchCode'].toString();
    }
    if (!specs.containsKey('Chủ hạt giống') && data['custom_fields'] is Map && data['custom_fields']['seedOwner'] != null) {
      specs['Chủ hạt giống'] = data['custom_fields']['seedOwner'].toString();
    }
    if (!specs.containsKey('Nhà máy chế biến') && data['custom_fields'] is Map && data['custom_fields']['processingUnit'] != null) {
      specs['Nhà máy chế biến'] = data['custom_fields']['processingUnit'].toString();
    }
    if (!specs.containsKey('Địa chỉ sản xuất') && data['custom_fields'] is Map && data['custom_fields']['production_address'] != null) {
      specs['Địa chỉ sản xuất'] = data['custom_fields']['production_address'].toString();
    }

    return specs;
  }

  Widget _buildTechnicalOperationTable(Map<String, String> specs) {
    final entries = specs.entries.toList();
    return Column(
      children: List.generate(entries.length, (index) {
        final entry = entries[index];
        final isLast = index == entries.length - 1;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    entry.value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (!isLast)
              Divider(color: Colors.white.withOpacity(0.08), height: 1),
          ],
        );
      }),
    );
  }

  Widget _rowDetail(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: ConsumerTheme.textGrey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                color: isHighlight
                    ? ConsumerTheme.actionBlue
                    : ConsumerTheme.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrigin(Map<String, dynamic> origin, {bool showTitle = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            'THÔNG TIN NGUỒN GỐC',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: ConsumerTheme.textGrey,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 12),
        ],
        // Enterprise Card
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.business, color: ConsumerTheme.actionBlue, size: 16),
                  SizedBox(width: 8),
                  Text('Nhà cung cấp', style: TextStyle(color: ConsumerTheme.textGrey, fontSize: 13)),
                ],
              ),
              SizedBox(height: 8),
              Text(
                origin['supplier_name'] ?? 'N/A',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
            ],
          ),
        ),
        // Show farm zone card ONLY if farm_zone data exists from API
        if (origin['farm_zone'] != null)
          ...[
            SizedBox(height: 12),
            // Farm Zone Card (clickable)
            GestureDetector(
              onTap: () => _showFarmZoneSheet(context, origin),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.orange, size: 16),
                        SizedBox(width: 8),
                        Text('Vùng trồng', style: TextStyle(color: ConsumerTheme.textGrey, fontSize: 13)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      origin['location_name']?.toString() ?? 'Chưa có thông tin',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Bấm để xem thông tin chi tiết và bản đồ vùng trồng →',
                      style: TextStyle(color: ConsumerTheme.actionBlue, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
          ],
      ],
    );
  }

  void _showFarmZoneSheet(BuildContext ctx, Map<String, dynamic> origin) {
    final farmZone = origin['farm_zone'] as Map<String, dynamic>?;
    
    // Parse coordinates for the map center — ONLY from API data, no fallback
    LatLng? center;
    final coordStr = origin['coordinates'] as String?;
    if (coordStr != null && coordStr.isNotEmpty) {
      final parts = coordStr.split(',');
      if (parts.length >= 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat != null && lng != null) center = LatLng(lat, lng);
      }
    }

    // Parse boundary polygon (GeoJSON)
    List<LatLng> polygonPoints = [];
    if (farmZone != null && farmZone['boundary'] != null) {
      try {
        final boundary = farmZone['boundary'];
        // Handle both direct GeoJSON or nested coordinates
        var coords = boundary['coordinates'];
        
        // PostGIS/TypeORM sometimes returns coordinates nested 
        // e.g. [[[lng, lat], ...]]
        if (coords != null && coords is List && coords.isNotEmpty) {
          final firstLevel = coords[0];
          if (firstLevel is List && firstLevel.isNotEmpty) {
            // Check if it's the [[[lng, lat]]] deep nesting
            final pointsSource = (firstLevel[0] is List) ? firstLevel : coords;
            
            for (final p in pointsSource) {
              if (p is List && p.length >= 2) {
                polygonPoints.add(LatLng(
                  (p[1] as num).toDouble(), 
                  (p[0] as num).toDouble(),
                ));
              }
            }
          }
        }
      } catch (e) {
        print('Error parsing farm zone polygon: $e');
      }
    }

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Color(0xFF0F2B46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)))),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Thông tin Vùng trồng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.close, color: Colors.white70, size: 20),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Map with polygon
              if (center != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.only(top: 8),
                    height: 300,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: center, 
                        initialZoom: polygonPoints.isNotEmpty ? 17 : 16,
                        minZoom: 5.0,
                        cameraConstraint: CameraConstraint.contain(
                          bounds: LatLngBounds(
                            const LatLng(8.0, 102.0),
                            const LatLng(23.5, 109.5),
                          ),
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                          userAgentPackageName: 'zps.trustid.com.vn',
                          maxZoom: 22,
                          maxNativeZoom: 20,
                        ),
                        if (polygonPoints.isNotEmpty)
                          PolygonLayer<Object>(polygons: [
                            Polygon<Object>(
                              points: polygonPoints,
                              color: ConsumerTheme.actionBlue.withOpacity(0.25),
                              borderColor: ConsumerTheme.actionBlue,
                              borderStrokeWidth: 2.5,
                            ),
                          ]),
                        MarkerLayer(markers: [
                          Marker(point: center, width: 40, height: 40, child: Icon(Icons.location_on, color: Colors.redAccent, size: 40)),
                        ]),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: 16),

              // Details — ONLY show rows where data exists from API
              if (farmZone?['name'] != null || origin['location_name'] != null)
                _sheetRow('Tên vùng', (farmZone?['name'] ?? origin['location_name']).toString()),
              if (farmZone?['address'] != null || farmZone?['ward'] != null || farmZone?['province'] != null)
                _sheetRow('Địa chỉ', () {
                  final addr = farmZone?['address']?.toString();
                  final ward = farmZone?['ward']?.toString();
                  final province = farmZone?['province']?.toString();
                  if (addr != null && addr.isNotEmpty) {
                    // Append ward/province if not already in address
                    final parts = [addr];
                    if (ward != null && !addr.contains(ward)) parts.add(ward);
                    if (province != null && !addr.contains(province)) parts.add(province);
                    return parts.join(', ');
                  }
                  return [ward, province].where((e) => e != null && e.isNotEmpty).join(', ');
                }()),
              if (farmZone?['area_m2'] != null)
                _sheetRow('Diện tích', '${NumberFormat('#,###', 'vi_VN').format((farmZone!['area_m2'] is num) ? farmZone!['area_m2'] : num.tryParse(farmZone!['area_m2'].toString()) ?? 0)} m²'),
              if (farmZone?['manager_name'] != null)
                _sheetRow('Người quản lý', farmZone!['manager_name'].toString()),
              if (farmZone?['plant_type'] != null)
                _sheetRow('Loại cây trồng', farmZone!['plant_type'].toString()),
              if (origin['supplier_name'] != null)
                _sheetRow('Doanh nghiệp', origin['supplier_name'].toString()),
              // If no details exist at all, show a message
              if (farmZone == null)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Chưa có thông tin vùng trồng', style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
                ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: TextStyle(color: ConsumerTheme.textGrey, fontSize: 13))),
          Expanded(child: Text(value, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildProductionInfo(Map<String, dynamic> production) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A3323), // Darker green
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ConsumerTheme.actionBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.spa, color: ConsumerTheme.actionBlue, size: 20),
              SizedBox(width: 8),
              Text(
                "Lô sản xuất",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: ConsumerTheme.actionBlue,
                ),
              ),
            ],
          ),
          Divider(color: Colors.white10),
          _rowDetail('Mã lô', production['farm_batch_code'] ?? 'N/A'),
          _rowDetail(
            'Ngày thu hoạch',
            production['harvest_date'] != null
                ? DateFormat(
                    'dd/MM/yyyy',
                  ).format(DateTime.parse(production['harvest_date']))
                : 'N/A',
          ),
          _rowDetail('Sản lượng', '${production['quantity']} kg'),
        ],
      ),
    );
  }

  Widget _buildTimeline(List<dynamic> events, {String title = 'Lịch sử chăm sóc', Map<String, dynamic>? fullData}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: ConsumerTheme.textGrey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
        ],
        ...events.map((e) {
          IconData icon = Icons.circle;
          Color color = Colors.grey;
          if (e['icon_type'] == 'farm') { icon = Icons.grass; color = Colors.green; }
          else if (e['icon_type'] == 'harvest') { icon = Icons.agriculture; color = Colors.orange; }
          else if (e['icon_type'] == 'activate') { icon = Icons.check_circle; color = Colors.blue; }
          else if (e['icon_type'] == 'truck') { icon = Icons.local_shipping; color = Colors.cyan; }
          else if (e['icon_type'] == 'warehouse') { icon = Icons.warehouse; color = Colors.teal; }
          else if (e['icon_type'] == 'cart') { icon = Icons.shopping_cart; color = Colors.purple; }

          final images = (e['images'] as List? ?? []).cast<String>();

          // Extract coordinate data if available
          double? lat;
          double? lng;
          if (e['latitude'] != null && e['longitude'] != null) {
            lat = double.tryParse(e['latitude'].toString());
            lng = double.tryParse(e['longitude'].toString());
          } else if (e['lat'] != null && e['lng'] != null) {
            lat = double.tryParse(e['lat'].toString());
            lng = double.tryParse(e['lng'].toString());
          } else if (e['coordinates'] != null) {
            final coords = e['coordinates'].toString().split(',');
            if (coords.length == 2) {
              lat = double.tryParse(coords[0].trim());
              lng = double.tryParse(coords[1].trim());
            }
          }

          // Fallback to match current_warehouse coordinate
          if (lat == null || lng == null) {
            if (fullData != null && fullData['current_warehouse'] != null) {
              final wh = fullData['current_warehouse'] as Map<String, dynamic>;
              final whName = wh['name']?.toString() ?? '';
              final desc = e['description']?.toString() ?? '';
              if (whName.isNotEmpty && desc.contains(whName) && wh['coordinates'] != null) {
                final coords = wh['coordinates'].toString().split(',');
                if (coords.length == 2) {
                  lat = double.tryParse(coords[0].trim());
                  lng = double.tryParse(coords[1].trim());
                }
              }
            }
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: color, width: 1.5)),
                      child: Icon(icon, size: 16, color: color),
                    ),
                    Container(width: 2, height: images.isNotEmpty ? 120 : 50, color: Colors.white10),
                  ],
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(e['title'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                            ),
                            if (lat != null && lng != null)
                              GestureDetector(
                                onTap: () => _launchExternalUrl('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: ConsumerTheme.actionBlue.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: ConsumerTheme.actionBlue.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.location_on, color: ConsumerTheme.actionBlue, size: 12),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Bản đồ',
                                        style: TextStyle(
                                          color: ConsumerTheme.actionBlue,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          e['time'] != null 
                              ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(e['time'].toString()).toLocal()) 
                              : '',
                          style: TextStyle(color: ConsumerTheme.textGrey, fontSize: 12),
                        ),
                        if (e['description'] != null && (e['description'] as String).isNotEmpty) ...[
                          SizedBox(height: 4),
                          Text(e['description'], style: TextStyle(color: Colors.white60, fontSize: 13)),
                        ],
                        if (images.isNotEmpty) ...[
                          SizedBox(height: 8),
                          SizedBox(
                            height: 80,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: images.length,
                              separatorBuilder: (_, __) => SizedBox(width: 8),
                              itemBuilder: (_, i) => ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _resolveImageUrl(images[i]),
                                  width: 100, height: 80, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(width: 100, height: 80, color: Colors.grey[800], child: Icon(Icons.broken_image, color: Colors.white38)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAlert(Map<String, dynamic> alert) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.red),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              alert['recall_reason'] ?? "Cảnh báo sản phẩm",
              style: TextStyle(color: Colors.red[200]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarehouseInfo(Map<String, dynamic> warehouse) {
    String typeLabel = warehouse['type'] ?? 'N/A';
    if (typeLabel == 'PRODUCTION') typeLabel = 'Nhà máy đóng gói';
    else if (typeLabel == 'STORAGE') typeLabel = 'Kho lưu trữ';
    else if (typeLabel == 'DISTRIBUTION') typeLabel = 'Kho phân phối';

    String statusLabel = warehouse['status'] ?? 'N/A';
    if (statusLabel == 'ACTIVE') statusLabel = 'Đang vận hành';
    else if (statusLabel == 'INACTIVE') statusLabel = 'Ngừng hoạt động';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'THÔNG TIN LƯU KHO',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: ConsumerTheme.textGrey,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            children: [
              // Trạm lưu trữ hiện tại
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: ConsumerTheme.actionBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.inventory_2, color: ConsumerTheme.actionBlue, size: 24),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TRẠM LƯU TRỮ HIỆN TẠI', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text(warehouse['name'] ?? '', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        SizedBox(height: 2),
                        Text(warehouse['address'] ?? '', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  )
                ],
              ),
              SizedBox(height: 16),
              // Phân loại & Trạng thái
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PHÂN LOẠI KHO', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                          SizedBox(height: 6),
                          Text(typeLabel, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TRẠNG THÁI KHO', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                          SizedBox(height: 6),
                          Row(
                            children: [
                              if (warehouse['status'] == 'ACTIVE') ...[
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: Color(0xFF1EC983), shape: BoxShape.circle)),
                                SizedBox(width: 6),
                              ],
                              Text(statusLabel, style: TextStyle(color: Color(0xFF1EC983), fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocuments(List<dynamic> docs) {
    if (docs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          "TÀI LIỆU CHỨNG NHẬN",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: ConsumerTheme.textGrey,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        ...docs.map(
          (d) {
            final rawUrl = d['url'] ?? d['file_url'] ?? d['link'] ?? d['path'] ?? d['file'] ?? '';
            final fullUrl = _resolveImageUrl(rawUrl?.toString());
            return Card(
              color: Colors.white.withOpacity(0.08),
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.description, color: Colors.orange, size: 24),
                ),
                title: Text(
                  d['name'] ?? d['title'] ?? 'Tài liệu chứng nhận',
                  style: const TextStyle(color: ConsumerTheme.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: (d['type'] != null || d['size'] != null)
                    ? Text(
                        '${d['type'] ?? ''} ${d['size'] != null ? '• ${d['size']}' : ''}'.trim(),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      )
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.open_in_new, color: ConsumerTheme.actionBlue),
                  onPressed: () => _openDocument(fullUrl),
                ),
                onTap: () => _openDocument(fullUrl),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _launchExternalUrl(String urlString) async {
    if (urlString.isEmpty) return;
    String cleanUrl = urlString.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }
    final uri = Uri.tryParse(cleanUrl);
    if (uri == null) return;

    try {
      if (kIsWeb) {
        await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_blank',
        );
      } else {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
      }
    } catch (e) {
      debugPrint('Error launching url $cleanUrl: $e');
      try {
        await launchUrl(uri);
      } catch (_) {}
    }
  }

  Future<void> _openDocument(String fullUrl) async {
    if (fullUrl.isNotEmpty) {
      await _launchExternalUrl(fullUrl);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy liên kết file tài liệu')),
        );
      }
    }
  }

  Widget _buildBlockchainVerification(Map<String, dynamic> data) {
    final blockData = data['blockchain_block'];
    if (blockData == null) return const SizedBox.shrink();
    
    final polyData = blockData['polygon'] ?? blockData;
    
    String txHash = polyData['tx_hash']?.toString() ?? polyData['transaction_hash']?.toString() ?? polyData['hash']?.toString() ?? '';
    if (txHash.isEmpty) return const SizedBox.shrink();

    String blockIndex = polyData['block_number']?.toString() ?? polyData['block_index']?.toString() ?? 'N/A';
    if (blockIndex != 'N/A' && !blockIndex.startsWith('#')) blockIndex = '#$blockIndex';
    
    String timeStamp = polyData['stamped_at']?.toString() ?? polyData['timestamp']?.toString() ?? '';
    if (timeStamp.isNotEmpty) {
      try {
        final dt = DateTime.parse(timeStamp).toLocal();
        timeStamp = DateFormat('dd/MM/yyyy HH:mm').format(dt);
      } catch (_) {}
    } else {
      timeStamp = 'N/A';
    }

    String groupCode = polyData['group_code']?.toString() ?? 'N/A';
    String merkleLeaf = polyData['merkle_leaf']?.toString() ?? 'N/A';
    String ipfsCid = polyData['ipfs_cid']?.toString() ?? 'N/A';
    String polygonscanUrl = polyData['polygonscan_url']?.toString() ?? 'https://polygonscan.com/tx/$txHash';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CHỨNG NHẬN SỔ CHUỖI KHỐI (BLOCKCHAIN)',
            style: TextStyle(color: ConsumerTheme.textGrey, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0C3827), Color(0xFF062215)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('XÁC THỰC CHUỖI KHỐI', style: TextStyle(color: Color(0xFF1EC983), fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text('TrustID Blockchain Stamp', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05), 
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.dns, color: Colors.white70, size: 20),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Mạng lưới', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Row(
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF1EC983), shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        const Text('Polygon Network', style: TextStyle(color: Color(0xFF1EC983), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Trạng thái xác thực', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.transparent, 
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF1EC983)),
                      ),
                      child: const Text('ĐÃ ĐÓNG DẤU', style: TextStyle(color: Color(0xFF1EC983), fontSize: 9, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF061E14), borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TRANSACTION HASH', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                          GestureDetector(
                            onTap: () => _launchExternalUrl(polygonscanUrl),
                            child: Row(
                              children: const [
                                Text('POLYGONSCAN', style: TextStyle(color: Color(0xFF1EC983), fontSize: 9, fontWeight: FontWeight.bold)),
                                SizedBox(width: 4),
                                Icon(Icons.open_in_new, color: Color(0xFF1EC983), size: 10),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(txHash, style: const TextStyle(color: Color(0xFF1EC983), fontSize: 10.5, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF061E14), borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('BLOCK INDEX', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(blockIndex, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF061E14), borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('THỜI GIAN ĐÓNG', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(timeStamp, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF061E14), borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MÃ NHÓM (GROUP CODE)', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(groupCode, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF061E14), borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MERKLE LEAF', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(merkleLeaf, style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF061E14), borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('IPFS CID (CHỮ KÝ DỮ LIỆU)', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(ipfsCid, style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Nút xem chi tiết giao dịch trên PolygonScan Explorer
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      String targetUrl = polygonscanUrl.trim();
                      if (!targetUrl.startsWith('http')) {
                        targetUrl = 'https://polygonscan.com/tx/$targetUrl';
                      }
                      _launchExternalUrl(targetUrl);
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF033E2B).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0xFF00D68F).withOpacity(0.4),
                          width: 1.2,
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'Xem chi tiết giao dịch trên PolygonScan Explorer',
                              style: TextStyle(
                                color: Color(0xFF38E5A1),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(
                              Icons.open_in_new,
                              color: Color(0xFF38E5A1),
                              size: 15,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Color _colorFor(String level) => switch (level) {
        'HIGH_RISK' => Colors.redAccent,
        'WATCH' => Colors.orangeAccent,
        _ => const Color(0xFF00C853),
      };

  String _titleFor(String level) => switch (level) {
        'HIGH_RISK' => 'CẢNH BÁO RỦI RO CAO',
        'WATCH' => 'CẦN THEO DÕI',
        _ => 'AN TOÀN',
      };

  Widget _buildRiskBanner() {
    final risk = _risk!;
    final color = _colorFor(risk.level);
    final icon = risk.level == 'HIGH_RISK'
        ? Icons.warning_rounded
        : risk.level == 'WATCH'
            ? Icons.info_outline
            : Icons.verified_user_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.45), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleFor(risk.level),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hệ thống AI phát hiện bất thường hành vi quét (Isolation Forest)',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            risk.level == 'HIGH_RISK'
                ? 'Phát hiện rủi ro quét bất thường (Điểm rủi ro: )'
                : risk.level == 'WATCH'
                    ? 'Cần chú ý theo dõi hành vi quét (Điểm rủi ro: )'
                    : 'Mã quét được xác thực an toàn. Không phát hiện hành vi quét gian lận.',
            style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildRiskPill(Icons.qr_code, 'Lượt quét: '),
              if (risk.distanceKm > 0)
                _buildRiskPill(Icons.navigation_outlined, 'Khoảng cách:  km'),
              if (risk.minutesSincePrev > 0)
                _buildRiskPill(Icons.schedule, 'Cách lần trước:  phút'),
            ],
          ),
          if (risk.reasons.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chi tiết cảnh báo:', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  ...risk.reasons.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                            Expanded(child: Text(r, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4))),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRiskPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

}

class _JourneyStage {
  final String title;
  final String subtitle;
  final String date;
  final bool isCompleted;
  final bool isCurrent;
  final IconData icon;

  _JourneyStage({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.isCompleted,
    required this.isCurrent,
    required this.icon,
  });
}

class _ExpandableSection extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final bool initiallyExpanded;

  const _ExpandableSection({
    required this.title,
    this.subtitle,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16325B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: widget.child,
            ),
          ],
        ],
      ),
    );
  }
}
