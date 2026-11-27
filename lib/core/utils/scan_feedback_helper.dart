import 'package:flutter/services.dart';

/// Phản hồi âm thanh hệ thống và rung (Haptic) khi quét mã QR tại xưởng.
/// Dùng `SystemSound` + `HapticFeedback` sẵn có của Flutter (không cần plugin native).
class ScanFeedbackHelper {
  static void playSuccess() {
    try {
      SystemSound.play(SystemSoundType.click).ignore();
      HapticFeedback.mediumImpact().ignore();
    } catch (_) {}
  }

  static void playError() {
    try {
      SystemSound.play(SystemSoundType.alert).ignore();
      HapticFeedback.heavyImpact().ignore();
    } catch (_) {}
  }
}

/// Bộ chống quét đúp cùng một mã QR trong khoảng `cooldown` (mặc định 1.4 giây theo FS-PRO-02).
class ScanCooldownGuard {
  final Duration cooldown;
  final DateTime Function() _now;
  String? _lastCode;
  DateTime? _lastScanAt;

  ScanCooldownGuard({
    this.cooldown = const Duration(milliseconds: 1400),
    DateTime Function()? nowProvider,
  }) : _now = nowProvider ?? DateTime.now;

  /// Trả `true` nếu [code] vừa được quét trong khoảng cooldown.
  bool shouldIgnore(String code) {
    final normalized = code.trim();
    if (normalized.isEmpty) return true;
    if (_lastCode != normalized || _lastScanAt == null) return false;
    return _now().difference(_lastScanAt!) < cooldown;
  }

  /// Ghi nhận mốc thời gian vừa xử lý xong [code].
  void markScanned(String code) {
    final normalized = code.trim();
    if (normalized.isEmpty) return;
    _lastCode = normalized;
    _lastScanAt = _now();
  }

  void reset() {
    _lastCode = null;
    _lastScanAt = null;
  }
}
