import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../domain/shipment.dart';
import '../../data/supply_repository.dart';

final shipmentsProvider = FutureProvider.autoDispose<List<Shipment>>((ref) async {
  final repo = ref.watch(supplyRepositoryProvider);
  return repo.getMyShipments();
});

class DriverController extends AsyncNotifier<void> {
  late final SupplyRepository _repo = ref.read(supplyRepositoryProvider);

  static Position _fallbackPosition() => Position(
        longitude: 0,
        latitude: 0,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );

  @override
  FutureOr<void> build() => null;

  Future<Position> _getGPS() async {
    try {
      return await Future<Position>(() async {
        if (!kIsWeb) {
          try {
            final last = await Geolocator.getLastKnownPosition();
            if (last != null) return last;
          } catch (_) {}
        }

        final enabled = await Geolocator.isLocationServiceEnabled();
        if (!enabled) return _fallbackPosition();

        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
          return _fallbackPosition();
        }

        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(milliseconds: 1500),
          ),
        );
      }).timeout(const Duration(milliseconds: 1500), onTimeout: _fallbackPosition);
    } catch (_) {
      return _fallbackPosition();
    }
  }

  Future<void> confirmPickup(String shipmentId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final pos = await _getGPS();
      await _repo.handshake(
        shipmentId: shipmentId,
        action: 'DRIVER_RECEIVE',
        lat: pos.latitude,
        long: pos.longitude,
      );
      await ref.refresh(shipmentsProvider.future);
    });
  }

  Future<void> confirmDelivery(String shipmentId, {String? signature, String? evidenceUrl}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final pos = await _getGPS();
      await _repo.handshake(
        shipmentId: shipmentId,
        action: 'DRIVER_DELIVER',
        lat: pos.latitude,
        long: pos.longitude,
        signature: signature,
        evidenceUrl: evidenceUrl,
      );
      await ref.refresh(shipmentsProvider.future);
    });
  }
}

final driverControllerProvider = AsyncNotifierProvider<DriverController, void>(DriverController.new);
