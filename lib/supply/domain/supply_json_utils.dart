/// Các hàm tiện ích parse JSON an toàn dùng chung cho domain models phân hệ Supply.
double? parseSupplyDoubleNullable(dynamic val) {
  if (val == null) return null;
  if (val is num) return val.toDouble();
  return double.tryParse(val.toString());
}

double parseSupplyDouble(dynamic val, [double fallback = 0.0]) =>
    parseSupplyDoubleNullable(val) ?? fallback;

int? parseSupplyIntNullable(dynamic val) {
  if (val == null) return null;
  if (val is int) return val;
  if (val is num) return val.toInt();
  return int.tryParse(val.toString());
}

int parseSupplyInt(dynamic val, [int fallback = 0]) =>
    parseSupplyIntNullable(val) ?? fallback;

bool parseSupplyBool(dynamic val, [bool fallback = false]) {
  if (val is bool) return val;
  if (val is num) return val != 0;
  if (val is String) {
    final lower = val.trim().toLowerCase();
    if (lower == 'true' || lower == '1') return true;
    if (lower == 'false' || lower == '0') return false;
  }
  return fallback;
}

DateTime? parseSupplyDate(dynamic val) {
  if (val == null) return null;
  if (val is DateTime) return val;
  return DateTime.tryParse(val.toString());
}

String? parseSupplyString(dynamic val) {
  if (val == null) return null;
  final s = val.toString().trim();
  return s.isEmpty ? null : s;
}

Map<String, dynamic>? asSupplyMap(dynamic val) {
  if (val is Map<String, dynamic>) return val;
  if (val is Map) return Map<String, dynamic>.from(val);
  return null;
}

List<Map<String, dynamic>> asSupplyMapList(dynamic val) {
  if (val is! List) return const [];
  return val
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}
