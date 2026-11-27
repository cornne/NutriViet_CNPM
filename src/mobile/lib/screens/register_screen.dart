import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../l10n/app_locale.dart';
import '../services/auth_service.dart';
import '../theme/nutriviet_glass.dart';
import '../theme/nutriviet_route.dart';
import '../widgets/nutriviet_notice.dart';
import '../widgets/nutriviet_ui.dart';
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
      final requiresVerification = result['requires_verification'] != false;
      if (!requiresVerification) {
        showNutriVietNotice(
          context,
          AppLocale.t(
            'Tạo tài khoản thành công! Bạn có thể đăng nhập ngay.',
            'Account created! You can sign in now.',
          ),
          tone: NutriVietNoticeTone.success,
        );
        Navigator.pop(context);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          NutriVietPageRoute(
            builder: (context) => VerifyEmailScreen(email: userEmail),
          ),
          (route) => false,
        );
      }
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
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NutriVietGlassBackdrop(
        child: Stack(
          children: [
            Positioned.fill(
              child: NutriVietGlassScrollArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(22.0, topInset + 78.0, 22.0, 32.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              AppLocale.t(
                                'Tạo hồ sơ bảo vệ sức khỏe cho bạn và gia đình',
                                'Create a health protection profile for you and your family',
                              ),
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF475569),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),

                            NutriVietGlassCard(
                              cornerRadius: 26,
                              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_errorMessage != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEE2E2).withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFEF4444),
                                          width: 1,
                                        ),
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
                                    const SizedBox(height: 14),
                                  ],

                                  Text(
                                    AppLocale.t('Họ và tên', 'Full Name'),
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _nameController,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Color(0xFF0F172A),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: AppLocale.t('Nhập họ tên', 'Enter full name'),
                                      prefixIcon: const PhosphorIcon(
                                        PhosphorIconsDuotone.user,
                                        size: 20,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    validator: (v) => (v == null || v.trim().isEmpty)
                                        ? AppLocale.t(
                                            'Vui lòng nhập họ và tên',
                                            'Please enter your full name',
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 16),

                                  Text(
                                    AppLocale.t('Địa chỉ Email', 'Email Address'),
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Color(0xFF0F172A),
                                    ),
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
                                        return AppLocale.t(
                                          'Vui lòng nhập email',
                                          'Please enter your email',
                                        );
                                      }
                                      if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$')
                                          .hasMatch(v.trim())) {
                                        return AppLocale.t(
                                          'Định dạng email không hợp lệ',
                                          'Invalid email format',
                                        );
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  Text(
                                    AppLocale.t(
                                      'Mật khẩu (tối thiểu 8 ký tự)',
                                      'Password (at least 8 characters)',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Color(0xFF0F172A),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: AppLocale.t(
                                        'Tối thiểu 8 ký tự',
                                        'At least 8 characters',
                                      ),
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
                                        onPressed: () => setState(
                                          () => _obscurePassword = !_obscurePassword,
                                        ),
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return AppLocale.t(
                                          'Vui lòng nhập mật khẩu',
                                          'Please enter a password',
                                        );
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
                                  ValueListenableBuilder<TextEditingValue>(
                                    valueListenable: _passwordController,
                                    builder: (context, value, _) {
                                      final pass = value.text;
                                      if (pass.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      final strength = _calculateStrength(pass);
                                      final barColor = strength >= 3
                                          ? const Color(0xFF14803C)
                                          : (strength >= 2
                                              ? const Color(0xFFD97706)
                                              : const Color(0xFFDC2626));
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(3),
                                                    child: LinearProgressIndicator(
                                                      value: (strength / 4)
                                                          .clamp(0.18, 1.0),
                                                      minHeight: 5,
                                                      backgroundColor:
                                                          const Color(0xFFE5ECE8),
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                              Color>(barColor),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  strength >= 3
                                                      ? AppLocale.t(
                                                          'Rất mạnh',
                                                          'Strong',
                                                        )
                                                      : (strength >= 2
                                                          ? AppLocale.t(
                                                              'Trung bình',
                                                              'Medium',
                                                            )
                                                          : AppLocale.t(
                                                              'Yếu',
                                                              'Weak',
                                                            )),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: barColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                _pwdHintChip(
                                                  AppLocale.t(
                                                    '8+ ký tự',
                                                    '8+ chars',
                                                  ),
                                                  pass.length >= 8,
                                                ),
                                                _pwdHintChip(
                                                  AppLocale.t(
                                                    'Chữ hoa',
                                                    'Uppercase',
                                                  ),
                                                  RegExp(r'[A-Z]').hasMatch(pass),
                                                ),
                                                _pwdHintChip(
                                                  AppLocale.t('Số', 'Number'),
                                                  RegExp(r'[0-9]').hasMatch(pass),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  Text(
                                    AppLocale.t('Xác nhận mật khẩu', 'Confirm Password'),
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: _obscureConfirmPassword,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Color(0xFF0F172A),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: AppLocale.t(
                                        'Nhập lại mật khẩu',
                                        'Re-enter password',
                                      ),
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
                                        onPressed: () => setState(
                                          () => _obscureConfirmPassword =
                                              !_obscureConfirmPassword,
                                        ),
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

                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => setState(
                                      () => _agreeTerms = !_agreeTerms,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: Checkbox(
                                              value: _agreeTerms,
                                              activeColor:
                                                  const Color(0xFF14803C),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              onChanged: (val) => setState(
                                                () => _agreeTerms = val ?? true,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              AppLocale.t(
                                                'Tôi đồng ý với Điều khoản & Cam kết bảo mật y tế',
                                                'I agree to the Terms & Health Privacy Policy',
                                              ),
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                color: Color(0xFF334155),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            NutriVietGlassActionButton(
                              label: AppLocale.t(
                                'Tạo tài khoản',
                                'Create account',
                              ),
                              icon: PhosphorIconsBold.userPlus,
                              height: 54,
                              isLoading: _isLoading,
                              onPressed: _handleRegister,
                            ),
                            const SizedBox(height: 18),

                            Center(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => Navigator.pop(context),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 4,
                                    children: [
                                      Text(
                                        AppLocale.t(
                                          'Đã có tài khoản?',
                                          'Already have an account?',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                      Text(
                                        AppLocale.t(
                                          'Đăng nhập',
                                          'Sign in',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          color: Color(0xFF14803C),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: NutriVietScrollFadeOverlay.top(
                height: topInset + 84,
                color: const Color(0xE8EEF6F2),
              ),
            ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: NutriVietGlassAppBar(
                    leading: NutriVietGlassCircleButton(
                      icon: PhosphorIconsBold.caretLeft,
                      iconColor: const Color(0xFF0F172A),
                      onTap: () => Navigator.pop(context),
                    ),
                    title: Text(
                      AppLocale.t('Đăng Ký Tài Khoản', 'Create Account'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pwdHintChip(String label, bool met) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: met ? const Color(0xFFE6F6EC) : const Color(0xFFF1F5F3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(
            met ? PhosphorIconsBold.check : PhosphorIconsRegular.circle,
            size: 11,
            color: met ? NutriVietGlass.brandGreen : const Color(0xFF64748B),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: met ? NutriVietGlass.brandGreen : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
