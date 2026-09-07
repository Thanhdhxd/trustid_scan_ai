import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:trustid_scan_ai/core/api/dio_client.dart';
import 'package:trustid_scan_ai/home/data/home_stats_repository.dart';

const Color kPrimaryColor = Color(0xFF00875A);
const Color kBackgroundDark = Color(0xFF0F2B46);
const Color kSurfaceDark = Color(0xFF16325B);
const Color kTextLight = Color(0xFFE8EDF3);
const Color kTextGray = Color(0xFF94A3B8);

class QuickAddUserDialog extends ConsumerStatefulWidget {
  final String roleName;

  const QuickAddUserDialog({super.key, required this.roleName});

  @override
  ConsumerState<QuickAddUserDialog> createState() => _QuickAddUserDialogState();
}

class _QuickAddUserDialogState extends ConsumerState<QuickAddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final payload = {
        'fullName': _fullNameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'password': _passwordCtrl.text.trim().isEmpty ? '123456' : _passwordCtrl.text.trim(),
        'roleName': widget.roleName,
        'isActive': true,
      };

      final res = await dio.post('/users', data: payload);
      final createdUser = res.data;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo tài khoản thành công!')));
        Navigator.pop(context, createdUser);
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data?['message'] ?? e.message;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $msg')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.roleName == 'TEAM_LEADER' ? 'Thêm Nhanh Đội Trưởng' : 'Thêm Nhanh Nhân Viên KCS';

    return Dialog(
      backgroundColor: kBackgroundDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: kTextLight, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _buildField(
                controller: _fullNameCtrl,
                label: '* Tên đầy đủ',
                hintText: 'Nhập họ và tên',
                required: true,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _usernameCtrl,
                label: '* Số điện thoại / Tên đăng nhập',
                hintText: 'Nhập số điện thoại',
                required: true,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _passwordCtrl,
                label: 'Mật khẩu',
                hintText: 'Mặc định: 123456',
                obscureText: true,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy', style: TextStyle(color: kTextGray)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Tạo mới', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    bool required = false,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              if (required) const TextSpan(text: '* ', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              TextSpan(text: label.replaceAll('* ', ''), style: const TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: kTextLight, fontSize: 14),
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: (val) {
            if (required && (val == null || val.trim().isEmpty)) {
              return 'Vui lòng nhập trường này';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kPrimaryColor),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            filled: true,
            fillColor: kSurfaceDark,
          ),
        ),
      ],
    );
  }
}
