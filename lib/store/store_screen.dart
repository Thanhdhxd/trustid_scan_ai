import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../core/api_client.dart';
import '../scan/result_screen.dart';
import '../home/widgets/consumer_theme.dart';

class ModernTopHeader extends StatelessWidget {
  const ModernTopHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo
          Expanded(
            child: Container(
              alignment: Alignment.centerLeft,
              child: const Text(
                'TrustID',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Action Buttons
          Row(
            children: [
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2738), // Dark blueish
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_none,
                        color: Colors.white,
                        size: 24,
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: const Text(
                            '1',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  
  const SectionHeader({super.key, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white, // kHeaderColor
              letterSpacing: -0.5,
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Text(
                'Xem tất cả',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: ConsumerTheme.actionBlue,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  bool _isLoading = true;
  String? _error;
  
  List<dynamic> _banners = [];
  List<dynamic> _partners = [];
  List<dynamic> _categories = [];
  
  int _currentBannerIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchStoreData();
  }

  dynamic _parseData(dynamic data) {
    if (data is String) {
      try {
        return jsonDecode(data);
      } catch (_) {}
    }
    return data;
  }

  Future<void> _fetchStoreData() async {
    try {
      final results = await Future.wait([
        companyApi.get('/api/home-stats'),
        companyApi.get('/consumer/partners/top'),
        companyApi.get('/consumer/products/grouped-by-category'),
      ]);

      if (!mounted) return;

      setState(() {
        // Parse Banners
        final statsData = _parseData(results[0].data);
        if (statsData is Map && statsData['appBanners'] != null) {
          _banners = List.from(statsData['appBanners']);
        }
        if (_banners.isEmpty) {
          _banners = [
            'https://api.trustid.com.vn/uploads/users/admin/san-pham/afa54f52-734e-4df4-9a23-0c479114e845.png',
            'https://api.trustid.com.vn/uploads/users/admin/san-pham/1cf4962e-2bc6-4ceb-a6a8-d944091f12f7.png',
            'https://api.trustid.com.vn/uploads/users/admin/san-pham/05d2a73d-33d2-483e-92e7-43ca5eca748b.png',
          ];
        }

        // Parse Partners
        final partnersData = _parseData(results[1].data);
        if (partnersData is List) {
          _partners = partnersData;
        } else if (partnersData is Map) {
          _partners = partnersData['data'] ?? [];
        }

        // Parse Categories
        final categoriesData = _parseData(results[2].data);
        if (categoriesData is List) {
          _categories = categoriesData;
        } else if (categoriesData is Map) {
          _categories = categoriesData['data'] ?? [];
        }

        _isLoading = false;
      });
      
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Không thể kết nối máy chủ: ${e.message}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Đã xảy ra lỗi hệ thống';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ConsumerTheme.backgroundDark,
      body: RefreshIndicator(
        onRefresh: _fetchStoreData,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // --- 0. TOP HEADER ---
            const SliverToBoxAdapter(child: SafeArea(child: ModernTopHeader())),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: ConsumerTheme.actionBlue)),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))),
              )
            else ...[
              
              // 1. SLIDING BANNER
              SliverToBoxAdapter(child: _buildBannerSlider()),
              
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              
              // 2. ENTERPRISES BLOCK
              if (_partners.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Doanh Nghiệp Tiêu Biểu',
                    onSeeAll: () {},
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 140, // Vừa đủ 1 dòng
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _partners.map((p) => _buildPartnerItem(p)).toList(),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
              
              // 3. CATEGORIZED PRODUCTS
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildCategorySection(_categories[index]),
                  childCount: _categories.length,
                ),
              ),
              
              const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBannerSlider() {
    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 180.0,
            autoPlay: true,
            enlargeCenterPage: true,
            aspectRatio: 16 / 9,
            autoPlayCurve: Curves.fastOutSlowIn,
            enableInfiniteScroll: true,
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            viewportFraction: 0.9,
            onPageChanged: (index, reason) {
              setState(() {
                _currentBannerIndex = index;
              });
            },
          ),
          items: _banners.map((url) {
            return Builder(
              builder: (BuildContext context) {
                return Container(
                  width: MediaQuery.of(context).size.width,
                  margin: const EdgeInsets.symmetric(horizontal: 5.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(getProxyImageUrl(url.toString())),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _banners.asMap().entries.map((entry) {
            return Container(
              width: 8.0,
              height: 8.0,
              margin: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 4.0,
              ),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(
                  _currentBannerIndex == entry.key ? 0.9 : 0.4,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPartnerItem(dynamic p) {
    final logo = p['logo'];
    final name = p['name'] ?? p['companyName'] ?? 'Doanh nghiệp';

    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: ConsumerTheme.actionBlue.withOpacity(0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                image: logo != null && logo.toString().isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(getProxyImageUrl(logo.toString())),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (logo == null || logo.toString().isEmpty)
                  ? const Icon(
                      Icons.store,
                      color: ConsumerTheme.actionBlue,
                      size: 40,
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: ConsumerTheme.textDark, // Đổi màu sáng hơn do nền tối
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(Map<String, dynamic> category) {
    final title = category['categoryName'] ?? 'Sản phẩm';
    final products = category['products'] as List? ?? [];
    
    if (products.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ConsumerTheme.actionBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: const Text(
                  'Xem thêm',
                  style: TextStyle(color: ConsumerTheme.textGrey, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 260, // Height for product card
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return SizedBox(
                width: 160,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GridProductCard(
                    product: product,
                    onTap: () {
                      final code = product['gtin'] ?? product['code'];
                      if (code != null) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ResultScreen(code: code.toString())));
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class GridProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const GridProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = product['name'] ?? 'Sản phẩm';
    final priceStr = product['price']?.toString() ?? '0';
    final image = product['image'] ?? product['thumbnail'];
    final badge = product['badge'];
    final coop = product['coop'] ?? product['producer'] ?? '';

    final formattedPrice = priceStr == '0' || priceStr.isEmpty || priceStr == 'Liên hệ' 
        ? 'Liên hệ' 
        : NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(double.tryParse(priceStr) ?? 0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: ConsumerTheme.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 55,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image != null && image.toString().isNotEmpty
                      ? Image.network(
                          getProxyImageUrl(image.toString()),
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(color: Colors.grey[200]),
                        )
                      : Container(color: Colors.grey[200]),
                  if (badge != null && badge.toString().isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badge.toString().contains('OCOP') ? Colors.orange : ConsumerTheme.actionBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badge.toString(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badge.toString().contains('OCOP') ? Colors.white : ConsumerTheme.textOnCard,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 45,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: ConsumerTheme.textOnCard,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (coop.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        coop,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formattedPrice,
                          style: TextStyle(
                            color: Colors.green[800],
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        Container(
                          width: 28,
                          height: 25,
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.add_shopping_cart,
                            color: Colors.green[800],
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
