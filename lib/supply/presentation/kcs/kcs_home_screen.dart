import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';
import 'package:trustid_scan_ai/auth/user_profile_screen.dart';
import 'package:trustid_scan_ai/core/api_client.dart';
import 'package:trustid_scan_ai/core/widgets/skeleton_loader.dart';
import 'package:trustid_scan_ai/core/widgets/user_avatar.dart';
import 'package:trustid_scan_ai/scan/scanner_screen.dart';
import 'package:trustid_scan_ai/home/modern_home_screen.dart';
import 'package:intl/intl.dart';

const Color _kBg = Color(0xFF0F2B46);
const Color _kSurface = Color(0xFF16325B);
const Color _kPrimary = Color(0xFF00875A);
const Color _kText = Color(0xFFE8EDF3);
const Color _kGray = Color(0xFF94A3B8);
const Color _kKAccent = Color(0xFFE11D48); // Rose for KCS

// ---------- Provider ----------
final _kcsRecentProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final res = await companyApi.get('/supply/kcs/recent', queryParameters: {'limit': 20});
    final data = res.data;
    return data is List ? data : (data['items'] ?? []);
  } catch (_) {
    return [];
  }
});

// ---------- Screen ----------
class KcsHomeScreen extends ConsumerStatefulWidget {
  const KcsHomeScreen({super.key});

  @override
  ConsumerState<KcsHomeScreen> createState() => _KcsHomeScreenState();
}

class _KcsHomeScreenState extends ConsumerState<KcsHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authControllerProvider);
    final user = authAsync.value;
    final recentAsync = ref.watch(_kcsRecentProvider);

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          _buildHeader(context, user),
          Expanded(
            child: RefreshIndicator(
              color: _kKAccent,
              onRefresh: () async {
                ref.invalidate(_kcsRecentProvider);
                await Future.delayed(const Duration(milliseconds: 300));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    // Big Scan Button
                    _buildScanCTA(context),
                    const SizedBox(height: 24),
                    // Stats
                    recentAsync.when(
                      data: (items) {
                        final today = items.where((i) {
                          final d = i['createdAt'] ?? i['created_at'] ?? '';
                          if (d.isEmpty) return false;
                          final dt = DateTime.tryParse(d);
                          if (dt == null) return false;
                          final now = DateTime.now();
                          return dt.year == now.year && dt.month == now.month && dt.day == now.day;
                        }).length;
                        final failed = items.where((i) {
                          final r = (i['result'] ?? i['status'] ?? '').toString().toUpperCase();
                          return r == 'FAIL' || r == 'REJECTED';
                        }).length;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStats(today, failed, items.length),
                            const SizedBox(height: 24),
                            _buildRecentSection(items),
                          ],
                        );
                      },
                      loading: () => const SingleChildScrollView(child: SkeletonListView(count: 5)),
                      error: (_, __) => Column(children: [
                        _buildStats(0, 0, 0),
                        const SizedBox(height: 24),
                        const Center(child: Text('Chưa thể tải dữ liệu KCS', style: TextStyle(color: _kGray))),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic user) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 12, left: 16, right: 16,
      ),
      decoration: BoxDecoration(
        color: _kBg.withOpacity(0.97),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          UserAvatar(
            avatarUrl: user?.avatar,
            fullName: user?.fullName ?? 'KCS',
            size: 48,
            borderColor: _kKAccent,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserProfileScreen())),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Nhân viên KCS', style: TextStyle(color: _kGray, fontSize: 12)),
              Text(user?.fullName ?? 'KCS', style: const TextStyle(color: _kText, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _kKAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kKAccent.withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.verified_outlined, size: 14, color: _kKAccent),
              SizedBox(width: 4),
              Text('KCS', style: TextStyle(color: _kKAccent, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.home_outlined, color: _kGray),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const ModernHomeScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScanCTA(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => _doScan(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_kKAccent.withOpacity(0.8), _kKAccent.withOpacity(0.4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kKAccent.withOpacity(0.3)),
            boxShadow: [BoxShadow(color: _kKAccent.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(children: const [
            Icon(Icons.qr_code_scanner, color: Colors.white, size: 56),
            SizedBox(height: 12),
            Text('QUÉT MÃ KCS', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            SizedBox(height: 4),
            Text('Nhấn để quét mã bao sản phẩm', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ),
      ),
    );
  }

  Widget _buildStats(int today, int failed, int total) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        _statCard('Hôm nay', today.toString(), Icons.today_outlined, _kKAccent),
        const SizedBox(width: 12),
        _statCard('Lỗi', failed.toString(), Icons.cancel_outlined, Colors.redAccent),
        const SizedBox(width: 12),
        _statCard('Tổng KCS', total.toString(), Icons.verified_outlined, _kPrimary),
      ]),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: _kGray, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _buildRecentSection(List<dynamic> items) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Column(children: [
            Icon(Icons.assignment_turned_in_outlined, size: 56, color: Colors.white12),
            SizedBox(height: 12),
            Text('Chưa có bao nào được KCS', style: TextStyle(color: _kGray, fontSize: 14)),
          ]),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text('Đã kiểm gần đây', style: TextStyle(color: _kText, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        ...items.map((item) => _buildKcsCard(item)),
      ],
    );
  }

  Widget _buildKcsCard(dynamic item) {
    final code = item['bagCode'] ?? item['bag_code'] ?? item['code'] ?? item['serial'] ?? 'N/A';
    final result = (item['result'] ?? item['status'] ?? 'PASS').toString().toUpperCase();
    final isPassed = result == 'PASS' || result == 'APPROVED';
    final color = isPassed ? _kPrimary : Colors.redAccent;
    final icon = isPassed ? Icons.check_circle_outline : Icons.cancel_outlined;
    final dateRaw = item['createdAt'] ?? item['created_at'] ?? '';
    final dateStr = dateRaw.isNotEmpty ? DateFormat('dd/MM HH:mm').format(DateTime.tryParse(dateRaw) ?? DateTime.now()) : '';
    final note = item['note'] ?? item['comment'] ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(code, style: const TextStyle(color: _kText, fontWeight: FontWeight.bold, fontSize: 14)),
            if (dateStr.isNotEmpty) Text(dateStr, style: const TextStyle(color: _kGray, fontSize: 12)),
            if (note.isNotEmpty) Text(note, style: const TextStyle(color: _kGray, fontSize: 11), overflow: TextOverflow.ellipsis),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Text(isPassed ? 'Đạt' : 'Không đạt', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _doScan(BuildContext context) async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen(title: 'Quét mã KCS', returnCode: true)),
    );
    if (code == null || code.isEmpty || !mounted) return;
    _showKcsResultDialog(context, code);
  }

  Future<void> _showKcsResultDialog(BuildContext context, String code) async {
    String? selectedResult = 'PASS';
    final noteCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: _kSurface,
          title: const Text('Kết quả kiểm tra KCS', style: TextStyle(color: _kText, fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mã bao: $code', style: const TextStyle(color: _kGray, fontSize: 13)),
            const SizedBox(height: 16),
            const Text('Kết quả:', style: TextStyle(color: _kGray, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(children: [
              _resultChip('Đạt', 'PASS', selectedResult, _kPrimary, (v) => setState(() => selectedResult = v)),
              const SizedBox(width: 10),
              _resultChip('Không đạt', 'FAIL', selectedResult, Colors.redAccent, (v) => setState(() => selectedResult = v)),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              style: const TextStyle(color: _kText, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Ghi chú (tùy chọn)...',
                hintStyle: const TextStyle(color: _kGray, fontSize: 12),
                filled: true, fillColor: _kBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
              ),
              maxLines: 2,
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy', style: TextStyle(color: _kGray))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _kKAccent),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Lưu KCS'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await companyApi.post('/supply/kcs', data: {
        'bag_code': code,
        'result': selectedResult,
        'note': noteCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(selectedResult == 'PASS' ? 'KCS Đạt — Lưu thành công!' : 'KCS Không đạt — Đã ghi nhận'),
            backgroundColor: selectedResult == 'PASS' ? _kPrimary : Colors.redAccent));
        ref.invalidate(_kcsRecentProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu KCS: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Widget _resultChip(String label, String value, String? selected, Color color, void Function(String) onTap) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : Colors.white24),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? color : _kGray, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}
