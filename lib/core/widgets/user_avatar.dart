import 'package:flutter/material.dart';
import 'package:trustid_scan_ai/core/api_client.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? fullName;
  final double size;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    this.fullName,
    this.size = 44,
    this.borderColor,
    this.borderWidth = 2,
    this.onTap,
    this.backgroundColor,
  });

  Widget _buildPlaceholder(BuildContext context) {
    final primary = borderColor ?? const Color(0xFF00875A);
    final bg = backgroundColor ?? primary.withOpacity(0.2);
    final name = fullName?.trim() ?? '';

    if (name.isEmpty) {
      return Container(
        width: size,
        height: size,
        color: bg,
        alignment: Alignment.center,
        child: Icon(
          Icons.person,
          color: primary,
          size: size * 0.55,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      color: bg,
      alignment: Alignment.center,
      child: Text(
        name[0].toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.42,
          color: primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeBorderColor = borderColor ?? const Color(0xFF00875A).withOpacity(0.5);

    Widget avatarWidget;
    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      final url = avatarUrl!.startsWith('http') ? avatarUrl! : getProxyImageUrl(avatarUrl!);
      avatarWidget = Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(context),
      );
    } else {
      avatarWidget = _buildPlaceholder(context);
    }

    final avatarContainer = Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: activeBorderColor,
          width: borderWidth,
        ),
      ),
      child: ClipOval(
        child: avatarWidget,
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: avatarContainer,
      );
    }

    return avatarContainer;
  }
}
