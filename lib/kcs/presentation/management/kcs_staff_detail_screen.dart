import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/dashboard/data/tenant_repository.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';
import 'kcs_staff_form_dialog.dart';

const Color kPrimaryColor = Color(0xFF00875A);
const Color kBackgroundDark = Color(0xFF0F2B46);
const Color kSurfaceDark = Color(0xFF16325B);
const Color kTextLight = Color(0xFFE8EDF3);
const Color kTextGray = Color(0xFF94A3B8);

class KcsStaffDetailScreen extends ConsumerStatefulWidget {
  final String staffId;
  const KcsStaffDetailScreen({super.key, required this.staffId});

  @override
  ConsumerState<KcsStaffDetailScreen> createState() => _KcsStaffDetailScreenState();
}

class _KcsStaffDetailScreenState extends ConsumerState<KcsStaffDetailScreen> {
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _statsData;
  List<dynamic> _assignedAreas = [];
  List<dynamic> _inspections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStaffDetails();
  }

  Future<void> _fetchStaffDetails() async {
    try {
      final repo = ref.read(tenantRepositoryProvider);
      
      // Fetch all required data concurrently like the web does
      final results = await Future.wait([
        repo.getKcsProfile(widget.staffId),
        repo.getKcsAssignedAreas(widget.staffId),
        repo.getKcsInspections(widget.staffId),
      ]);

      if (mounted) {
        setState(() {
          final profileRes = results[0] as Map<String, dynamic>;
          _profileData = profileRes['profile'];
          _statsData = profileRes['stats'];
          _assignedAreas = results[1] as List<dynamic>;
          _inspections = results[2] as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: kBackgroundDark,
        appBar: AppBar(title: const Text('Hồ sơ Nhân viên KCS'), backgroundColor: kBackgroundDark),
        body: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
      );
    }

    final staffName = _profileData?['fullName'] ?? 'Không có tên';
    final username = _profileData?['username'] ?? '';
    final isActive = _profileData?['status'] == 'ACTIVE' || _profileData?['status'] == 'Hoạt động';
    final initial = staffName.isNotEmpty ? staffName.substring(0, 1).toUpperCase() : '?';

    final upcomingInspections = _inspections.where((i) => i['status'] == 'PENDING').toList();
    final historyInspections = _inspections.where((i) => i['status'] != 'PENDING').toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: kBackgroundDark,
        appBar: AppBar(
          title: const Text('Hồ sơ Nhân viên KCS', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          backgroundColor: kBackgroundDark,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: kSurfaceDark,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: kPrimaryColor.withOpacity(0.2),
                    child: Text(initial, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: kPrimaryColor)),
                  ),
                  const SizedBox(height: 12),
                  Text(staffName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('@$username', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                      border: Border.all(color: isActive ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_profileData?['status'] ?? (isActive ? 'Hoạt động' : 'Tạm khóa'), style: TextStyle(color: isActive ? Colors.greenAccent : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 24),
                  
                  // Statistics
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem('Vùng trồng', _statsData?['totalAssignedAreas']?.toString() ?? '0', Icons.landscape),
                      _buildStatItem('Chờ duyệt', _statsData?['pendingInspections']?.toString() ?? '0', Icons.pending_actions, color: Colors.orangeAccent),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Tabs
            TabBar(
              isScrollable: true,
              indicatorColor: kPrimaryColor,
              labelColor: kPrimaryColor,
              unselectedLabelColor: Colors.white54,
              indicatorWeight: 3,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              tabs: const [
                Tab(text: 'Nhiệm vụ (Đến hạn)'),
                Tab(text: 'Vùng phân công'),
                Tab(text: 'Lịch sử'),
              ],
            ),
            
            // Tab Content
            Expanded(
              child: TabBarView(
                children: [
                  _buildUpcomingTab(upcomingInspections),
                  _buildAreasTab(_assignedAreas),
                  _buildHistoryTab(historyInspections),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.white54, size: 20),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildEmptyTab(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.white10),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildUpcomingTab(List<dynamic> upcoming) {
    if (upcoming.isEmpty) return _buildEmptyTab('Không có dữ liệu nhiệm vụ', Icons.assignment_outlined);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: upcoming.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = upcoming[index];
        final locationName = item['location']?['name'] ?? '—';
        final createdAt = item['createdAt'] != null ? item['createdAt'].toString().substring(0, 16).replaceAll('T', ' ') : '—';
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: kSurfaceDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(locationName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text('Ngày tạo: $createdAt\nTrạng thái: Đang chờ', style: const TextStyle(color: Colors.white54)),
            ),
            trailing: const Icon(Icons.warning, color: Colors.orangeAccent),
          ),
        );
      },
    );
  }

  Widget _buildAreasTab(List<dynamic> areas) {
    if (areas.isEmpty) return _buildEmptyTab('Không có dữ liệu vùng trồng', Icons.landscape_outlined);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: areas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = areas[index];
        final areaHa = ((item['maxAreaM2'] ?? 0) / 10000).toStringAsFixed(2);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: kSurfaceDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.landscape, color: kPrimaryColor),
            title: Text(item['name'] ?? '—', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('Diện tích: $areaHa ha\nTỉnh/Thành: ${item['province'] ?? '—'}', style: const TextStyle(color: Colors.white54)),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab(List<dynamic> history) {
    if (history.isEmpty) return _buildEmptyTab('Không có lịch sử kiểm định', Icons.history);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = history[index];
        final isPassed = item['status'] == 'PASSED';
        final date = item['inspectionDate'] ?? item['updatedAt'];
        final dateStr = date != null ? date.toString().substring(0, 16).replaceAll('T', ' ') : '—';
        final locationName = item['location']?['name'] ?? '—';
        final notes = item['notes'] ?? '';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kSurfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dateStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPassed ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      border: Border.all(color: isPassed ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(isPassed ? 'ĐẠT' : 'KHÔNG ĐẠT', style: TextStyle(color: isPassed ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(locationName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(notes, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ]
            ],
          ),
        );
      },
    );
  }
}
