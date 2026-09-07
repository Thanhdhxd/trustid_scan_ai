import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class QrParserUtil {
  /// Parses a raw QR code string.
  /// If it's a URL belonging to 'trustid.com.vn' or 'veritrust.vn' and contains 'Code=' or 'code=',
  /// it extracts and returns just that parameter's value.
  /// If it's another URL, it prompts the user before opening it in an in-app webview and returns null.
  /// Otherwise, returns the raw code itself.
  static Future<String?> parseQrCode(BuildContext context, String rawCode) async {
    final trimmed = rawCode.trim();
    // 1. Check if it's a valid URL
    if (trimmed.toLowerCase().startsWith('http://') || trimmed.toLowerCase().startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null) {
        // 2. Check if it's our domain
        final host = uri.host.toLowerCase();
        if (host.contains('trustid.com.vn') || host.contains('veritrust.vn')) {
          // Extract the 'Code' query parameter
          final codeParam = uri.queryParameters['Code'] ?? uri.queryParameters['code'];
          if (codeParam != null && codeParam.isNotEmpty) {
            return codeParam;
          }
        }
        
        // 3. Not our domain (or missing 'Code' param) -> prompt user
        if (await canLaunchUrl(uri)) {
          if (!context.mounted) return null;
          
          final shouldLaunch = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF16325B),
              title: const Text('Mở liên kết', style: TextStyle(color: Colors.white)),
              content: Text('Bạn có muốn mở trang web này không?\n\n$trimmed', style: const TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Bỏ qua', style: TextStyle(color: Colors.redAccent)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00875A)),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Mở trang', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );

          if (shouldLaunch == true) {
            await launchUrl(
              uri,
              mode: LaunchMode.inAppWebView,
            );
          }
        }
        return null;
      }
    }
    
    // 4. Not a URL at all -> Return raw text
    return trimmed;
  }
}
