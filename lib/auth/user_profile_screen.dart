import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import '../core/api_client.dart';
import '../core/widgets/user_avatar.dart';
import '../home/widgets/consumer_theme.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';
import 'login_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../farm/presentation/home/farmer_home_screen.dart';
import '../supply/presentation/driver/driver_home_screen.dart';
import '../supply/presentation/warehouse/warehouse_home_screen.dart';
import '../supply/presentation/dealer/dealer_home_screen.dart';
import '../kcs/presentation/kcs_dashboard_screen.dart';

const Color kTextLight = Color(0xFFE8EDF3);
const Color kTextGray = Color(0xFF94A3B8);
const Color kSecondaryColor = Color(0xFF94A3B8);

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _userProfile;
  bool _isLoggedIn = false;
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token != null && token.isNotEmpty) {
      if (isJwtExpired(token)) {
        await prefs.remove('auth_token');
        if (mounted) {
          setState(() {
            _isLoggedIn = false;
            _userProfile = null;
            _isLoading = false;
          });
        }
        return;
      }
      setState(() {
        _isLoggedIn = true;
      });
      await _fetchProfile();
      ref.read(authControllerProvider.notifier).refreshProfile();
    } else {
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty || isJwtExpired(token)) {
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _userProfile = null;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final response = await companyApi.get('/auth/profile');
      if (mounted) {
        setState(() {
          _isLoggedIn = true;
          _userProfile = response.data['data'] ?? response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _userProfile = null;
          _isLoading = false;
        });
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('auth_token');
        } catch (_) {}
      }
    }
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) {
      setState(() {
        _isLoggedIn = false;
        _userProfile = null;
      });
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())).then((_) {
        if (mounted) _checkLoginStatus();
      });
    }
  }

  String _getFriendlyRole(String role) {
    final map = {
      'TENANT_ADMIN': 'Quản trị viên HTX',
      'TENANT': 'Chủ Doanh nghiệp',
      'MANAGER': 'Cán bộ Quản lý',
      'FARMER': 'Nông dân',
      'TEAM_LEADER': 'Đội trưởng',
      'DRIVER': 'Tài xế vận chuyển',
      'TRANSPORTER': 'Đơn vị vận chuyển',
      'WAREHOUSE_MANAGER': 'Thủ kho',
      'KCS_STAFF': 'Nhân viên KCS',
      'DEALER': 'Đại lý',
    };
    return map[role.trim().toUpperCase()] ?? role;
  }

  void _navigateToDashboard(BuildContext context, String role) {
    final r = role.trim().toUpperCase();
    if (['FARMER', 'TEAM_LEADER'].contains(r)) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const FarmerHomeScreen()),
        (route) => false,
      );
    } else if (['DRIVER', 'TRANSPORTER'].contains(r)) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
        (route) => false,
      );
    } else if (r == 'WAREHOUSE_MANAGER') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WarehouseHomeScreen()),
        (route) => false,
      );
    } else if (r == 'DEALER') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DealerHomeScreen()),
        (route) => false,
      );
    } else if (r == 'KCS_STAFF') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const KcsDashboardScreen()),
        (route) => false,
      );
    } else if (['MANAGER', 'ADMIN', 'TENANT_ADMIN', 'TENANT'].contains(r)) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => DashboardScreen(userProfile: _userProfile)),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(userProfile: _userProfile),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _showImageSourceDialog(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: ConsumerTheme.backgroundDark,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.white),
            title: const Text('Chụp ảnh', style: TextStyle(color: kTextLight)),
            onTap: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.white),
            title: const Text('Chọn từ thư viện', style: TextStyle(color: kTextLight)),
            onTap: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tính năng upload chưa mở trên bản Web Proxy')));
      }
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tính năng đổi mật khẩu đang phát triển')));
  }

  void _showDeleteAccountDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yêu cầu xóa tài khoản đã được ghi nhận')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ConsumerTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Hồ sơ người dùng', style: TextStyle(color: kTextLight)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: kSecondaryColor),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: ConsumerTheme.actionBlue))
        : (!_isLoggedIn || _userProfile == null)
            ? _buildGuestUI()
            : RefreshIndicator(
                onRefresh: _fetchProfile,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      // Avatar Section
                      SizedBox(
                        height: 104,
                        width: 104,
                        child: Stack(
                          children: [
                            UserAvatar(
                              avatarUrl: _userProfile?['avatar']?.toString(),
                              fullName: _userProfile?['fullName']?.toString(),
                              size: 100,
                              borderColor: ConsumerTheme.actionBlue,
                              borderWidth: 2.5,
                            ),
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: InkWell(
                                onTap: () => _showImageSourceDialog(context),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: ConsumerTheme.actionBlue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.black,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _userProfile?['fullName'] ?? 'Người dùng',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: kTextLight,
                        ),
                      ),
                      Text(
                        '@${_userProfile?['username'] ?? 'unknown'}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ConsumerTheme.actionBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: ConsumerTheme.actionBlue.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _getFriendlyRole(_userProfile?['role'] ?? 'END_USER'),
                          style: const TextStyle(
                            color: ConsumerTheme.actionBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Enterprise Name (if available)
                      if (_userProfile?['tenantName'] != null && _userProfile!['tenantName'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _userProfile!['tenantName'],
                            style: const TextStyle(
                              color: kTextGray,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),

                      // Dashboard Link
                      if ((_userProfile?['role'] ?? 'END_USER') != 'END_USER')
                        InkWell(
                          onTap: () => _navigateToDashboard(context, _userProfile?['role'] ?? ''),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.dashboard,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Truy cập trang làm việc',
                                  style: TextStyle(
                                    color: kTextLight,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: kTextGray,
                                  size: 12,
                                ),
                              ],
                            ),
                          ),
                        ),

                      if ((_userProfile?['role'] ?? 'END_USER') != 'END_USER') const SizedBox(height: 32),
                      if ((_userProfile?['role'] ?? 'END_USER') == 'END_USER') const SizedBox(height: 16),

                      // Info Cards
                      _buildSectionTitle('Thông tin cá nhân'),
                      _buildInfoCard(
                        Icons.email,
                        'Email',
                        _userProfile?['email'] ?? 'Chưa cập nhật',
                      ),
                      _buildInfoCard(
                        Icons.phone,
                        'Số điện thoại',
                        _userProfile?['phoneNumber'] ?? 'Chưa cập nhật',
                      ),
                      _buildInfoCard(
                        Icons.verified_user,
                        'Trạng thái',
                        _userProfile?['status'] ?? 'Active',
                      ),

                      const SizedBox(height: 16),

                      // Change Password Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showChangePasswordDialog(context),
                          icon: const Icon(Icons.lock_reset),
                          label: const Text('Đổi mật khẩu'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kTextLight,
                            side: BorderSide(color: kTextLight.withOpacity(0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout),
                          label: const Text('Đăng xuất'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.1),
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Delete Account Button
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () => _showDeleteAccountDialog(context),
                          icon: const Icon(Icons.delete_forever, size: 20),
                          label: const Text('Yêu cầu xóa tài khoản'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildGuestUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ConsumerTheme.actionBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline,
                size: 80,
                color: ConsumerTheme.actionBlue,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Bạn chưa đăng nhập',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: kTextLight,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Vui lòng đăng nhập để sử dụng các tính năng của ứng dụng',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 16),

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _redirectTimer?.cancel();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())).then((_) {
                  if (mounted) _checkLoginStatus();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ConsumerTheme.actionBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Đăng nhập ngay',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 4),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: kTextGray,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16325B), // ConsumerTheme.surface
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E3B52)), // ConsumerTheme.border
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[400]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: kTextLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
