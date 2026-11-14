import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../l10n/app_locale.dart';
import '../services/auth_service.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _agreeTerms = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  int _calculateStrength(String pass) {
    if (pass.isEmpty) return 0;
    int score = 0;
    if (pass.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(pass)) score++;
    if (RegExp(r'[0-9]').hasMatch(pass)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pass)) score++;
    return score;
  }

  Future<void> _handleRegister() async {
    if (!_agreeTerms) {
      setState(() {
        _errorMessage = AppLocale.t(
          'Vui lòng đồng ý với Điều khoản & Cam kết bảo mật y tế.',
          'Please agree to the Terms & Health Privacy Policy.',
        );
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.register(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      final userEmail = _emailController.text.trim();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => VerifyEmailScreen(email: userEmail),
        ),
        (route) => false,
      );
    } else {
      setState(() {
        final err = result['error'];
        final msg = result['message'] ??
            AppLocale.t('Đăng ký tài khoản thất bại', 'Account registration failed');
        _errorMessage = err != null
            ? AppLocale.t('$msg\nChi tiết: $err', '$msg\nDetails: $err')
            : msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strength = _calculateStrength(_passwordController.text);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const PhosphorIcon(
            PhosphorIconsBold.caretLeft,
            color: Color(0xFF334155),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppLocale.t('Đăng Ký Tài Khoản', 'Create Account'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),

                  Text(
                    AppLocale.t(
                      'Tạo hồ sơ bảo vệ sức khỏe cho bạn và gia đình',
                      'Create a health protection profile for you and your family',
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEF4444), width: 1),
                      ),
                      child: Row(
                        children: [
                          const PhosphorIcon(
                            PhosphorIconsDuotone.warningOctagon,
                            color: Color(0xFFDC2626),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Text(
                    AppLocale.t('Họ và tên', 'Full Name'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: AppLocale.t('Nhập họ tên', 'Enter full name'),
                      prefixIcon: const PhosphorIcon(
                        PhosphorIconsDuotone.user,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? AppLocale.t('Vui lòng nhập họ và tên', 'Please enter your full name')
                        : null,
                  ),
                  const SizedBox(height: 14),

                  Text(
                    AppLocale.t('Địa chỉ Email', 'Email Address'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      hintText: 'email@example.com',
                      prefixIcon: PhosphorIcon(
                        PhosphorIconsDuotone.envelope,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return AppLocale.t('Vui lòng nhập email', 'Please enter your email');
                      }
                      if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                        return AppLocale.t('Định dạng email không hợp lệ', 'Invalid email format');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  Text(
                    AppLocale.t(
                      'Mật khẩu (tối thiểu 8 ký tự)',
                      'Password (at least 8 characters)',
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                    onChanged: (val) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: AppLocale.t('Tối thiểu 8 ký tự', 'At least 8 characters'),
                      prefixIcon: const PhosphorIcon(
                        PhosphorIconsDuotone.lock,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                      suffixIcon: IconButton(
                        icon: PhosphorIcon(
                          _obscurePassword
                              ? PhosphorIconsDuotone.eyeSlash
                              : PhosphorIconsDuotone.eye,
                          size: 20,
                          color: const Color(0xFF64748B),
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return AppLocale.t('Vui lòng nhập mật khẩu', 'Please enter a password');
                      }
                      if (v.length < 8) {
                        return AppLocale.t(
                          'Mật khẩu phải chứa ít nhất 8 ký tự',
                          'Password must be at least 8 characters',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Container(
                        height: 4,
                        width: 65,
                        decoration: BoxDecoration(
                          color: strength >= 3
                              ? const Color(0xFF10B981)
                              : (strength >= 2
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFFEF4444)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        strength >= 3
                            ? AppLocale.t('Độ mạnh: Rất mạnh', 'Strength: Strong')
                            : (strength >= 2
                                ? AppLocale.t('Độ mạnh: Trung bình', 'Strength: Medium')
                                : AppLocale.t('Độ mạnh: Yếu', 'Strength: Weak')),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: strength >= 3
                              ? const Color(0xFF10B981)
                              : (strength >= 2
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFFEF4444)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Text(
                    AppLocale.t('Xác nhận mật khẩu', 'Confirm Password'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: AppLocale.t('Nhập lại mật khẩu', 'Re-enter password'),
                      prefixIcon: const PhosphorIcon(
                        PhosphorIconsDuotone.lockKey,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                      suffixIcon: IconButton(
                        icon: PhosphorIcon(
                          _obscureConfirmPassword
                              ? PhosphorIconsDuotone.eyeSlash
                              : PhosphorIconsDuotone.eye,
                          size: 20,
                          color: const Color(0xFF64748B),
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                    validator: (v) {
                      if (v != _passwordController.text) {
                        return AppLocale.t(
                          'Mật khẩu xác nhận không trùng khớp',
                          'Passwords do not match',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _agreeTerms,
                          activeColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) => setState(() => _agreeTerms = val ?? true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocale.t(
                            'Tôi đồng ý với Điều khoản & Cam kết bảo mật y tế',
                            'I agree to the Terms & Health Privacy Policy',
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              AppLocale.t(
                                'Hoàn tất & Cài đặt Hồ sơ',
                                'Complete & Set Up Profile',
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppLocale.t('Đã có tài khoản? ', 'Already have an account? '),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          AppLocale.t('Đăng nhập ngay', 'Sign in now'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
