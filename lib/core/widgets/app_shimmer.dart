import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Bộ màu chuẩn Shimmer cho giao diện Dark Navy của TrustID
const Color kShimmerBaseDark = Color(0xFF20426E);
const Color kShimmerHighlightDark = Color(0xFF35659F);
const Color kShimmerCardBg = Color(0xFF16325B);

/// Wrapper Shimmer toàn cục với chu kỳ quét sóng mượt mà
class AppShimmer extends StatelessWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  const AppShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1300),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? kShimmerBaseDark,
      highlightColor: highlightColor ?? kShimmerHighlightDark,
      period: duration,
      child: child,
    );
  }
}

/// Khối hộp chữ nhật bo góc dùng cho dòng chữ, thẻ badge, nút bấm
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 6.0,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Khối tròn dùng cho avatar, icon badge
class ShimmerCircle extends StatelessWidget {
  final double size;
  final EdgeInsetsGeometry? margin;

  const ShimmerCircle({
    super.key,
    required this.size,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: margin,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// =========================================================================
/// 1. SKELETON: DANH SÁCH ĐƠN XUẤT KHO (ExportOrderListSkeleton)
/// =========================================================================
class ExportOrderListSkeleton extends StatelessWidget {
  final int itemCount;
  const ExportOrderListSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 80),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kShimmerCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: AppShimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hàng 1: Mã đơn, badge ưu tiên & trạng thái
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const ShimmerBox(width: 90, height: 16, borderRadius: 4),
                        const SizedBox(width: 8),
                        const ShimmerBox(width: 44, height: 16, borderRadius: 4),
                      ],
                    ),
                    const ShimmerBox(width: 80, height: 20, borderRadius: 10),
                  ],
                ),
                const SizedBox(height: 12),

                // Hàng 2: Tên sản phẩm
                Row(
                  children: [
                    const ShimmerBox(width: 14, height: 14, borderRadius: 3),
                    const SizedBox(width: 8),
                    ShimmerBox(
                      width: (140 + (index % 3) * 40).toDouble(),
                      height: 14,
                      borderRadius: 4,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Hàng 3: Khách hàng / Đại lý
                Row(
                  children: [
                    const ShimmerBox(width: 14, height: 14, borderRadius: 3),
                    const SizedBox(width: 8),
                    ShimmerBox(
                      width: (110 + (index % 2) * 50).toDouble(),
                      height: 12,
                      borderRadius: 4,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Hàng 4: Thanh tiến độ quét
                const ShimmerBox(width: double.infinity, height: 6, borderRadius: 3),
                const SizedBox(height: 8),

                // Hàng 5: Số lượng & ngày tạo
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    ShimmerBox(width: 90, height: 12, borderRadius: 4),
                    ShimmerBox(width: 70, height: 12, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// =========================================================================
/// 2. SKELETON: LÔ BÁN THÀNH PHẨM & ĐÓNG GÓI TRỰC TIẾP (BatchListSkeleton)
/// =========================================================================
class BatchListSkeleton extends StatelessWidget {
  final int itemCount;
  const BatchListSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kShimmerCardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: AppShimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hàng 1: Mã lô + Badge trạng thái
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    ShimmerBox(width: 130, height: 16, borderRadius: 4),
                    ShimmerBox(width: 75, height: 20, borderRadius: 10),
                  ],
                ),
                const SizedBox(height: 10),

                // Hàng 2: Tên sản phẩm
                ShimmerBox(
                  width: (160 + (index % 3) * 30).toDouble(),
                  height: 14,
                  borderRadius: 4,
                ),
                const SizedBox(height: 12),

                // Hàng 3: 3 ô thông số (Vào, Ra, Tồn khả dụng)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: const [
                          ShimmerBox(width: 45, height: 10, borderRadius: 3),
                          SizedBox(height: 4),
                          ShimmerBox(width: 55, height: 13, borderRadius: 3),
                        ],
                      ),
                      Container(width: 1, height: 24, color: Colors.white.withOpacity(0.1)),
                      Column(
                        children: const [
                          ShimmerBox(width: 45, height: 10, borderRadius: 3),
                          SizedBox(height: 4),
                          ShimmerBox(width: 55, height: 13, borderRadius: 3),
                        ],
                      ),
                      Container(width: 1, height: 24, color: Colors.white.withOpacity(0.1)),
                      Column(
                        children: const [
                          ShimmerBox(width: 45, height: 10, borderRadius: 3),
                          SizedBox(height: 4),
                          ShimmerBox(width: 55, height: 13, borderRadius: 3),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Hàng 4: Kho hàng + Lô nguồn
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    ShimmerBox(width: 110, height: 12, borderRadius: 4),
                    ShimmerBox(width: 80, height: 12, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// =========================================================================
/// 3. SKELETON: BÁN LẺ POS & LỊCH SỬ ĐƠN HÀNG (RetailSalesListSkeleton)
/// =========================================================================
class RetailSalesListSkeleton extends StatelessWidget {
  final int itemCount;
  const RetailSalesListSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kShimmerCardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: AppShimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hàng 1: Mã HĐ + Badge phương thức + Số tiền
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        ShimmerBox(width: 85, height: 15, borderRadius: 4),
                        SizedBox(width: 8),
                        ShimmerBox(width: 65, height: 18, borderRadius: 6),
                      ],
                    ),
                    const ShimmerBox(width: 95, height: 16, borderRadius: 4),
                  ],
                ),
                const SizedBox(height: 10),

                // Hàng 2: Tên khách hàng & SĐT
                Row(
                  children: [
                    const ShimmerBox(width: 14, height: 14, borderRadius: 3),
                    const SizedBox(width: 6),
                    ShimmerBox(
                      width: (120 + (index % 3) * 35).toDouble(),
                      height: 13,
                      borderRadius: 4,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Hàng 3: Thời gian bán + Tổng số lượng sản phẩm (SP)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    ShimmerBox(width: 110, height: 12, borderRadius: 4),
                    ShimmerBox(width: 60, height: 18, borderRadius: 6),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// =========================================================================
/// 4. SKELETON: LỆNH SẢN XUẤT (OrderListSkeleton)
/// =========================================================================
class OrderListSkeleton extends StatelessWidget {
  final int itemCount;
  const OrderListSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kShimmerCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: AppShimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hàng 1: Mã lệnh & Trạng thái
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    ShimmerBox(width: 110, height: 16, borderRadius: 4),
                    ShimmerBox(width: 70, height: 20, borderRadius: 10),
                  ],
                ),
                const SizedBox(height: 10),

                // Hàng 2: Tên sản phẩm
                ShimmerBox(
                  width: (150 + (index % 3) * 30).toDouble(),
                  height: 14,
                  borderRadius: 4,
                ),
                const SizedBox(height: 10),

                // Hàng 3: Tiến độ bao / khối lượng
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    ShimmerBox(width: 120, height: 12, borderRadius: 4),
                    ShimmerBox(width: 80, height: 12, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// =========================================================================
/// 5. SKELETON CHUNG: TIẾP NHẬN / PHIẾU GIAO (GenericCardListSkeleton)
/// =========================================================================
class GenericCardListSkeleton extends StatelessWidget {
  final int itemCount;
  const GenericCardListSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kShimmerCardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: AppShimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    ShimmerBox(width: 120, height: 16, borderRadius: 4),
                    ShimmerBox(width: 65, height: 18, borderRadius: 8),
                  ],
                ),
                const SizedBox(height: 10),
                ShimmerBox(
                  width: (170 + (index % 2) * 40).toDouble(),
                  height: 13,
                  borderRadius: 4,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    ShimmerBox(width: 90, height: 12, borderRadius: 4),
                    ShimmerBox(width: 75, height: 12, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
