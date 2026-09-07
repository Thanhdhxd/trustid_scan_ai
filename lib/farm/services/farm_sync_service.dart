import 'dart:async';
import 'package:trustid_scan_ai/core/utils/connectivity_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/farm_repository.dart';
import '../presentation/farmer_controller.dart';

final farmSyncServiceProvider = Provider((ref) {
  final service = FarmSyncService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

class FarmSyncService {
  final Ref _ref;
  StreamSubscription? _subscription;
  bool _isSyncing = false;

  FarmSyncService(this._ref) {
    _init();
  }

  void _init() {
    _subscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final hasConnection = results.any((result) => result != ConnectivityResult.none);
      if (hasConnection && !_isSyncing) {
        _sync();
      }
    });
  }

  Future<void> _sync() async {
    _isSyncing = true;
    try {
      final repo = _ref.read(farmRepositoryProvider);
      await repo.processSyncQueue();
      _ref.invalidate(dailyTasksProvider);
    } catch (e) {
      print('Auto-sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
