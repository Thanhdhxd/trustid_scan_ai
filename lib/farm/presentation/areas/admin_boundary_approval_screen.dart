import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';
import '../../data/farm_repository.dart';
import '../../domain/location.dart';

class AdminBoundaryApprovalScreen extends ConsumerStatefulWidget {
  const AdminBoundaryApprovalScreen({super.key});

  @override
  ConsumerState<AdminBoundaryApprovalScreen> createState() => _AdminBoundaryApprovalScreenState();
}

class _AdminBoundaryApprovalScreenState extends ConsumerState<AdminBoundaryApprovalScreen> {
  bool _isLoading = true;
  List<GrowingLocation> _pendingList = [];
  bool _autoApprove = false;
  bool _isUpdatingConfig = false;

  // Theme Constants
  static const Color kPrimaryColor = Color(0xFF00875A);
  static const Color kBackgroundDark = Color(0xFF0F2B46);
  static const Color kSurfaceDark = Color(0xFF16325B);
  static const Color kTextLight = Color(0xFFE8EDF3);
  static const Color kTextGray = Color(0xFF94A3B8);
  static const Color kWarningColor = Colors.orange;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(farmRepositoryProvider);
      final list = await repo.getPendingApprovals();
      final config = await repo.getFarmConfig();
      
      if (mounted) {
        setState(() {
          _pendingList = list;
          _autoApprove = config['autoApproveBoundary'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanErrorMessage(e))));
      }
    }
  }

  Future<void> _toggleAutoApprove(bool value) async {
    setState(() => _isUpdatingConfig = true);
    try {
      await ref.read(farmRepositoryProvider).saveFarmConfig({'autoApproveBoundary': value});
      setState(() {
        _autoApprove = value;
        _isUpdatingConfig = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value ? 'Đã bật Tự động duyệt' : 'Đã tắt Tự động duyệt')));
    } catch (e) {
      setState(() => _isUpdatingConfig = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanErrorMessage(e))));
    }
  }

  Future<void> _approve(String id) async {
    try {
      await ref.read(farmRepositoryProvider).approveBoundary(id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã phê duyệt ranh giới')));
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanErrorMessage(e))));
    }
  }

  Future<void> _reject(String id) async {
    try {
      await ref.read(farmRepositoryProvider).rejectBoundary(id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã từ chối ranh giới')));
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      appBar: AppBar(
        title: const Text('Duyệt Ranh Giới', style: TextStyle(color: kTextLight)),
        backgroundColor: kBackgroundDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextGray),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: kPrimaryColor,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : CustomScrollView(
              slivers: [
                // Config Section
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: kSurfaceDark, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        const Icon(Icons.settings_suggest, color: kPrimaryColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tự động duyệt ranh giới', style: TextStyle(fontWeight: FontWeight.bold, color: kTextLight)),
                              Text('Hệ thống sẽ tự động duyệt các thay đổi vùng trồng.', style: TextStyle(fontSize: 12, color: kTextGray)),
                            ],
                          ),
                        ),
                        if (_isUpdatingConfig)
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          Switch(
                            value: _autoApprove,
                            onChanged: _toggleAutoApprove,
                            activeColor: kPrimaryColor,
                          )
                      ],
                    ),
                  ),
                ),

                // List Section
                if (_pendingList.isEmpty)
                  const SliverFillRemaining(child: Center(child: Text('Không có yêu cầu nào đang chờ duyệt', style: TextStyle(color: kTextGray))))
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final loc = _pendingList[index];
                        return _buildRequestCard(loc);
                      },
                      childCount: _pendingList.length,
                    ),
                  ),
                
                const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
              ],
            ),
      ),
    );
  }

  Widget _buildRequestCard(GrowingLocation loc) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceDark, 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kWarningColor.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(loc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextLight)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: kWarningColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Text('CHỜ DUYỆT', style: TextStyle(color: kWarningColor, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 8),
          Text('Mã: ${loc.code ?? 'N/A'} • Diện tích: ${loc.areaM2.toStringAsFixed(0)} m²', style: const TextStyle(color: kTextGray, fontSize: 13)),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/manager/location-detail/${loc.id}'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: kPrimaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('XEM BẢN ĐỒ', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _reject(loc.id),
                icon: const Icon(Icons.close, color: Colors.redAccent),
                style: IconButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _approve(loc.id),
                icon: const Icon(Icons.check, color: kPrimaryColor),
                style: IconButton.styleFrom(backgroundColor: kPrimaryColor.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          )
        ],
      ),
    );
  }
}
