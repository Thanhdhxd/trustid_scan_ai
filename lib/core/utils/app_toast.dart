      import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'error_utils.dart';

enum ToastType { success, error, warning, info }

/// Tiện ích hiển thị thông báo Top-Right Toast (Góc trên bên phải, thời lượng 2s)
/// Thiết kế chuẩn Dark Navy cho TrustID App, hoạt động mượt mà trên cả Web và Mobile.
class AppToast {
  static OverlayEntry? _activeEntry;
  static Timer? _timer;

  /// Hiển thị thông báo Thành công (Màu xanh ngọc + Icon check)
  static void success(BuildContext context, String message, {String? title}) {
    show(context, message: message, title: title, type: ToastType.success);
  }

  /// Hiển thị thông báo Lỗi (Màu đỏ + Tự động làm sạch mã lỗi tiếng Việt)
  static void error(BuildContext context, dynamic error, {String? title}) {
    final cleanMsg = cleanErrorMessage(error);
    show(context, message: cleanMsg, title: title, type: ToastType.error);
  }

  /// Hiển thị thông báo Cảnh báo (Màu vàng cam + Icon warning)
  static void warning(BuildContext context, String message, {String? title}) {
    show(context, message: message, title: title, type: ToastType.warning);
  }

  /// Hiển thị thông báo Thông tin (Màu xanh dương + Icon info)
  static void info(BuildContext context, String message, {String? title}) {
    show(context, message: message, title: title, type: ToastType.info);
  }

  /// Đóng thông báo hiện tại ngay lập tức
  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    try {
      _activeEntry?.remove();
    } catch (_) {}
    _activeEntry = null;
  }

  /// Hiển thị Toast ở góc trên bên phải, tự tắt sau 3 giây
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    dismiss();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ToastOverlayWidget(
        message: message,
        title: title,
        type: type,
        duration: duration,
        onDismiss: () {
          dismiss();
        },
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);

    _timer = Timer(duration, () {
      dismiss();
    });
  }
}

class _ToastOverlayWidget extends StatefulWidget {
  final String message;
  final String? title;
  final ToastType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _ToastOverlayWidget({
    required this.message,
    this.title,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_ToastOverlayWidget> createState() => _ToastOverlayWidgetState();
}

class _ToastOverlayWidgetState extends State<_ToastOverlayWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.35, 0.0), // Trượt nhẹ từ bên phải vào
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _accentColor {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFF00875A); // TrustID Green
      case ToastType.error:
        return Colors.redAccent;
      case ToastType.warning:
        return const Color(0xFFF59E0B);
      case ToastType.info:
        return const Color(0xFF38BDF8);
    }
  }

  IconData get _iconData {
    switch (widget.type) {
      case ToastType.success:
        return Icons.check_circle_rounded;
      case ToastType.error:
        return Icons.error_outline_rounded;
      case ToastType.warning:
        return Icons.warning_amber_rounded;
      case ToastType.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final screenWidth = mediaQuery.size.width;

    return Positioned(
      top: topPadding + 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _offsetAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.min(520.0, screenWidth - 32.0),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF16325B), // Dark Navy Surface
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _accentColor.withOpacity(0.55),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _accentColor.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_iconData, color: _accentColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      fit: FlexFit.loose,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.title != null && widget.title!.isNotEmpty) ...[
                            Text(
                              widget.title!,
                              style: TextStyle(
                                color: _accentColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          Text(
                            widget.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: widget.onDismiss,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
