import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'result_screen.dart';
import '../home/providers/scan_count_provider.dart';

import '../core/utils/qr_parser_util.dart';

/// Màn hình quét mã QR - Giao diện đồng bộ với TrustID App
class ScannerScreen extends ConsumerStatefulWidget {
  final String title;
  final String instruction;
  final bool returnCode;

  const ScannerScreen({
    super.key,
    this.title = 'Quét mã sản phẩm',
    this.instruction = 'Đưa camera vào mã QR trên sản phẩm để tra cứu nguồn gốc',
    this.returnCode = false,
  });

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  late MobileScannerController controller;
  bool isFlashOn = false;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: [BarcodeFormat.qrCode, BarcodeFormat.dataMatrix],
      autoStart: true,
      torchEnabled: false,
      useNewCameraSelector: true,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        _handled = true;
        controller.stop(); // Tạm dừng quét
        
        final parsedCode = await QrParserUtil.parseQrCode(context, barcode.rawValue!);
        if (parsedCode != null && parsedCode.isNotEmpty) {
          if (widget.returnCode) {
            if (mounted) Navigator.pop(context, parsedCode);
            return;
          }
          
          // Tăng lượt quét
          ref.read(scanCountProvider.notifier).increment();
          
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ResultScreen(code: parsedCode)),
            ).then((_) {
              // Cho phép quét tiếp khi quay lại
              if (mounted) {
                setState(() => _handled = false);
                controller.start();
              }
            });
          }
        } else {
          // Người dùng mở link ngoài hoặc hủy -> tiếp tục quét
          if (mounted) {
            setState(() => _handled = false);
            controller.start();
          }
        }
        break;
      }
    }
  }

  void _toggleFlash() {
    controller.toggleTorch();
    setState(() {
      isFlashOn = !isFlashOn;
    });
  }

  void _onManualInput() async {
    controller.stop();
    final String? result = await showDialog<String>(
      context: context,
      builder: (context) => _ManualInputDialog(),
    );

    if (result != null && result.isNotEmpty) {
      if (!mounted) return;
      final parsedCode = await QrParserUtil.parseQrCode(context, result);
      if (parsedCode != null && parsedCode.isNotEmpty && mounted) {
        _handled = true;
        
        if (widget.returnCode) {
          Navigator.pop(context, parsedCode);
          return;
        }
        
        // Tăng lượt quét
        ref.read(scanCountProvider.notifier).increment();
        
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ResultScreen(code: parsedCode)),
        ).then((_) {
          if (mounted) {
            setState(() => _handled = false);
            controller.start();
          }
        });
      } else {
        if (mounted) controller.start();
      }
    } else {
      if (mounted) controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera View
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
            fit: BoxFit.cover,
          ),

          // 2. Overlay
          _buildOverlay(context),
        ],
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final double scanArea = 280.0;

    return Stack(
      children: [
        // 1. Custom Overlay Painter
        Positioned.fill(
          child: CustomPaint(
            painter: ScannerOverlayPainter(
              scanAreaSize: scanArea,
              borderRadius: 20,
            ),
          ),
        ),

        // 2. UI Content
        SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Logo & Instruction
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Icon(Icons.qr_code_scanner, color: Colors.greenAccent, size: 50),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.instruction,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Bottom Controls
              Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCircleButton(
                      icon: isFlashOn ? Icons.flash_on : Icons.flash_off,
                      label: 'Đèn pin',
                      onPressed: _toggleFlash,
                    ),
                    const SizedBox(width: 40),
                    _buildCircleButton(
                      icon: Icons.keyboard,
                      label: 'Nhập tay',
                      onPressed: _onManualInput,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 3. Scan Frame Border
        Center(
          child: Container(
            width: scanArea,
            height: scanArea,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.greenAccent, width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    VoidCallback? onPressed,
    String? label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final double scanAreaSize;
  final double borderRadius;

  ScannerOverlayPainter({
    required this.scanAreaSize,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    final holePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: scanAreaSize,
            height: scanAreaSize,
          ),
          Radius.circular(borderRadius),
        ),
      );

    final path = Path.combine(PathOperation.difference, backgroundPath, holePath);
    
    final paint = Paint()
      ..color = const Color(0xFF0F2B46).withOpacity(0.85) // Sử dụng màu nền đặc trưng của TrustID
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ManualInputDialog extends StatefulWidget {
  @override
  State<_ManualInputDialog> createState() => _ManualInputDialogState();
}

class _ManualInputDialogState extends State<_ManualInputDialog> {
  final TextEditingController _textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF143E66),
      title: const Text('Nhập mã sản phẩm', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: _textController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Nhập chuỗi GTIN/Serial...',
          hintStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24)),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: const Text('Hủy', style: TextStyle(color: Colors.white70))
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
          onPressed: () {
            if (_textController.text.isNotEmpty) {
              Navigator.pop(context, _textController.text);
            }
          },
          child: const Text('Xác nhận'),
        ),
      ],
    );
  }
}
