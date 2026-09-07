import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Combines a TextField (auto-focus for dedicated barcode readers)
/// with a camera button that opens MobileScanner in a bottom sheet.
class QrScanInput extends StatefulWidget {
  final ValueChanged<String> onCodeScanned;
  final String hintText;
  final bool enabled;
  final FocusNode? focusNode;

  const QrScanInput({
    super.key,
    required this.onCodeScanned,
    this.hintText = 'Quét hoặc nhập mã serial...',
    this.enabled = true,
    this.focusNode,
  });

  @override
  State<QrScanInput> createState() => _QrScanInputState();
}

class _QrScanInputState extends State<QrScanInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _ownsNode = false;

  String _extractCode(String raw) {
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasQuery) {
      final code = uri.queryParameters['Code'] ?? uri.queryParameters['code'];
      if (code != null && code.trim().isNotEmpty) return code.trim();
    }
    if (trimmed.contains('=')) {
      return trimmed.substring(trimmed.lastIndexOf('=') + 1).trim();
    }
    return trimmed;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsNode = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.enabled && mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_ownsNode) _focusNode.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final code = _extractCode(value);
    if (code.isEmpty) return;
    widget.onCodeScanned(code);
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _openCamera() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: _CameraScanner(
          onDetect: (code) {
            Navigator.of(context).pop();
            widget.onCodeScanned(_extractCode(code));
            _focusNode.requestFocus();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            style: const TextStyle(color: Color(0xFFE8EDF3), fontSize: 15),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
              ),
              filled: true,
              fillColor: const Color(0xFF0F2B46),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00875A)),
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: Color(0xFF64748B),
                size: 20,
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: _submit,
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: const Color(0xFF00875A),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.enabled ? _openCamera : null,
            child: const SizedBox(
              width: 50,
              height: 50,
              child: Icon(Icons.camera_alt, color: Colors.white, size: 24),
            ),
          ),
        ),
      ],
    );
  }
}

class _CameraScanner extends StatefulWidget {
  final ValueChanged<String> onDetect;
  const _CameraScanner({required this.onDetect});

  @override
  State<_CameraScanner> createState() => _CameraScannerState();
}

class _CameraScannerState extends State<_CameraScanner> {
  bool _detected = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          onDetect: (capture) {
            if (_detected) return;
            final barcodes = capture.barcodes;
            if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
              _detected = true;
              widget.onDetect(barcodes.first.rawValue!);
            }
          },
        ),
        Positioned(
          top: 16,
          right: 16,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            style: IconButton.styleFrom(backgroundColor: Colors.black45),
          ),
        ),
        const Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Text(
            'Hướng camera vào mã QR/Barcode',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
