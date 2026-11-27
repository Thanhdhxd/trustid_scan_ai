import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Tính hạn sử dụng dự kiến từ ngày sản xuất (`mfgDate`) và cấu hình HSD trên sản phẩm.
/// Trả về `null` nếu sản phẩm chưa khai báo `expiryDuration > 0`.
DateTime? computeDefaultExpiryDate(DateTime? mfgDate, Map<String, dynamic>? product) {
  if (mfgDate == null || product == null) return null;
  final rawDuration = product['expiryDuration'] ?? product['expiry_duration'];
  final duration = int.tryParse(rawDuration?.toString() ?? '') ?? 0;
  if (duration <= 0) return null;

  final unit = (product['expiryUnit'] ?? product['expiry_unit'] ?? 'MONTH').toString().toUpperCase();
  if (unit == 'DAY') {
    return mfgDate.add(Duration(days: duration));
  }
  if (unit == 'YEAR') {
    return _addMonthsSafe(mfgDate, duration * 12);
  }
  return _addMonthsSafe(mfgDate, duration);
}

DateTime _addMonthsSafe(DateTime date, int monthsToAdd) {
  final totalMonths = (date.year * 12) + (date.month - 1) + monthsToAdd;
  final targetYear = totalMonths ~/ 12;
  final targetMonth = (totalMonths % 12) + 1;
  final lastDayOfTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
  final targetDay = date.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : date.day;
  return DateTime(targetYear, targetMonth, targetDay);
}

bool hasProductExpiryConfig(Map<String, dynamic>? product) {
  if (product == null) return false;
  final rawDuration = product['expiryDuration'] ?? product['expiry_duration'];
  return (int.tryParse(rawDuration?.toString() ?? '') ?? 0) > 0;
}

String productExpiryUnitLabel(Map<String, dynamic>? product) {
  final unit = (product?['expiryUnit'] ?? product?['expiry_unit'] ?? 'MONTH').toString().toUpperCase();
  switch (unit) {
    case 'DAY':
      return 'ngày';
    case 'YEAR':
      return 'năm';
    default:
      return 'tháng';
  }
}

String formatProdOrderDate(DateTime? date, {String emptyText = '—'}) {
  if (date == null) return emptyText;
  return DateFormat('dd/MM/yyyy').format(date.toLocal());
}

String formatProdOrderDateIso(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

String prodOrderSourceLabel(String? sourceType) {
  switch ((sourceType ?? '').toUpperCase()) {
    case 'FARM':
      return 'Nông trại (Farm)';
    case 'EXTERNAL':
      return 'Nhập ngoài';
    case 'CROSS_TENANT':
      return 'Nhận B2B (Cross-Tenant)';
    case 'SEMI_FINISHED':
      return 'Bán thành phẩm (BTP)';
    case 'SURPLUS':
      return 'Kho Dư BTP';
    default:
      return sourceType?.isNotEmpty == true ? sourceType! : '—';
  }
}

String prodOrderTypeLabel(String orderType) =>
    orderType.toUpperCase() == 'STANDARD' ? 'Tiêu chuẩn' : 'Đóng bao';

Color prodOrderStatusColor(String status) {
  switch (status.toUpperCase()) {
    case 'ACTIVE':
    case 'IN_PROGRESS':
      return const Color(0xFF00875A);
    case 'APPROVED':
    case 'CODES_READY':
      return Colors.tealAccent;
    case 'GENERATING':
      return const Color(0xFFF59E0B);
    case 'GENERATION_FAILED':
    case 'CANCELLED':
    case 'REJECTED':
      return Colors.redAccent;
    case 'COMPLETED':
      return Colors.lightBlueAccent;
    default:
      return const Color(0xFF94A3B8);
  }
}

String prodOrderStatusLabel(String status, {bool isPalletMode = false}) {
  switch (status.toUpperCase()) {
    case 'GENERATING':
      return 'Đang sinh mã...';
    case 'GENERATION_FAILED':
      return 'Lỗi sinh mã';
    case 'CODES_READY':
      return 'Mã sẵn sàng';
    case 'APPROVED':
      return 'Đã duyệt';
    case 'ACTIVE':
    case 'IN_PROGRESS':
      return isPalletMode ? 'Đang xếp' : 'Đang sản xuất';
    case 'COMPLETED':
      return 'Hoàn thành';
    case 'CANCELLED':
      return 'Đã hủy';
    case 'DRAFT':
      return 'Nháp';
    default:
      return status;
  }
}

/// Trích xuất mã serial từ URL QR (`?Code=XXX` / `?code=XXX` / sau `=`) hoặc chuỗi serial thuần.
String extractSerialCodeFromQr(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasQuery) {
    final code = uri.queryParameters['Code'] ?? uri.queryParameters['code'];
    if (code != null && code.trim().isNotEmpty) {
      return code.trim();
    }
  }
  final eqIndex = trimmed.lastIndexOf('=');
  if (eqIndex >= 0 && eqIndex < trimmed.length - 1) {
    return trimmed.substring(eqIndex + 1).trim();
  }
  return trimmed;
}
