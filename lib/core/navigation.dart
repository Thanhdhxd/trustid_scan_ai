import 'package:flutter/material.dart';
import 'package:trustid_scan_ai/supply/presentation/bag_linking_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/pallet_linking_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/pallets/pallet_list_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/pallets/pallet_detail_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/export_orders/export_order_list_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/semi_finished/sf_pallet_list_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/semi_finished/sf_pallet_detail_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/export_orders/export_order_create_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/export_orders/export_order_edit_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/export_orders/export_order_scan_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/export_orders/export_order_sheet_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/semi_finished/semi_finished_list_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/semi_finished/semi_finished_export_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/semi_finished/semi_finished_import_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/semi_finished/semi_finished_packaging_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/dealer/receive/dealer_receive_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/dealer/receive/dealer_shipment_detail_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/dealer/inventory/dealer_stock_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/dealer/pos/dealer_pos_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/dealer/sales/dealer_sales_history_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/dealer/customers/dealer_customers_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/dealer/customers/dealer_customer_groups_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/dealer/pricing/dealer_pricing_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/order_list_screen.dart';
import 'package:trustid_scan_ai/scan/scanner_screen.dart';
import 'package:trustid_scan_ai/farm/presentation/diary/farming_diary_screen.dart';
import 'package:trustid_scan_ai/farm/presentation/cycle/cycle_management_screen.dart';
import 'package:trustid_scan_ai/farm/presentation/cycle/cycle_list_screen.dart';
import 'package:trustid_scan_ai/farm/presentation/team/my_team_screen.dart';
import 'package:trustid_scan_ai/farm/presentation/locations/location_management_screen.dart';
import 'package:trustid_scan_ai/farm/presentation/harvest/harvest_screen.dart';
import 'package:trustid_scan_ai/auth/user_profile_screen.dart';
import 'package:trustid_scan_ai/farm/presentation/areas/master_area_list_screen.dart';
import 'package:trustid_scan_ai/farm/presentation/materials/material_list_screen.dart';
import 'package:trustid_scan_ai/farm/presentation/products/product_list_screen.dart';
import 'package:trustid_scan_ai/home/modern_home_screen.dart';
import 'package:trustid_scan_ai/dashboard/placeholder_screen.dart';
import 'package:trustid_scan_ai/dashboard/dashboard_screen.dart';
import 'package:trustid_scan_ai/farm/presentation/home/farmer_home_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/driver/driver_home_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/warehouse/warehouse_home_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/warehouse/warehouse_management_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/warehouse/warehouse_stock_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/dealer/dealer_home_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/kcs/kcs_home_screen.dart';
import 'package:trustid_scan_ai/supply/presentation/create_production_order_screen.dart';
import 'package:trustid_scan_ai/kcs/presentation/kcs_dashboard_screen.dart';
import 'package:trustid_scan_ai/kcs/presentation/inspection_form_screen.dart';
import 'package:trustid_scan_ai/kcs/presentation/management/kcs_staff_list_screen.dart';
import 'package:trustid_scan_ai/kcs/presentation/management/kcs_staff_detail_screen.dart';
import 'package:trustid_scan_ai/home/weather/weather_detail_screen.dart';

extension NavigationExtension on BuildContext {
  void pop<T>([T? result]) {
    Navigator.of(this).pop(result);
  }

  Future<T?> pushReplacement<T extends Object?, TO extends Object?>(dynamic location, {TO? result, Object? extra}) {
    if (location is! String) {
      return Navigator.of(this).pushReplacement(
        MaterialPageRoute(builder: (context) => location as Widget),
        result: result,
      );
    }
    final path = location;
    if (path == '/manager/orders-bag-linking') {
      return Navigator.of(this).pushReplacement(
        MaterialPageRoute(builder: (context) => const OrderListScreen(mode: 'bag-linking')),
        result: result,
      );
    }
    return push<T>(location, extra: extra);
  }

  void pushReplacementNamed(String path) {
    pushReplacement(path);
  }

  Future<T?> push<T>(dynamic location, {Object? extra}) {
    if (location is! String) {
      // standard push with MaterialPageRoute
      return Navigator.of(this).push(
        MaterialPageRoute(builder: (context) => location as Widget),
      );
    }
    
    final path = location;
    Widget? screen;
    
    if (path == '/manager/production-orders/create' || path == '/supply/production-orders/create' || path == '/manager/create-production-order') {
      screen = const CreateProductionOrderScreen();
    } else if (path.startsWith('/manager/bag-linking/')) {
      final id = path.replaceAll('/manager/bag-linking/', '');
      screen = BagLinkingScreen(orderId: id);
    } else if (path.startsWith('/manager/pallet-linking/')) {
      final id = path.replaceAll('/manager/pallet-linking/', '');
      screen = PalletLinkingScreen(orderId: id);
    } else if (path == '/manager/orders-bag-linking') {
      screen = const OrderListScreen(mode: 'bag-linking');
    } else if (path == '/manager/orders-pallet-linking') {
      screen = const OrderListScreen(mode: 'pallet-linking');
    } else if (path == '/manager/pallets') {
      screen = const PalletListScreen();
    } else if (path.startsWith('/manager/pallets/')) {
      final id = path.replaceAll('/manager/pallets/', '');
      screen = PalletDetailScreen(palletId: id);
    } else if (path == '/manager/export-sheets') {
      screen = const ExportOrderSheetScreen();
    } else if (path == '/manager/orders-bag-linking') {
      screen = const OrderListScreen(mode: 'bag-linking');
    } else if (path == '/manager/export-orders') {
      screen = const ExportOrderListScreen();
    } else if (path == '/manager/sf-pallets') {
      screen = const SFPalletListScreen();
    } else if (path.startsWith('/manager/sf-pallets/')) {
      final id = path.replaceAll('/manager/sf-pallets/', '');
      screen = SFPalletDetailScreen(palletId: id);
    } else if (path == '/manager/semi-finished') {
      screen = const SemiFinishedListScreen();
    } else if (path == '/manager/export-orders/create') {
      screen = const ExportOrderCreateScreen();
    } else if (path.startsWith('/manager/export-orders/') && path.endsWith('/edit')) {
      final parts = path.split('/');
      if (parts.length >= 4) {
        screen = ExportOrderEditScreen(orderId: parts[3]);
      }
    } else if (path.startsWith('/manager/export-orders/') && path.endsWith('/scan')) {
      final parts = path.split('/');
      if (parts.length >= 4) {
        screen = ExportOrderScanScreen(orderId: parts[3]);
      }
    } else if (path == '/manager/semi-finished/export') {
      screen = const SemiFinishedExportScreen();
    } else if (path == '/manager/semi-finished/import') {
      screen = const SemiFinishedImportScreen();
    } else if (path == '/manager/semi-finished/packaging') {
      screen = const SemiFinishedPackagingScreen();
    } else if (path.startsWith('/manager/receive/')) {
      final id = path.replaceAll('/manager/receive/', '');
      screen = DealerShipmentDetailScreen(shipmentId: id);
    } else if (path == '/manager/warehouses') {
      screen = const WarehouseManagementScreen();
    } else if (path.startsWith('/manager/warehouse-stock/')) {
      final id = path.replaceAll('/manager/warehouse-stock/', '');
      screen = WarehouseStockScreen(warehouseId: id);
    } else if (path == '/manager/orders') {
      screen = const OrderListScreen(mode: 'orders');
    } else if (path == '/consumer/scan') {
      screen = const ScannerScreen(
        title: 'Quét mã',
        instruction: 'Đưa camera vào mã để quét',
        returnCode: false,
      );
    } else if (path == '/farmer/diary') {
      screen = const FarmingDiaryScreen();
    } else if (path == '/farmer/profile') {
      screen = const UserProfileScreen();
    } else if (path == '/farmer/my-team') {
      screen = const MyTeamScreen();
    } else if (path == '/farmer/locations') {
      screen = const LocationManagementScreen();
    } else if (path == '/farmer/master-areas') {
      screen = const MasterAreaListScreen();
    } else if (path == '/farmer/materials') {
      screen = const MaterialListScreen();
    } else if (path == '/farmer/cycles') {
      screen = const CycleManagementScreen();
    } else if (path == '/farmer/cycle-list') {
      screen = const CycleListScreen();
    } else if (path == '/farmer/harvest') {
      screen = const HarvestScreen();
    } else if (path == '/farmer/products') {
      screen = const ProductListScreen();
    } else if (path == '/farmer/home') {
      screen = const FarmerHomeScreen();
    } else if (path == '/driver/home') {
      screen = const DriverHomeScreen();
    } else if (path == '/warehouse/home') {
      screen = const WarehouseHomeScreen();
    } else if (path == '/dealer/home') {
      screen = const DealerHomeScreen();
    } else if (path == '/dealer/receive') {
      screen = const DealerReceiveScreen();
    } else if (path.startsWith('/dealer/receive/')) {
      final id = path.replaceAll('/dealer/receive/', '');
      screen = DealerShipmentDetailScreen(shipmentId: id);
    } else if (path == '/dealer/inventory') {
      screen = const DealerStockScreen();
    } else if (path == '/dealer/customers') {
      screen = const DealerCustomersScreen();
    } else if (path == '/dealer/customer-groups') {
      screen = const DealerCustomerGroupsScreen();
    } else if (path == '/dealer/pricing') {
      screen = const DealerPricingScreen();
    } else if (path == '/dealer/pos') {
      screen = const DealerPosScreen();
    } else if (path == '/dealer/sales') {
      screen = const DealerSalesHistoryScreen();
    } else if (path == '/dealer/profile') {
      screen = const UserProfileScreen();
    } else if (path == '/kcs' || path == '/kcs/home') {
      screen = const KcsDashboardScreen();
    } else if (path.startsWith('/kcs/inspection/')) {
      final locId = path.replaceAll('/kcs/inspection/', '');
      screen = InspectionFormScreen(locationId: locId);
    } else if (path == '/manager/kcs-staff') {
      screen = const KcsStaffListScreen();
    } else if (path.startsWith('/manager/kcs-staff/')) {
      final id = path.replaceAll('/manager/kcs-staff/', '');
      screen = KcsStaffDetailScreen(staffId: id);
    } else if (path == '/manager/dashboard') {
      screen = const DashboardScreen();
    } else if (path == '/consumer') {
      screen = const ModernHomeScreen();
    } else if (path.startsWith('/consumer/weather')) {
      final uri = Uri.tryParse(path);
      final lat = double.tryParse(uri?.queryParameters['lat'] ?? '') ?? 21.0285;
      final lon = double.tryParse(uri?.queryParameters['lon'] ?? '') ?? 105.8542;
      screen = WeatherDetailScreen(lat: lat, lon: lon);
    } else if (path == '/consumer/notifications') {
      screen = const PlaceholderScreen(title: 'Thông báo');
    }
    
    if (screen != null) {
      return Navigator.of(this).push<T>(
        MaterialPageRoute(builder: (context) => screen!),
      );
    }
    
    print('Navigation path not matched: $path');
    return Future.value(null);
  }
  
  void go(String path, {Object? extra}) {
    push(path, extra: extra);
  }
}

