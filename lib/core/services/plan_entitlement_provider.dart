import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/dio_client.dart';
import '../../auth/presentation/auth_controller.dart';

/// Thông tin gói dịch vụ & danh sách tính năng (`FN-...`) của doanh nghiệp hiện tại.
class PlanEntitlement {
  final String? planCode;
  final String? planState;
  final String? tenantStatus;
  final List<String> addons;
  final List<String>? features;

  const PlanEntitlement({
    this.planCode,
    this.planState,
    this.tenantStatus,
    this.addons = const [],
    this.features,
  });

  factory PlanEntitlement.fromMePlanJson(Map<String, dynamic> json) {
    final root = json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : json;
    final entitlement = root['entitlement'] is Map
        ? Map<String, dynamic>.from(root['entitlement'] as Map)
        : <String, dynamic>{};
    final entPlan = entitlement['plan'] is Map
        ? Map<String, dynamic>.from(entitlement['plan'] as Map)
        : <String, dynamic>{};
    final viewPlan = root['plan'] is Map
        ? Map<String, dynamic>.from(root['plan'] as Map)
        : <String, dynamic>{};

    List<String>? parsedFeatures;
    if (entitlement['features'] is List) {
      parsedFeatures = (entitlement['features'] as List).map((e) => e.toString()).toList();
    }

    final rawAddons = entPlan['addons'] ?? viewPlan['addons'];
    final parsedAddons = rawAddons is List
        ? rawAddons.map((e) => e.toString()).toList()
        : const <String>[];

    return PlanEntitlement(
      planCode: (entPlan['code'] ?? viewPlan['planCode'])?.toString(),
      planState: (entPlan['state'] ?? viewPlan['state'])?.toString(),
      tenantStatus: viewPlan['tenantStatus']?.toString(),
      addons: parsedAddons,
      features: parsedFeatures,
    );
  }

  bool hasFeature(String featureCode) {
    final f = features;
    if (f == null) return true;
    return f.contains(featureCode);
  }

  bool get isExpired => planState?.toUpperCase() == 'EXPIRED';
  bool get isSuspended => tenantStatus?.toUpperCase() == 'SUSPENDED';
}

final planEntitlementProvider =
    AsyncNotifierProvider<PlanEntitlementNotifier, PlanEntitlement?>(
  PlanEntitlementNotifier.new,
);

/// Quản lý trạng thái gói dịch vụ của doanh nghiệp (`GET /me/plan`).
class PlanEntitlementNotifier extends AsyncNotifier<PlanEntitlement?> {
  DateTime? _lastFetchAt;
  static const Duration _refreshCooldown = Duration(seconds: 30);

  @override
  Future<PlanEntitlement?> build() async {
    final userId = ref.watch(authControllerProvider.select((v) => v.value?.id));
    if (userId == null || userId.isEmpty) {
      return null;
    }
    return _fetchMePlan();
  }

  Future<PlanEntitlement?> _fetchMePlan() async {
    _lastFetchAt = DateTime.now();
    try {
      final response = await ref.read(dioProvider).get('/me/plan');
      if (response.data is Map) {
        return PlanEntitlement.fromMePlanJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      return null;
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> refresh({bool force = false}) async {
    if (!force &&
        _lastFetchAt != null &&
        DateTime.now().difference(_lastFetchAt!) < _refreshCooldown) {
      return;
    }
    state = AsyncData(await _fetchMePlan());
  }

  /// Tải lại thông tin gói tối đa 1 lần / 30 giây khi API báo khóa gói.
  Future<void> refreshThrottled() async {
    final now = DateTime.now();
    if (_lastFetchAt != null && now.difference(_lastFetchAt!) < _refreshCooldown) {
      return;
    }
    final result = await _fetchMePlan();
    state = AsyncData(result);
  }
}

/// Kiểm tra nhanh mã tính năng gói (`FN-FAR-06`, `FN-PRO-02`, ...) trên UI.
final hasPlanFeatureProvider = Provider.family<bool, String>((ref, featureCode) {
  final entitlement = ref.watch(planEntitlementProvider).value;
  return entitlement?.hasFeature(featureCode) ?? true;
});
