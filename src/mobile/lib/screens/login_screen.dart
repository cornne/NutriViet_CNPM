import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../l10n/app_locale.dart';
import '../services/auth_service.dart';
import '../services/local_guest_store.dart';
import '../theme/nutriviet_glass.dart';
import '../widgets/nutriviet_glass_modal.dart';
import '../widgets/nutriviet_ui.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'verify_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

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
    final forgotEmailController =
        TextEditingController(text: _emailController.text);
    bool isSubmitting = false;
    String? dialogMessage;
    bool dialogSuccess = false;

    showNutriVietGlassDialog(
      context: context,
      barrierColor: const Color(0x520F172A),
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return NutriVietGlassDialog(
            titleTextStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
            contentTextStyle: const TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              height: 1.45,
            ),
            title: Row(
              children: [
                const PhosphorIcon(
                  PhosphorIconsDuotone.lockKey,
                  color: Color(0xFF14803C),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocale.t('Khôi phục mật khẩu', 'Password Recovery'),
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
                    'Nhập email tài khoản NutriViet của bạn để nhận hướng dẫn đặt lại mật khẩu.',
                    'Enter your NutriViet account email to receive password reset instructions.',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: forgotEmailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: AppLocale.t('Email', 'Email'),
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: dialogSuccess
                          ? const Color(0xFFD1FAE5)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      dialogMessage!,
                      style: TextStyle(
                        fontSize: 13,
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
              NutriVietGlassPillButton(
                label: AppLocale.t('Hủy', 'Cancel'),
                variant: NutriVietGlassButtonVariant.neutral,
                height: 44,
                width: 96,
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              ),
              NutriVietGlassPillButton(
                label: AppLocale.t('Gửi yêu cầu', 'Send Request'),
                isLoading: isSubmitting,
                height: 44,
                width: 148,
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
                        final res =
                            await AuthService.forgotPassword(email: email);
                        setDialogState(() {
                          isSubmitting = false;
                          dialogMessage = res['message'];
                          dialogSuccess = res['success'] == true;
                        });
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUnverifiedEmailDialog(String email) {
    showNutriVietGlassDialog(
      context: context,
      barrierColor: const Color(0x520F172A),
      builder: (ctx) => NutriVietGlassDialog(
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F172A),
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          color: Color(0xFF475569),
          height: 1.45,
        ),
        title: Row(
          children: [
            const PhosphorIcon(
              PhosphorIconsDuotone.envelope,
              color: Color(0xFFEF4444),
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocale.t('Chưa xác thực email', 'Email Not Verified'),
              ),
            ),
          ],
        ),
        content: Text(
          AppLocale.t(
            'Tài khoản ($email) chưa được kích hoạt qua email. Vui lòng xác thực email trước khi đăng nhập.',
            'Account ($email) has not been verified yet. Please verify your email before signing in.',
          ),
        ),
        actions: [
          NutriVietGlassPillButton(
            label: AppLocale.t('Đóng', 'Close'),
            variant: NutriVietGlassButtonVariant.neutral,
            height: 44,
            width: 96,
            onPressed: () => Navigator.pop(ctx),
          ),
          NutriVietGlassPillButton(
            label: AppLocale.t('Kích hoạt ngay', 'Verify Now'),
            height: 44,
            width: 148,
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VerifyEmailScreen(email: email),
                ),
              );
            },
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

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final user = Map<String, dynamic>.from(result['user'] as Map);
      user['token'] = result['token'] ?? '';
      user['is_guest'] = false;
      final uid = user['id'] is int
          ? user['id'] as int
          : int.tryParse('${user['id']}') ?? 0;

      if (uid > 0 && await LocalGuestStore.hasLocalData() && mounted) {
        final shouldSync = await showNutriVietGlassDialog<bool>(
          context: context,
          builder: (ctx) => NutriVietGlassDialog(
            title: Text(
              AppLocale.t(
                'Đồng bộ dữ liệu Chế độ Khách?',
                'Sync Guest Mode Data?',
              ),
            ),
            content: Text(
              AppLocale.t(
                'Phát hiện lịch sử quét và hồ sơ dị ứng đã lưu trên thiết bị ở Chế độ Khách. Bạn có muốn đồng bộ lên tài khoản này không?',
                'Local scans and allergy profiles from Guest Mode were found on this device. Would you like to sync them to your account?',
              ),
            ),
            actions: [
              NutriVietGlassPillButton(
                height: 44,
                variant: NutriVietGlassButtonVariant.neutral,
                label: AppLocale.t('Bỏ qua', 'Skip'),
                onPressed: () => Navigator.pop(ctx, false),
              ),
              NutriVietGlassPillButton(
                height: 44,
                label: AppLocale.t('Đồng bộ ngay', 'Sync Now'),
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        );
        if (shouldSync == true) {
          await LocalGuestStore.syncToCloudAccount(userId: uid);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocale.t(
              'Đăng nhập thành công! Xin chào ${user['full_name']}',
              'Signed in successfully! Welcome ${user['full_name']}',
            ),
          ),
          backgroundColor: const Color(0xFF14803C),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(user: user)),
        (route) => false,
      );
    } else {
      final code = result['code'] ?? '';
      final msg = result['message'] ??
          AppLocale.t('Đăng nhập thất bại', 'Sign in failed');

      if (code == 'EMAIL_NOT_VERIFIED') {
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

  Future<void> _handleGuestLogin() async {
    final guestUser = await AuthService.enterGuestMode();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen(user: guestUser)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NutriVietGlassBackdrop(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: NutriVietGlassScrollArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding:
                            const EdgeInsets.fromLTRB(24.0, 68.0, 24.0, 28.0),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: (constraints.maxHeight - 96)
                                .clamp(0.0, double.infinity),
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Brand identity
                                    const Center(
                                      child: NutriVietEntranceMotion(
                                        child: NutriVietPulseHalo(
                                          glowColor: Color(0xFF14803C),
                                          size: 84,
                                          child: NutriVietGlassIconTile(
                                            icon:
                                                PhosphorIconsDuotone.shieldCheck,
                                            color: Color(0xFF14803C),
                                            size: 84,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 22),

                                    Text(
                                      AppLocale.t(
                                        'Chào mừng trở lại',
                                        'Welcome back',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: -0.6,
                                        height: 1.15,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    Text(
                                      AppLocale.t(
                                        'Bảo vệ sức khỏe & cảnh báo dị ứng cùng NutriViet',
                                        'Allergy safety & smart label scanning with NutriViet',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Color(0xFF475569),
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 28),

                                    // Clean spacious login form card
                                    NutriVietGlassCard(
                                      cornerRadius: 28,
                                      padding: const EdgeInsets.fromLTRB(
                                        22,
                                        24,
                                        22,
                                        22,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          if (_errorMessage != null) ...[
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 12,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEE2E2)
                                                    .withValues(alpha: 0.92),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color:
                                                      const Color(0xFFEF4444),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  const PhosphorIcon(
                                                    PhosphorIconsDuotone
                                                        .warningOctagon,
                                                    color: Color(0xFFDC2626),
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      _errorMessage!,
                                                      style: const TextStyle(
                                                        color:
                                                            Color(0xFFDC2626),
                                                        fontSize: 13.5,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        height: 1.35,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 18),
                                          ],

                                          Text(
                                            AppLocale.t('Email', 'Email'),
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF334155),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _emailController,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            textInputAction:
                                                TextInputAction.next,
                                            style: const TextStyle(
                                              fontSize: 15.5,
                                              color: Color(0xFF0F172A),
                                            ),
                                            decoration: InputDecoration(
                                              hintText: AppLocale.t(
                                                'nhap.email@example.com',
                                                'your.email@example.com',
                                              ),
                                              prefixIcon: const Padding(
                                                padding: EdgeInsets.only(
                                                  left: 14,
                                                  right: 10,
                                                ),
                                                child: PhosphorIcon(
                                                  PhosphorIconsDuotone.envelope,
                                                  size: 21,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                              prefixIconConstraints:
                                                  const BoxConstraints(
                                                minWidth: 44,
                                                minHeight: 44,
                                              ),
                                            ),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.trim().isEmpty) {
                                                return AppLocale.t(
                                                  'Vui lòng nhập địa chỉ email',
                                                  'Please enter your email address',
                                                );
                                              }
                                              if (!RegExp(
                                                r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$',
                                              ).hasMatch(value.trim())) {
                                                return AppLocale.t(
                                                  'Định dạng email không hợp lệ',
                                                  'Invalid email format',
                                                );
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 18),

                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                AppLocale.t(
                                                  'Mật khẩu',
                                                  'Password',
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF334155),
                                                ),
                                              ),
                                              InkWell(
                                                onTap:
                                                    _showForgotPasswordDialog,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 4,
                                                    vertical: 4,
                                                  ),
                                                  child: Text(
                                                    AppLocale.t(
                                                      'Quên mật khẩu?',
                                                      'Forgot password?',
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 13.5,
                                                      color: Color(0xFF14803C),
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _passwordController,
                                            obscureText: _obscurePassword,
                                            textInputAction:
                                                TextInputAction.done,
                                            onFieldSubmitted: (_) =>
                                                _handleLogin(),
                                            style: const TextStyle(
                                              fontSize: 15.5,
                                              color: Color(0xFF0F172A),
                                            ),
                                            decoration: InputDecoration(
                                              hintText: AppLocale.t(
                                                'Nhập mật khẩu',
                                                'Enter password',
                                              ),
                                              prefixIcon: const Padding(
                                                padding: EdgeInsets.only(
                                                  left: 14,
                                                  right: 10,
                                                ),
                                                child: PhosphorIcon(
                                                  PhosphorIconsDuotone.lock,
                                                  size: 21,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                              prefixIconConstraints:
                                                  const BoxConstraints(
                                                minWidth: 44,
                                                minHeight: 44,
                                              ),
                                              suffixIcon: IconButton(
                                                icon: PhosphorIcon(
                                                  _obscurePassword
                                                      ? PhosphorIconsDuotone
                                                          .eyeSlash
                                                      : PhosphorIconsDuotone
                                                          .eye,
                                                  size: 21,
                                                  color:
                                                      const Color(0xFF64748B),
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    _obscurePassword =
                                                        !_obscurePassword;
                                                  });
                                                },
                                              ),
                                            ),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return AppLocale.t(
                                                  'Vui lòng nhập mật khẩu',
                                                  'Please enter your password',
                                                );
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 22),

                                          // Single clear primary CTA
                                          NutriVietGlassActionButton(
                                            label: AppLocale.t(
                                              'Đăng nhập',
                                              'Sign in',
                                            ),
                                            icon: PhosphorIconsBold.arrowRight,
                                            height: 54,
                                            isLoading: _isLoading,
                                            onPressed: _handleLogin,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 22),

                                    // Quiet divider
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Divider(
                                            color: Color(0x3364748B),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                          ),
                                          child: Text(
                                            AppLocale.t('hoặc', 'or'),
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                        const Expanded(
                                          child: Divider(
                                            color: Color(0x3364748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),

                                    // One calm secondary Guest button
                                    SizedBox(
                                      height: 52,
                                      child: OutlinedButton.icon(
                                        onPressed: _handleGuestLogin,
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xB8FFFFFF),
                                          foregroundColor:
                                              const Color(0xFF1E293B),
                                          side: const BorderSide(
                                            color: Color(0xFFC9D5CD),
                                            width: 1.25,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                          ),
                                        ),
                                        icon: const PhosphorIcon(
                                          PhosphorIconsDuotone.userCircle,
                                          color: Color(0xFF14803C),
                                          size: 21,
                                        ),
                                        label: Text(
                                          AppLocale.t(
                                            'Tiếp tục với chế độ Khách',
                                            'Continue as Guest',
                                          ),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Minimal inline sign-up link (no heavy card clutter)
                                    Center(
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const RegisterScreen(),
                                            ),
                                          );
                                        },
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
                                                  'Chưa có tài khoản?',
                                                  'Don\'t have an account?',
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 14.5,
                                                  color: Color(0xFF475569),
                                                ),
                                              ),
                                              Text(
                                                AppLocale.t(
                                                  'Đăng ký ngay',
                                                  'Sign up',
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
                      );
                    },
                  ),
                ),
              ),

              // Top-right language switcher
              Positioned(
                top: 10,
                right: 20,
                child: LiquidGlassBatch.exclude(
                  child: LiquidGlassLens(
                    style: NutriVietGlass.floatingChrome,
                    touch: NutriVietGlass.touchHorizontalCapsule,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () async {
                        await AppLocale.setLanguage(
                          AppLocale.isEn ? 'vi' : 'en',
                        );
                        if (mounted) setState(() {});
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const PhosphorIcon(
                              PhosphorIconsDuotone.translate,
                              size: 17,
                              color: Color(0xFF14803C),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              AppLocale.isEn ? 'English' : 'Tiếng Việt',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
