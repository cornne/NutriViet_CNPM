import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../l10n/app_locale.dart';
import '../services/auth_service.dart';
import '../widgets/nutriviet_ui.dart';
import 'register_screen.dart';
import 'verify_email_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showForgotPasswordDialog() {
    final forgotEmailController = TextEditingController(text: _emailController.text);
    bool isSubmitting = false;
    String? dialogMessage;
    bool dialogSuccess = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const PhosphorIcon(
                  PhosphorIconsDuotone.lockKey,
                  color: Color(0xFF14803C),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocale.t('Khôi Phục Mật Khẩu', 'Password Recovery'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppLocale.t(
                    'Nhập địa chỉ email tài khoản NutriViet của bạn. Hệ thống sẽ gửi hướng dẫn khôi phục mật khẩu vào hộp thư.',
                    'Enter your NutriViet account email address. We will send password recovery instructions to your inbox.',
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: forgotEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: AppLocale.t('Địa chỉ Email', 'Email Address'),
                    hintText: 'email@example.com',
                    prefixIcon: const PhosphorIcon(
                      PhosphorIconsDuotone.envelope,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                if (dialogMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: dialogSuccess
                          ? const Color(0xFFD1FAE5)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      dialogMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: dialogSuccess
                            ? const Color(0xFF065F46)
                            : const Color(0xFF991B1B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                child: Text(
                  AppLocale.t('Hủy', 'Cancel'),
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final email = forgotEmailController.text.trim();
                        if (email.isEmpty) {
                          setDialogState(() {
                            dialogMessage = AppLocale.t(
                              'Vui lòng nhập địa chỉ email',
                              'Please enter your email address',
                            );
                            dialogSuccess = false;
                          });
                          return;
                        }
                        setDialogState(() => isSubmitting = true);
                        final res = await AuthService.forgotPassword(email: email);
                        setDialogState(() {
                          isSubmitting = false;
                          dialogMessage = res['message'];
                          dialogSuccess = res['success'] == true;
                        });
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(AppLocale.t('Gửi Yêu Cầu', 'Send Request')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUnverifiedEmailDialog(String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const PhosphorIcon(
              PhosphorIconsDuotone.envelope,
              color: Color(0xFFEF4444),
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              AppLocale.t('Chưa Xác Thực Email', 'Email Not Verified'),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          AppLocale.t(
            'Tài khoản ($email) chưa được kích hoạt qua email.\n\nTheo chính sách an toàn y tế NutriViet, bạn phải xác thực email trước khi đăng nhập và sử dụng ứng dụng.',
            'Account ($email) has not been activated via email.\n\nUnder NutriViet health safety policy, you must verify your email before signing in.',
          ),
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppLocale.t('Đóng', 'Close'),
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VerifyEmailScreen(email: email),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(AppLocale.t('Kích Hoạt Ngay', 'Verify Now')),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      final user = result['user'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocale.t(
              'Đăng nhập thành công! Xin chào ${user['full_name']}',
              'Signed in successfully! Welcome ${user['full_name']}',
            ),
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(user: user),
        ),
      );
    } else {
      final code = result['code'] ?? '';
      final msg = result['message'] ??
          AppLocale.t('Đăng nhập thất bại', 'Sign in failed');

      if (code == 'EMAIL_NOT_VERIFIED' ||
          msg.contains('kích hoạt') ||
          msg.contains('xác thực')) {
        _showUnverifiedEmailDialog(_emailController.text.trim());
      } else {
        setState(() {
          _errorMessage = result['error'] != null
              ? AppLocale.t(
                  '$msg\nChi tiết: ${result['error']}',
                  '$msg\nDetails: ${result['error']}',
                )
              : msg;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        await AppLocale.setLanguage(AppLocale.isEn ? 'vi' : 'en');
                        if (mounted) setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const PhosphorIcon(
                              PhosphorIconsDuotone.translate,
                              size: 16,
                              color: Color(0xFF14803C),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              AppLocale.isEn ? 'English' : 'Tiếng Việt',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  const Center(
                    child: NutriVietEntranceMotion(
                      child: NutriVietPulseHalo(
                        glowColor: Color(0xFF14803C),
                        size: 74,
                        child: NutriVietGlassIconTile(
                          icon: PhosphorIconsDuotone.shieldCheck,
                          color: Color(0xFF14803C),
                          size: 74,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    AppLocale.t('Chào mừng trở lại', 'Welcome back'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),

                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      children: [
                        TextSpan(
                          text: AppLocale.t(
                            'Quét nhãn thực phẩm an toàn cùng ',
                            'Scan food labels safely with ',
                          ),
                        ),
                        const TextSpan(
                          text: 'NutriViet',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

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
                    AppLocale.t('Email hoặc Số điện thoại', 'Email or Phone number'),
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
                    decoration: InputDecoration(
                      hintText: AppLocale.t(
                        'nhap.email@example.com',
                        'your.email@example.com',
                      ),
                      prefixIcon: const PhosphorIcon(
                        PhosphorIconsDuotone.envelope,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return AppLocale.t(
                          'Vui lòng nhập địa chỉ email',
                          'Please enter your email address',
                        );
                      }
                      if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value.trim())) {
                        return AppLocale.t(
                          'Định dạng email không hợp lệ',
                          'Invalid email format',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  Text(
                    AppLocale.t('Mật khẩu', 'Password'),
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
                    decoration: InputDecoration(
                      hintText: AppLocale.t('Nhập mật khẩu', 'Enter password'),
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
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocale.t(
                          'Vui lòng nhập mật khẩu',
                          'Please enter your password',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _rememberMe,
                              activeColor: const Color(0xFF10B981),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _rememberMe = val ?? true;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppLocale.t('Ghi nhớ đăng nhập', 'Remember me'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: _showForgotPasswordDialog,
                        child: Text(
                          AppLocale.t('Quên mật khẩu?', 'Forgot password?'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
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
                      onPressed: _isLoading ? null : _handleLogin,
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
                              AppLocale.t('Đăng Nhập An Toàn', 'Sign In Safely'),
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
                        AppLocale.t('Chưa có tài khoản? ', 'Don\'t have an account? '),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: Text(
                          AppLocale.t('Đăng ký ngay', 'Sign up now'),
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
