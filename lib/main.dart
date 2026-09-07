import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'auth/login_screen.dart';
import 'core/api_client.dart';
import 'home/widgets/consumer_theme.dart';
import 'home/modern_home_screen.dart';
import 'auth/presentation/auth_controller.dart';
import 'dashboard/dashboard_screen.dart';
import 'farm/presentation/home/farmer_home_screen.dart';
import 'supply/presentation/driver/driver_home_screen.dart';
import 'supply/presentation/warehouse/warehouse_home_screen.dart';
import 'supply/presentation/dealer/dealer_home_screen.dart';
import 'kcs/presentation/kcs_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Khởi tạo Hive để lưu Lịch sử cục bộ (Local History)
  await Hive.initFlutter();
  await Hive.openBox('scan_history');
  
  // Cấu hình interceptor cho API
  // Interceptors được khởi tạo trực tiếp trong api_client.dart

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'TrustID Scan AI Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: ConsumerTheme.actionBlue,
        useMaterial3: true,
        scaffoldBackgroundColor: ConsumerTheme.backgroundDark,
      ),
      home: authState.when(
        data: (user) {
          if (user != null) {
            final role = user.role.toUpperCase();
            if (['FARMER', 'TEAM_LEADER'].contains(role)) {
              return const FarmerHomeScreen();
            }
            if (['DRIVER', 'TRANSPORTER'].contains(role)) {
              return const DriverHomeScreen();
            }
            if (role == 'WAREHOUSE_MANAGER') {
              return const WarehouseHomeScreen();
            }
            if (role == 'DEALER') {
              return const DealerHomeScreen();
            }
            if (role == 'KCS_STAFF') {
              return const KcsDashboardScreen();
            }
            if (['MANAGER', 'ADMIN', 'TENANT_ADMIN', 'TENANT'].contains(role)) {
              return DashboardScreen(userProfile: user.toJson());
            }
          }
          return const ModernHomeScreen();
        },
        loading: () => const Scaffold(
          backgroundColor: ConsumerTheme.backgroundDark,
          body: Center(
            child: CircularProgressIndicator(color: ConsumerTheme.actionBlue),
          ),
        ),
        error: (_, __) => const ModernHomeScreen(),
      ),
    );
  }
}
