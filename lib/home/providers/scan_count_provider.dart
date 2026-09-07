import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final scanCountProvider = NotifierProvider<ScanCountNotifier, int>(() {
  return ScanCountNotifier();
});

class ScanCountNotifier extends Notifier<int> {
  static const _key = 'user_scan_count';

  @override
  int build() {
    _loadCount();
    return 0;
  }

  Future<void> _loadCount() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_key) ?? 0;
  }

  Future<void> increment() async {
    state++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, state);
  }
}
