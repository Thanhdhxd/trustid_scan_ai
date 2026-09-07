import 'package:flutter/material.dart';

import 'risk_repository.dart';

/// Màn hình CHỈ DÙNG ĐỂ DEMO/KIỂM THỬ - cho phép giả lập vị trí và thời
/// gian mà không cần di chuyển thật hay chờ thời gian thật trôi qua.
/// KHÔNG phải tính năng đưa cho người dùng cuối.
class DebugDemoScreen extends StatefulWidget {
  const DebugDemoScreen({super.key});

  @override
  State<DebugDemoScreen> createState() => _DebugDemoScreenState();
}

class _DebugDemoScreenState extends State<DebugDemoScreen> {
  final _riskRepo = RiskRepository();
  final _codeController = TextEditingController(text: 'DEMO-001');

  final DateTime _baseTime = DateTime.now();
  int _minutesOffset = 0;
  bool _loading = false;
  String? _resultText;

  // Toạ độ dựng sẵn - bấm nút thay vì phải đi tới nơi thật
  static const _locations = <String, List<double>>{
    'Hà Nội': [21.0278, 105.8342],
    'TP.HCM': [10.7626, 106.6602],
    'Đà Nẵng': [16.0544, 108.2022],
  };

  Future<void> _sendScan(String locationName) async {
    setState(() {
      _loading = true;
      _resultText = null;
    });

    try {
      final coords = _locations[locationName]!;
      final fakeTime = _baseTime.add(Duration(minutes: _minutesOffset));

      final result = await _riskRepo.getRiskScore(
        code: _codeController.text,
        lat: coords[0],
        long: coords[1],
        timestamp: fakeTime,
      );

      setState(() {
        _resultText = 'Quét tại $locationName lúc +$_minutesOffset phút\n'
            'Kết quả: ${result.level} (score=${result.anomalyScore})\n'
            'Khoảng cách: ${result.distanceKm} km | '
            'Cách lần trước: ${result.minutesSincePrev} phút';
      });
    } catch (e) {
      setState(() => _resultText = 'Lỗi: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Color _colorForResult() {
    if (_resultText == null) return Colors.grey.shade200;
    if (_resultText!.contains('HIGH_RISK')) return Colors.red.shade50;
    if (_resultText!.contains('WATCH')) return Colors.orange.shade50;
    if (_resultText!.contains('NORMAL')) return Colors.green.shade50;
    return Colors.grey.shade200;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Demo'),
        backgroundColor: Colors.deepOrange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.deepOrange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Màn hình này CHỈ dùng để kiểm thử/demo - cho phép giả lập '
                'vị trí và thời gian thay vì phải di chuyển/chờ thật.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Mã sản phẩm demo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            Text('Giả lập trôi thời gian: +$_minutesOffset phút'),
            Slider(
              value: _minutesOffset.toDouble(),
              min: 0,
              max: 120,
              divisions: 24,
              label: '$_minutesOffset phút',
              onChanged: (v) => setState(() => _minutesOffset = v.toInt()),
            ),
            const SizedBox(height: 8),

            const Text('Bấm để mô phỏng quét tại vị trí:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _locations.keys
                  .map(
                    (name) => ElevatedButton(
                      onPressed: _loading ? null : () => _sendScan(name),
                      child: Text(name),
                    ),
                  )
                  .toList(),
            ),

            const SizedBox(height: 24),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_resultText != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _colorForResult(),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_resultText!),
              ),
          ],
        ),
      ),
    );
  }
}
