import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../data/consumer_models.dart';
import '../data/home_stats_repository.dart';
import '../data/weather_location_store.dart';

class WeatherDetailScreen extends ConsumerStatefulWidget {
  final double lat;
  final double lon;

  const WeatherDetailScreen({
    super.key,
    required this.lat,
    required this.lon,
  });

  @override
  ConsumerState<WeatherDetailScreen> createState() => _WeatherDetailScreenState();
}

class _WeatherDetailScreenState extends ConsumerState<WeatherDetailScreen> {
  late WeatherFavoriteLocation _selectedLocation;
  List<WeatherFavoriteLocation> _locations = [];
  bool _addingLocation = false;
  int _refreshNonce = 0;

  @override
  void initState() {
    super.initState();
    _selectedLocation = WeatherFavoriteLocation(
      id: 'current',
      name: 'Vị trí hiện tại',
      lat: widget.lat,
      lon: widget.lon,
    );
    _initLocations();
  }

  Future<void> _initLocations() async {
    final store = ref.read(weatherLocationStoreProvider);
    final saved = await store.getSavedLocations();
    final selected = await store.getSelectedLocation();

    final matchedSaved = saved
        .where((loc) => (loc.lat - widget.lat).abs() < 0.0001 && (loc.lon - widget.lon).abs() < 0.0001)
        .toList();

    WeatherFavoriteLocation active = selected;
    if (matchedSaved.isNotEmpty) {
      active = matchedSaved.first;
    } else {
      active = WeatherFavoriteLocation(
        id: 'initial_${widget.lat}_${widget.lon}',
        name: selected.name.isNotEmpty ? selected.name : 'Vị trí hiện tại',
        lat: widget.lat,
        lon: widget.lon,
      );
    }

    if (!mounted) return;
    setState(() {
      _locations = saved;
      _selectedLocation = active;
    });
  }

  Future<void> _selectLocation(WeatherFavoriteLocation location) async {
    setState(() => _selectedLocation = location);
    await ref.read(weatherLocationStoreProvider).setSelectedLocation(location);
  }

  Future<void> _deleteLocation(WeatherFavoriteLocation location) async {
    final res = await ref.read(weatherLocationStoreProvider).removeLocation(location.id);
    if (!mounted) return;
    if (!res.removed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần giữ ít nhất 1 vị trí theo dõi')),
      );
      return;
    }
    setState(() {
      _locations = res.locations;
      _selectedLocation = res.selected;
    });
  }

  Future<void> _addCurrentLocation() async {
    setState(() => _addingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng cấp quyền vị trí để thêm')),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );

      final geo = await ref.read(homeStatsRepositoryProvider).reverseGeocode(
        lat: pos.latitude,
        lon: pos.longitude,
      );

      final name = (geo?.district != null && geo?.city != null)
          ? '${geo!.district}, ${geo.city}'
          : (geo?.city ?? 'Vị trí của tôi');

      final newLoc = WeatherFavoriteLocation(
        id: 'loc_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        lat: pos.latitude,
        lon: pos.longitude,
      );

      final next = await ref.read(weatherLocationStoreProvider).addLocation(newLoc);
      if (!mounted) return;
      setState(() {
        _locations = next;
        _selectedLocation = newLoc;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thêm vị trí: $name')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể lấy vị trí hiện tại: $e')),
      );
    } finally {
      if (mounted) setState(() => _addingLocation = false);
    }
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'warning':
        return const Color(0xFFEF4444);
      case 'caution':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF20A376);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'warning':
        return const Color(0xFFEF4444);
      case 'caution':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF20A376);
    }
  }

  IconData _weatherIcon(String icon) {
    if (icon.contains('rain')) return Icons.water_drop;
    if (icon.contains('thunder')) return Icons.bolt;
    if (icon.contains('cloud')) return Icons.cloud;
    return Icons.wb_sunny;
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(
      weatherDetailProvider((
        lat: _selectedLocation.lat,
        lon: _selectedLocation.lon,
        refreshNonce: _refreshNonce,
      )),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Chi tiết thời tiết', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF20A376)),
            onPressed: () => setState(() => _refreshNonce++),
          ),
        ],
      ),
      body: detailAsync.when(
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Không có dữ liệu thời tiết', style: TextStyle(color: Colors.white70)));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _locationManagerCard(),
              const SizedBox(height: 14),

              // Overview Card
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedLocation.name,
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${data.current['temp'] ?? 0}°C',
                                style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900),
                              ),
                              Text(
                                data.current['description']?.toString() ?? '',
                                style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        Icon(_weatherIcon(data.current['icon']?.toString() ?? 'sunny'), color: const Color(0xFFF59E0B), size: 54),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _metric('Độ ẩm', '${data.current['humidity'] ?? 0}%', Icons.water_drop_outlined),
                        const SizedBox(width: 8),
                        _metric('Gió', '${data.current['wind_speed'] ?? 0} km/h', Icons.air),
                        const SizedBox(width: 8),
                        _metric('Mưa 6h tới', '${data.next6hRainProb}%', Icons.umbrella_outlined),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Realtime Alerts
              if (data.alerts.isNotEmpty) ...[
                ...data.alerts.map((alert) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _severityColor(alert.severity).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _severityColor(alert.severity).withOpacity(0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: _severityColor(alert.severity), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert.title,
                              style: TextStyle(color: _severityColor(alert.severity), fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              alert.message,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 4),
              ],

              // Hourly Forecast
              if (data.hourly.isNotEmpty) ...[
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dự báo 24 giờ tới',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 105,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: data.hourly.length > 24 ? 24 : data.hourly.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, idx) {
                            final h = data.hourly[idx];
                            return Container(
                              width: 62,
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(h['hour']?.toString() ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  Icon(_weatherIcon(h['icon']?.toString() ?? ''), color: const Color(0xFF60A5FA), size: 20),
                                  Text('${h['temp'] ?? 0}°', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('${h['rain_probability'] ?? 0}%', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 7-day Daily Forecast
              if (data.daily.isNotEmpty) ...[
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dự báo 7 ngày tới',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      ...data.daily.map((d) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 70,
                              child: Text(
                                '${d['day_name'] ?? ''} (${d['date'] ?? ''})',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                            Icon(_weatherIcon(d['icon']?.toString() ?? ''), color: const Color(0xFF60A5FA), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                d['description']?.toString() ?? '',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${d['rain_probability'] ?? 0}%',
                              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${d['temp_min'] ?? 0}° / ${d['temp_max'] ?? 0}°',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Farm Advice
              if (data.farmAdvice.isNotEmpty) ...[
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.eco, color: Color(0xFF10B981), size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Khuyến cáo nông vụ',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...data.farmAdvice.map((a) {
                        final status = a['status']?.toString() ?? 'good';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: _statusColor(status).withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(10),
                            color: _statusColor(status).withOpacity(0.08),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a['title']?.toString() ?? '',
                                style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                a['detail']?.toString() ?? '',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF20A376))),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Không thể tải dữ liệu thời tiết', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => setState(() => _refreshNonce++),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locationManagerCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Vị trí theo dõi',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              TextButton.icon(
                onPressed: _addingLocation ? null : _addCurrentLocation,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF20A376),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: _addingLocation
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF20A376)))
                    : const Icon(Icons.add_location_alt, size: 16),
                label: const Text('Thêm vị trí', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _locations.map((loc) {
              final selected = loc.id == _selectedLocation.id;
              return InputChip(
                label: Text(loc.name.isEmpty ? 'Vị trí đã lưu' : loc.name),
                selected: selected,
                showCheckmark: false,
                onPressed: () => _selectLocation(loc),
                onDeleted: () => _deleteLocation(loc),
                deleteIcon: Icon(Icons.close, size: 16, color: selected ? const Color(0xFF34D399) : Colors.white70),
                backgroundColor: const Color(0xFF151E30),
                selectedColor: const Color(0xFF20A376).withOpacity(0.25),
                labelStyle: TextStyle(
                  color: selected ? const Color(0xFF34D399) : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                side: BorderSide(color: selected ? const Color(0xFF20A376) : Colors.white.withOpacity(0.1)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: child,
    );
  }

  Widget _metric(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
