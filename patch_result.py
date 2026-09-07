import re

file_path = r"e:\TTTN\trustid_scan_ai\trustid_scan_ai\lib\scan\result_screen.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Rename class TraceabilityScreen to ResultScreen
content = content.replace("class TraceabilityScreen", "class ResultScreen")
content = content.replace("TraceabilityScreen({super.key", "ResultScreen({super.key")
content = content.replace("State<TraceabilityScreen>", "State<ResultScreen>")
content = content.replace("class _TraceabilityScreenState extends ConsumerState<TraceabilityScreen>", "class _ResultScreenState extends ConsumerState<ResultScreen>")

# 2. Fix imports
content = content.replace("import 'package:go_router/go_router.dart';", "")
content = content.replace("import '../../data/traceability_repository.dart';", "import 'traceability_repository.dart';\nimport 'risk_repository.dart';")
content = content.replace("import '../widgets/consumer_theme.dart';", "import '../home/widgets/consumer_theme.dart';")
content = content.replace("import '../../data/local/scan_history_local_source.dart';", "import '../home/providers/scan_count_provider.dart';")
content = content.replace("import '../../../../core/theme/trustid_colors.dart';", "")
content = content.replace("import '../../../../core/constants/api_constants.dart';", "")

# Fallback for TrustIDColors
content = content.replace("TrustIDColors.primaryGreen", "ConsumerTheme.actionBlue")
content = content.replace("TrustIDColors.backgroundDark", "ConsumerTheme.backgroundDark")
content = content.replace("TrustIDColors.cardDark", "const Color(0xFF1A2E40)")
content = content.replace("ApiConstants.baseUrl", "'https://api.trustid.com.vn'")

# 3. Add Risk properties and RiskBanner logic
content = re.sub(
    r"late Future<Map<String, dynamic>> _dataFuture;",
    r"late Future<Map<String, dynamic>> _dataFuture;\n  RiskResult? _risk;\n  final _traceRepo = TraceabilityRepository();\n  final _riskRepo = RiskRepository();",
    content
)

# Fix scanHistoryProvider usage
content = content.replace("ref\n                .read(scanHistoryLocalSourceProvider)\n                .updateProductName(widget.code, header['product_name']);", "")
content = content.replace("ref.read(scanHistoryLocalSourceProvider).updateProductName(widget.code, header['product_name']);", "")

# 4. Modify _loadWithLocation
load_with_loc_orig = """    return ref.read(traceabilityRepositoryProvider).getPublicTraceability(
      widget.code,
      lat: lat,
      lng: lng,
    );"""
load_with_loc_new = """    
    try {
      final results = await Future.wait([
        _traceRepo.getPublicTraceability(widget.code),
        _riskRepo.getRiskScore(
          code: widget.code,
          lat: lat ?? 21.0285,
          long: lng ?? 105.8542,
        ),
      ]);
      setState(() {
        _risk = results[1] as RiskResult;
      });
      _traceRepo.logScan(code: widget.code, lat: lat ?? 21.0285, long: lng ?? 105.8542);
      return results[0] as Map<String, dynamic>;
    } catch (e) {
      // Return empty map on error to let FutureBuilder handle it
      throw Exception(e);
    }"""
content = content.replace(load_with_loc_orig, load_with_loc_new)

# If the code uses context.pop(), replace with Navigator.pop(context)
content = content.replace("context.pop()", "Navigator.pop(context)")

# 5. Inject AI Risk Banner into the UI
risk_banner_code = """
                // 1.5. AI Risk Banner
                if (_risk != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: _buildRiskBanner(),
                  ),
"""
content = content.replace("// 2. Product Info Card", risk_banner_code + "\n                // 2. Product Info Card")

risk_banner_widget = """
  Color _colorFor(String level) => switch (level) {
        'HIGH_RISK' => Colors.redAccent,
        'WATCH' => Colors.orangeAccent,
        _ => ConsumerTheme.actionBlue,
      };

  String _titleFor(String level) => switch (level) {
        'HIGH_RISK' => 'CẢNH BÁO RỦI RO CAO',
        'WATCH' => 'CẦN THEO DÕI',
        _ => 'AN TOÀN',
      };

  Widget _buildRiskBanner() {
    final risk = _risk!;
    final color = _colorFor(risk.level);
    final icon = risk.level == 'HIGH_RISK'
        ? Icons.warning_rounded
        : risk.level == 'WATCH'
            ? Icons.info_outline
            : Icons.verified_user_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _titleFor(risk.level),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            risk.level == 'HIGH_RISK'
              ? 'Mã này có dấu hiệu bất thường (điểm ${risk.anomalyScore}). Khoảng cách: ${risk.distanceKm} km. Có thể đã bị làm giả!'
              : risk.level == 'WATCH'
                  ? 'Cần theo dõi thêm (điểm ${risk.anomalyScore}).'
                  : 'Không phát hiện dấu hiệu bất thường (điểm ${risk.anomalyScore}).',
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }
}
"""

# Find the LAST closing brace and replace it with the risk_banner_widget
last_brace_index = content.rfind("}")
if last_brace_index != -1:
    content = content[:last_brace_index] + risk_banner_widget + content[last_brace_index+1:]

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Patching complete!")
