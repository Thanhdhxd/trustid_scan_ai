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

  @override
  FutureOr<void> build() => null;

  Future<Position> _getGPS() async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return Position(longitude: 0, latitude: 0, timestamp: DateTime.now(), accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0);

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        return Position(longitude: 0, latitude: 0, timestamp: DateTime.now(), accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0);
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      return Position(longitude: 0, latitude: 0, timestamp: DateTime.now(), accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0);
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
    });
  }
}

final driverControllerProvider = AsyncNotifierProvider<DriverController, void>(DriverController.new);
