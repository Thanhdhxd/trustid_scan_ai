import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';

/// Helper utility to check module subscriptions, hidden menus, and RBAC permissions on Mobile App
class PermissionHelper {
  static const String productionOrderView = 'PRODUCTION_ORDER_VIEW';
  static const String productionOrderManage = 'PRODUCTION_ORDER_MANAGE';
  static const String palletManage = 'PALLET_MANAGE';
  static const String productionTicketScan = 'PRODUCTION_TICKET_SCAN';
  static const String packagingDirectManage = 'PACKAGING_DIRECT_MANAGE';

  static bool hasModule(WidgetRef ref, String moduleKey) {
    final user = ref.watch(authControllerProvider).value;
    return hasModuleForUser(user, moduleKey);
  }

  static bool hasModuleForUser(User? user, String moduleKey) {
    if (user == null) return false;

    final role = (user.role).trim().toUpperCase();
    if (role == 'ADMIN' || role == 'SUPER_ADMIN') {
      return true;
    }

    if (role == 'DRIVER' || role == 'TRANSPORTER') {
      if (moduleKey == 'supply' || moduleKey == 'transport' || moduleKey == 'logistics') {
        return true;
      }
    }
    if (role == 'FARMER' || role == 'TEAM_LEADER') {
      if (moduleKey == 'farm') return true;
    }
    if (role == 'DEALER') {
      if (moduleKey == 'retail') return true;
    }

    if (user.moduleConfig != null && user.moduleConfig!.isNotEmpty) {
      final val = user.moduleConfig![moduleKey];
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
      return false;
    }

    if (user.permissions != null && user.permissions!.isNotEmpty) {
      if (user.permissions!.contains('ALL')) return true;

      if (moduleKey == 'supply') {
        return user.permissions!.any((p) =>
            p.startsWith('MATERIAL_') ||
            p.startsWith('WAREHOUSE_') ||
            p.startsWith('BATCH_') ||
            p.startsWith('PACKAGING_') ||
            p.startsWith('PRODUCTION_') ||
            p.startsWith('PALLET_') ||
            p.startsWith('INBOUND_') ||
            p.startsWith('EXPORT_') ||
            p.startsWith('SHIPMENT_') ||
            p.startsWith('TRANSPORT_') ||
            p.startsWith('DELIVERY_') ||
            p.startsWith('DRIVER_'));
      }

      if (moduleKey == 'farm') {
        return user.permissions!.any((p) =>
            p.startsWith('FARM_') ||
            p.startsWith('CYCLE_') ||
            p.startsWith('TASK_') ||
            p.startsWith('TEAM_'));
      }

      if (moduleKey == 'retail') {
        return user.permissions!.any((p) =>
            p.startsWith('DEALER_') ||
            p.startsWith('RETAIL_') ||
            p.startsWith('POS_'));
      }
    }

    return true;
  }

  static bool isMenuVisible(User? user, String path) {
    if (user == null) return false;
    if (user.globalHiddenMenus != null && user.globalHiddenMenus!.contains(path)) {
      return false;
    }
    if (user.hiddenMenus != null && user.hiddenMenus!.contains(path)) {
      return false;
    }
    return true;
  }

  static bool hasPermission(WidgetRef ref, String permissionKey) {
    final user = ref.watch(authControllerProvider).value;
    return hasPermissionForUser(user, permissionKey);
  }

  static bool hasPermissionForUser(User? user, String permissionKey) {
    if (user == null) return false;

    final role = (user.role).trim().toUpperCase();
    if (role == 'ADMIN' || role == 'SUPER_ADMIN') {
      return true;
    }

    if (user.permissions == null || user.permissions!.isEmpty) {
      return true;
    }

    if (user.permissions!.contains('ALL')) return true;
    return user.permissions!.contains(permissionKey);
  }

  static bool canViewProductionOrders(WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    return canViewProductionOrdersForUser(user);
  }

  static bool canViewProductionOrdersForUser(User? user) =>
      hasPermissionForUser(user, productionOrderView) ||
      hasPermissionForUser(user, productionOrderManage);

  static bool canManageProductionOrders(WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    return canManageProductionOrdersForUser(user);
  }

  static bool canManageProductionOrdersForUser(User? user) =>
      hasPermissionForUser(user, productionOrderManage);

  static bool canManagePallets(WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    return canManagePalletsForUser(user);
  }

  static bool canManagePalletsForUser(User? user) =>
      hasPermissionForUser(user, palletManage) ||
      hasPermissionForUser(user, productionOrderManage);
}
