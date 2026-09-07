import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/navigation.dart';
import 'package:trustid_scan_ai/dashboard/data/tenant_repository.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';
import 'kcs_staff_detail_screen.dart';
import 'kcs_staff_form_dialog.dart';

const Color kPrimaryColor = Color(0xFF00875A);
const Color kBackgroundDark = Color(0xFF0F2B46);
const Color kSurfaceDark = Color(0xFF16325B);
const Color kTextLight = Color(0xFFE8EDF3);
const Color kTextGray = Color(0xFF94A3B8);

final kcsStaffProvider = FutureProvider.family.autoDispose<List<User>, String>((ref, search) async {
  final repo = ref.watch(tenantRepositoryProvider);
  return repo.getTenantUsers(roleName: 'KCS_STAFF', search: search);
});

class KcsStaffListScreen extends ConsumerStatefulWidget {
  const KcsStaffListScreen({super.key});

  @override
  ConsumerState<KcsStaffListScreen> createState() => _KcsStaffListScreenState();
}

class _KcsStaffListScreenState extends ConsumerState<KcsStaffListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(kcsStaffProvider(_searchQuery));

    return Scaffold(
      backgroundColor: kBackgroundDark,
      appBar: AppBar(
        title: const Text('Nhân viên KCS', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: kBackgroundDark,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const KcsStaffFormDialog(),
          );
        },
        backgroundColor: kPrimaryColor,
        child: const Icon(Icons.person_add_alt_1, color: Colors.white),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Tìm tên hoặc username...',
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: kSurfaceDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          
          // List View
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
              error: (err, stack) => Center(child: Text('Lỗi: $err', style: const TextStyle(color: Colors.redAccent))),
              data: (staffList) {
                if (staffList.isEmpty) {
                  return const Center(child: Text('Không tìm thấy nhân viên nào', style: TextStyle(color: Colors.white54)));
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 88),
                  itemCount: staffList.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final staff = staffList[index];
                    final isActive = staff.status == 'ACTIVE' || staff.status == 'Hoạt động';
                    
                    return InkWell(
                      onTap: () => context.push('/manager/kcs-staff/${staff.id}'),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kSurfaceDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: kPrimaryColor.withOpacity(0.2),
                              child: Text(
                                staff.fullName.isNotEmpty ? staff.fullName.substring(0, 1).toUpperCase() : '?',
                                style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 16),
                            
                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    staff.fullName.isNotEmpty ? staff.fullName : 'Chưa có tên',
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '@${staff.username}',
                                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Status & Action
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isActive ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isActive ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    isActive ? 'Hoạt động' : 'Tạm khóa',
                                    style: TextStyle(
                                      color: isActive ? Colors.greenAccent : Colors.grey,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
