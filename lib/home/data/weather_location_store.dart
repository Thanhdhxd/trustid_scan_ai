import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'consumer_models.dart';

final weatherLocationStoreProvider = Provider((ref) => WeatherLocationStore());

class WeatherLocationStore {
  static const _selectedKey = 'weather_selected_location';
  static const _savedKey = 'weather_saved_locations';

  Future<List<WeatherFavoriteLocation>> getSavedLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedKey);
    if (raw == null || raw.isEmpty) {
      final defaults = [WeatherFavoriteLocation.hanoi];
      await saveLocations(defaults);
      return defaults;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final locations = decoded
            .whereType<Map>()
            .map(
              (item) => WeatherFavoriteLocation.fromJson(
                item.cast<String, dynamic>(),
              ),
            )
            .where((location) => location.id.isNotEmpty)
            .toList();
        if (locations.isNotEmpty) return locations;
      }
    } catch (_) {}

    final fallback = [WeatherFavoriteLocation.hanoi];
    await saveLocations(fallback);
    return fallback;
  }

  Future<void> saveLocations(List<WeatherFavoriteLocation> locations) async {
    final prefs = await SharedPreferences.getInstance();
    final safeLocations = locations.isEmpty
        ? [WeatherFavoriteLocation.hanoi]
        : locations;
    await prefs.setString(
      _savedKey,
      jsonEncode(safeLocations.map((location) => location.toJson()).toList()),
    );
  }

  Future<WeatherFavoriteLocation> getSelectedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocations = await getSavedLocations();
    final raw = prefs.getString(_selectedKey);

    if (raw != null && raw.isNotEmpty) {
      try {
        final selected = WeatherFavoriteLocation.fromJson(
          (jsonDecode(raw) as Map).cast<String, dynamic>(),
        );
        final matched = savedLocations
            .where((location) => location.id == selected.id)
            .toList();
        if (matched.isNotEmpty) return matched.first;
      } catch (_) {}
    }

    final fallback = savedLocations.first;
    await setSelectedLocation(fallback);
    return fallback;
  }

  Future<void> setSelectedLocation(WeatherFavoriteLocation location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey, jsonEncode(location.toJson()));
  }

  Future<List<WeatherFavoriteLocation>> addLocation(
    WeatherFavoriteLocation location,
  ) async {
    final locations = await getSavedLocations();
    final filtered = locations.where((item) => item.id != location.id).toList();
    final next = [location, ...filtered];
    await saveLocations(next);
    await setSelectedLocation(location);
    return next;
  }

  Future<WeatherLocationRemovalResult> removeLocation(String id) async {
    final locations = await getSavedLocations();
    if (locations.length <= 1) {
      return WeatherLocationRemovalResult(
        locations: locations,
        selected: locations.first,
        removed: false,
      );
    }

    final next = locations.where((location) => location.id != id).toList();
    final safeNext = next.isEmpty ? [WeatherFavoriteLocation.hanoi] : next;
    await saveLocations(safeNext);

    final current = await getSelectedLocation();
    final selected = current.id == id ? safeNext.first : current;
    await setSelectedLocation(selected);

    return WeatherLocationRemovalResult(
      locations: safeNext,
      selected: selected,
      removed: true,
    );
  }
}

class WeatherLocationRemovalResult {
  final List<WeatherFavoriteLocation> locations;
  final WeatherFavoriteLocation selected;
  final bool removed;

  WeatherLocationRemovalResult({
    required this.locations,
    required this.selected,
    required this.removed,
  });
}
