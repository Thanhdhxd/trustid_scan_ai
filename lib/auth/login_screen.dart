import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/auth/presentation/auth_controller.dart';
import '../core/api_client.dart';
import '../home/widgets/consumer_theme.dart';
import 'widgets/custom_text_field.dart';
import '../dashboard/dashboard_screen.dart';
import '../farm/presentation/home/farmer_home_screen.dart';
import '../supply/presentation/driver/driver_home_screen.dart';
import '../supply/presentation/warehouse/warehouse_home_screen.dart';
import '../supply/presentation/dealer/dealer_home_screen.dart';
import '../kcs/presentation/kcs_dashboard_screen.dart';
import '../home/modern_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ConsumerTheme.backgroundDark,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            const Positioned.fill(child: _AuthBackground()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 40,
                      ),
                      child: Column(
                        children: [
                          _buildTopBar(context),
                          const SizedBox(height: 18),
                          _buildBrandHeader(),
                          const SizedBox(height: 24),
                          _buildAuthCard(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        if (Navigator.canPop(context))
          _IconCircleButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context))
        else
          const SizedBox(width: 42),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/khien.png',
                height: 15,
                width: 15,
              ),
              const SizedBox(width: 6),
              const Text(
                'TrustID',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBrandHeader() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final isLogin = _tabController.index == 0;
        return Column(
          children: [
            SizedBox(
              width: 220,
              height: 112,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: ConsumerTheme.actionBlue.withOpacity(0.18),
                      blurRadius: 34,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo_w.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.security, size: 80, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isLogin ? 'Đăng nhập tài khoản' : 'Đăng ký tài khoản',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.45,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isLogin
                  ? 'Truy xuất nguồn gốc, xác thực sản phẩm và kết nối chuỗi cung ứng.'
                  : 'Tạo tài khoản để quản lý, truy xuất và kết nối dữ liệu nông sản.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAuthCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF16325B).withOpacity(0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSegmentedControl(),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _tabController.index == 0
                    ? const LoginForm(key: ValueKey('login-form'))
                    : const RegisterForm(key: ValueKey('register-form')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2E3B52).withOpacity(0.9)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: ConsumerTheme.actionBlue,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: ConsumerTheme.actionBlue.withOpacity(0.28),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        tabs: const [
          Tab(text: 'Đăng nhập', height: 42),
          Tab(text: 'Đăng ký', height: 42),
        ],
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ConsumerTheme.backgroundDark,
            Color(0xFF0F2B46),
            ConsumerTheme.backgroundDark,
          ],
          stops: [0, 0.48, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -110,
            right: -90,
            child: _GlowOrb(
              size: 260,
              color: ConsumerTheme.actionBlue.withOpacity(0.28),
            ),
          ),
          Positioned(
            bottom: -130,
            left: -110,
            child: _GlowOrb(
              size: 300,
              color: const Color(0xFF0F2B46).withOpacity(0.7),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _ContourPainter())),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
      ),
    );
  }
}

class _ContourPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withOpacity(0.035);

    for (var i = 0; i < 9; i++) {
      final path = Path();
      final baseY = size.height * (0.18 + i * 0.09);
      path.moveTo(-20, baseY);
      for (double x = -20; x <= size.width + 20; x += 18) {
        final y =
            baseY +
            math.sin((x / 58) + i * 0.72) * 14 +
            math.cos((x / 104) + i) * 10;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }

    final leafPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = ConsumerTheme.actionBlue.withOpacity(0.06);
    final center = Offset(size.width * 0.82, size.height * 0.72);
    for (var i = 0; i < 4; i++) {
      final rect = Rect.fromCenter(
        center: center.translate(-i * 18, i * 20),
        width: 54 + i * 16,
        height: 94 + i * 22,
      );
      canvas.drawArc(rect, -math.pi * 0.86, math.pi * 1.32, false, leafPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------
// LOGIN FORM
// ---------------------------------------------------------
class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});
  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedUsername();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('saved_username');
    if (savedUser != null && savedUser.isNotEmpty) {
      setState(() {
        _usernameController.text = savedUser;
        _rememberMe = true;
      });
    }
  }

  void _handleLogin() async {
    if (_isLoading) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tài khoản và mật khẩu!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authControllerProvider.notifier).login(username, password);

      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('saved_username', username);
      } else {
        await prefs.remove('saved_username');
      }

      final authState = ref.read(authControllerProvider);
      final user = authState.value;

      if (user != null && mounted) {
        final role = user.role.toUpperCase();
        if (['FARMER', 'TEAM_LEADER'].contains(role)) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const FarmerHomeScreen()),
            (route) => false,
          );
          return;
        } else if (['DRIVER', 'TRANSPORTER'].contains(role)) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
            (route) => false,
          );
          return;
        } else if (role == 'WAREHOUSE_MANAGER') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const WarehouseHomeScreen()),
            (route) => false,
          );
          return;
        } else if (role == 'DEALER') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const DealerHomeScreen()),
            (route) => false,
          );
          return;
        } else if (role == 'KCS_STAFF') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const KcsDashboardScreen()),
            (route) => false,
          );
          return;
        } else if (['MANAGER', 'ADMIN', 'TENANT_ADMIN', 'TENANT'].contains(role)) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => DashboardScreen(userProfile: user.toJson())),
            (route) => false,
          );
          return;
        }
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ModernHomeScreen()),
          (route) => false,
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        String msg = 'Đăng nhập thất bại. Vui lòng kiểm tra lại.';
        if (e.response?.data != null && e.response?.data is Map && e.response!.data['message'] != null) {
          msg = e.response!.data['message'].toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi hệ thống: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tài khoản',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          CustomTextField(
            hintText: 'Tài khoản',
            icon: Icons.email_outlined,
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocusNode),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mật khẩu',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tính năng đang phát triển'))),
                child: const Text(
                  'Quên mật khẩu?',
                  style: TextStyle(
                    color: ConsumerTheme.actionBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CustomTextField(
            hintText: '........',
            icon: Icons.lock_outline,
            controller: _passwordController,
            isPassword: true,
            focusNode: _passwordFocusNode,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleLogin(),
          ),
          const SizedBox(height: 16),

          // Remember Me Checkbox
          Row(
            children: [
              Theme(
                data: ThemeData(unselectedWidgetColor: Colors.white54),
                child: Checkbox(
                  value: _rememberMe,
                  activeColor: ConsumerTheme.actionBlue,
                  checkColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF2E3B52)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  onChanged: (val) {
                    setState(() => _rememberMe = val ?? false);
                  },
                ),
              ),
              const Text(
                'Nhớ tài khoản',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),

          const SizedBox(height: 22),

          SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: ConsumerTheme.actionBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: ConsumerTheme.actionBlue.withOpacity(0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.4,
                      ),
                    )
                  : const Text(
                      'Đăng nhập',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey,
              ),
              child: const Text(
                'Tiếp tục không đăng nhập',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Row(
            children: [
              Expanded(child: Divider(color: Color(0xFF2E3B52))),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'Hoặc tiếp tục với',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              Expanded(child: Divider(color: Color(0xFF2E3B52))),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSocialButton('assets/images/google_logo.svg', _showDevelopingMessage),
              _buildSocialButton('assets/images/facebook_logo.svg', _showDevelopingMessage),
              _buildSocialButton('assets/images/apple_logo.svg', _showDevelopingMessage),
            ],
          ),
          const SizedBox(height: 26),

          const Center(
            child: Text(
              'Bằng cách tiếp tục, bạn đồng ý với Điều khoản và Chính sách bảo mật của TrustID.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDevelopingMessage() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tính năng đang phát triển')));
  }

  Widget _buildSocialButton(String assetPath, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        height: 50,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2E3B52)),
        ),
        child: SvgPicture.asset(assetPath, width: 24, height: 24, fit: BoxFit.contain, placeholderBuilder: (_) => const Icon(Icons.image, color: Colors.white)),
      ),
    );
  }
}

// ---------------------------------------------------------
// REGISTER FORM
// ---------------------------------------------------------
class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key});
  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.grey,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    final phone = _phoneController.text.trim();

    if (email.isEmpty || name.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đủ thông tin')),
      );
      return;
    }

    if (password != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mật khẩu không khớp')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await companyApi.post('/auth/register', data: {
        'email': email,
        'fullName': name,
        'password': password,
        'phoneNumber': phone.isEmpty ? null : phone,
      });

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF16325B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Text('Đăng ký thành công', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mark_email_read, size: 60, color: ConsumerTheme.actionBlue),
                const SizedBox(height: 16),
                Text('Vui lòng kiểm tra email $email để hoàn tất.', style: const TextStyle(color: Colors.grey, height: 1.5), textAlign: TextAlign.center),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context), // Let them switch to login tab manually
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ConsumerTheme.actionBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Đóng', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        String msg = 'Đăng ký thất bại.';
        if (e.response?.data != null && e.response?.data is Map && e.response!.data['message'] != null) {
          msg = e.response!.data['message'].toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDevelopingMessage() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tính năng đang phát triển')));
  }

  Widget _buildSocialLink(String assetPath, VoidCallback onTap) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        height: 50,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2E3B52)),
        ),
        child: SvgPicture.asset(assetPath, width: 24, height: 24, fit: BoxFit.contain, placeholderBuilder: (_) => const Icon(Icons.image, color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Họ và tên'),
          const SizedBox(height: 8),
          CustomTextField(
            hintText: 'Nguyễn Văn A',
            icon: Icons.person_outline,
            controller: _nameController,
          ),
          const SizedBox(height: 16),
          _label('Số điện thoại (không bắt buộc)'),
          const SizedBox(height: 8),
          CustomTextField(
            hintText: '0912345678',
            icon: Icons.phone_android,
            controller: _phoneController,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _label('Email'),
          const SizedBox(height: 8),
          CustomTextField(
            hintText: 'example@email.com',
            icon: Icons.email_outlined,
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _label('Mật khẩu'),
          const SizedBox(height: 8),
          CustomTextField(
            hintText: '........',
            icon: Icons.lock_outline,
            controller: _passwordController,
            isPassword: true,
          ),
          const SizedBox(height: 16),
          _label('Nhập lại mật khẩu'),
          const SizedBox(height: 8),
          CustomTextField(
            hintText: '........',
            icon: Icons.refresh,
            controller: _confirmPasswordController,
            isPassword: true,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: ConsumerTheme.actionBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: ConsumerTheme.actionBlue.withOpacity(0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.4,
                      ),
                    )
                  : const Text(
                      'Tạo tài khoản',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
            ),
          ),
          const SizedBox(height: 28),
          Column(
            children: [
              const Row(
                children: [
                  Expanded(child: Divider(color: Color(0xFF2E3B52))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'Hoặc tiếp tục với',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  Expanded(child: Divider(color: Color(0xFF2E3B52))),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSocialLink('assets/images/google_logo.svg', _showDevelopingMessage),
                  _buildSocialLink('assets/images/facebook_logo.svg', _showDevelopingMessage),
                  _buildSocialLink('assets/images/apple_logo.svg', _showDevelopingMessage),
                ],
              ),
              const SizedBox(height: 26),
              const Center(
                child: Text(
                  'Bằng cách đăng ký, bạn đồng ý với Điều khoản sử dụng và Chính sách bảo mật.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
