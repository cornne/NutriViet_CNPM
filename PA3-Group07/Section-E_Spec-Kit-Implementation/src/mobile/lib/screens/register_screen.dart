import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  // Requirement: Không điền sẵn nội dung
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

  // Password strength calculator
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
        _errorMessage = 'Vui lòng đồng ý với Điều khoản & Cam kết bảo mật y tế.';
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
        final msg = result['message'] ?? 'Đăng ký tài khoản thất bại';
        _errorMessage = err != null ? '$msg\nChi tiết: $err' : msg;
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF334155), size: 20),
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
                  // Title matching prototype
                  const Text(
                    'Đăng Ký Tài Khoản',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Subtitle
                  const Text(
                    'Tạo hồ sơ bảo vệ sức khỏe cho bạn và gia đình',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Error Banner
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
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
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

                  // Full Name
                  const Text(
                    'Họ và tên',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      hintText: 'Nhập họ tên',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF94A3B8)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập họ và tên' : null,
                  ),
                  const SizedBox(height: 14),

                  // Email
                  const Text(
                    'Địa chỉ Email',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      hintText: 'email@example.com',
                      prefixIcon: Icon(Icons.email_outlined, size: 20, color: Color(0xFF94A3B8)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
                      if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                        return 'Định dạng email không hợp lệ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Password
                  const Text(
                    'Mật khẩu (tối thiểu 8 ký tự)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                    onChanged: (val) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Tối thiểu 8 ký tự',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: Color(0xFF94A3B8)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                          color: const Color(0xFF94A3B8),
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                      if (v.length < 8) return 'Mật khẩu phải chứa ít nhất 8 ký tự';
                      return null;
                    },
                  ),
                  const SizedBox(height: 6),

                  // Password strength bar matching prototype
                  Row(
                    children: [
                      Container(
                        height: 4,
                        width: 65,
                        decoration: BoxDecoration(
                          color: strength >= 3
                              ? const Color(0xFF10B981)
                              : (strength >= 2 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        strength >= 3
                            ? 'Độ mạnh: Rất mạnh'
                            : (strength >= 2 ? 'Độ mạnh: Trung bình' : 'Độ mạnh: Yếu'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: strength >= 3
                              ? const Color(0xFF10B981)
                              : (strength >= 2 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Confirm Password
                  const Text(
                    'Xác nhận mật khẩu',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Nhập lại mật khẩu',
                      prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20, color: Color(0xFF94A3B8)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                          color: const Color(0xFF94A3B8),
                        ),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                    validator: (v) {
                      if (v != _passwordController.text) return 'Mật khẩu xác nhận không trùng khớp';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Terms & Conditions Checkbox
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
                      const Expanded(
                        child: Text(
                          'Tôi đồng ý với Điều khoản & Cam kết bảo mật y tế',
                          style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Submit Button "Hoàn tất & Cài đặt Hồ sơ"
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
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                            )
                          : const Text(
                              'Hoàn tất & Cài đặt Hồ sơ',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Switch to Login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Đã có tài khoản? ',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          'Đăng nhập ngay',
                          style: TextStyle(
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
