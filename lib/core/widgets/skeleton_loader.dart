import 'package:flutter/material.dart';

/// Widget tạo hiệu ứng shimmer cho các thành phần đang tải
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: const Color(0xFF16325B).withOpacity(0.4 + _animation.value * 0.6),
          ),
        );
      },
    );
  }
}

/// Card skeleton cho màn hình danh sách (Pallet, Export Orders, v.v.)
class SkeletonListCard extends StatelessWidget {
  const SkeletonListCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16325B).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonBox(width: 48, height: 48, borderRadius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(height: 16, width: 140),
                    SizedBox(height: 8),
                    SkeletonBox(height: 12, width: 90),
                  ],
                ),
              ),
              const SkeletonBox(width: 60, height: 24, borderRadius: 12),
            ],
          ),
          const SizedBox(height: 12),
          const SkeletonBox(height: 12),
          const SizedBox(height: 8),
          const SkeletonBox(height: 12, width: 200),
        ],
      ),
    );
  }
}

/// Skeleton loading list — hiển thị N card skeleton
class SkeletonListView extends StatelessWidget {
  final int count;
  final EdgeInsets? padding;

  const SkeletonListView({super.key, this.count = 6, this.padding});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const SkeletonListCard(),
    );
  }
}

/// Skeleton dạng form/wizard — dùng cho màn hình đóng gói, xuất, nhập
class SkeletonForm extends StatelessWidget {
  const SkeletonForm({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info text placeholder
          const SkeletonBox(height: 14, width: 240),
          const SizedBox(height: 20),

          // Card 1
          _skeletonCard([
            _row(160, 80),
            const SizedBox(height: 16),
            const SkeletonBox(height: 48),
          ]),

          // Card 2
          _skeletonCard([
            _row(120, 60),
            const SizedBox(height: 16),
            const SkeletonBox(height: 48),
            const SizedBox(height: 12),
            const SkeletonBox(height: 48),
          ]),

          // Card 3
          _skeletonCard([
            _row(180, 100),
            const SizedBox(height: 16),
            const SkeletonBox(height: 48),
            const SizedBox(height: 12),
            const SkeletonBox(height: 48),
            const SizedBox(height: 12),
            const SkeletonBox(height: 80),
          ]),

          // Submit button placeholder
          const SizedBox(height: 8),
          const SkeletonBox(height: 52, borderRadius: 14),
        ],
      ),
    );
  }

  Widget _skeletonCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF16325B).withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _row(double w1, double w2) {
    return Row(
      children: [
        SkeletonBox(width: w1, height: 16),
        const SizedBox(width: 12),
        SkeletonBox(width: w2, height: 16),
      ],
    );
  }
}
