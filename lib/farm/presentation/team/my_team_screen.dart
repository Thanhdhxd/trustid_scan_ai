import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/core/utils/error_utils.dart';
import '../../data/farm_repository.dart';
import '../../domain/location.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';

const Color kPrimaryColor = Color(0xFF00875A);
const Color kBackgroundDark = Color(0xFF0F2B46);
const Color kSurfaceDark = Color(0xFF163452);
const Color kTextLight = Color(0xFFE8EDF3);
const Color kTextGray = Color(0xFF94A3B8);

class MyTeamScreen extends ConsumerStatefulWidget {
  const MyTeamScreen({super.key});

  @override
  ConsumerState<MyTeamScreen> createState() => _MyTeamScreenState();
}

class _MyTeamScreenState extends ConsumerState<MyTeamScreen> {
  bool _isLoading = true;
  List<GrowingLocation> _locations = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final repo = ref.read(farmRepositoryProvider);
      final authState = ref.read(authControllerProvider);
      if (authState.value?.id == null) return;
      final locs = await repo.getLeaderMap(authState.value!.id);
      if (mounted) {
        setState(() {
          _locations = locs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleanErrorMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: kBackgroundDark,
        body: Center(child: CircularProgressIndicator(color: kPrimaryColor)),
      );
    }

    final farmersMap = <String, Map<String, dynamic>>{};
    for (var loc in _locations) {
      if (loc.farmer != null) {
        final farmerId = loc.farmer!['id'] as String;
        if (!farmersMap.containsKey(farmerId)) {
          farmersMap[farmerId] = {
            'farmer': loc.farmer,
            'locations': <GrowingLocation>[],
          };
        }
        (farmersMap[farmerId]!['locations'] as List<GrowingLocation>).add(loc);
      }
    }

    final farmersList = farmersMap.values.toList();

    return Scaffold(
      backgroundColor: kBackgroundDark,
      appBar: AppBar(
        title: const Text('Quản lý Nông dân', style: TextStyle(color: kTextLight)),
        backgroundColor: kBackgroundDark,
        iconTheme: const IconThemeData(color: kTextLight),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Tìm nông dân...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: kSurfaceDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          
          Expanded(
            child: farmersList.isEmpty
                ? const Center(
                    child: Text(
                      'Bạn chưa quản lý nông dân nào',
                      style: TextStyle(color: kTextGray, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: farmersList.length,
                    itemBuilder: (context, index) {
                      final item = farmersList[index];
                      final farmer = item['farmer'] as Map<String, dynamic>;
                      final locs = item['locations'] as List<GrowingLocation>;
                      
                      final farmerName = (farmer['fullName'] ?? farmer['full_name'] ?? 'Chưa cập nhật tên').toString();
                      final username = (farmer['username'] ?? '').toString();
                      
                      // Lọc local
                      if (_searchQuery.isNotEmpty) {
                        if (!farmerName.toLowerCase().contains(_searchQuery) &&
                            !username.toLowerCase().contains(_searchQuery)) {
                          return const SizedBox.shrink();
                        }
                      }

                      return Card(
                        color: kSurfaceDark,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: kPrimaryColor.withOpacity(0.2),
                            radius: 24,
                            child: const Icon(Icons.person, color: kPrimaryColor),
                          ),
                          title: Text(
                            farmerName,
                            style: const TextStyle(color: kTextLight, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                username,
                                style: const TextStyle(color: kTextGray),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${locs.length} thửa đang canh tác',
                                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, color: kTextGray, size: 16),
                          onTap: () {
                            _showFarmerLocations(context, farmer, locs);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showFarmerLocations(BuildContext context, Map<String, dynamic> farmer, List<GrowingLocation> locs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lô thửa của ${farmer['fullName'] ?? farmer['username']}',
                    style: const TextStyle(color: kTextLight, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: kTextGray),
                    onPressed: () => Navigator.of(ctx).pop(),
                  )
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: locs.length,
                  itemBuilder: (context, i) {
                    final loc = locs[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: kBackgroundDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.map, color: kPrimaryColor),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                loc.name,
                                style: const TextStyle(
                                  color: kTextLight,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (loc.isOverlapped) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.amber, width: 0.5),
                                ),
                                child: const Text(
                                  '⚠️ Lấn ranh',
                                  style: TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '${loc.areaM2} m2',
                          style: const TextStyle(color: kTextGray),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: kTextGray),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          context.push('/farmer/locations/${loc.id}');
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
