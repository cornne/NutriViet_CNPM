import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../l10n/app_locale.dart';
import '../services/auth_service.dart';
import '../theme/nutriviet_glass.dart';
import '../widgets/nutriviet_ui.dart';
import 'login_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isResending = false;
  String? _resendMessage;
  bool _resendSuccess = false;

  Future<void> _handleResend() async {
    setState(() {
      _isResending = true;
      _resendMessage = null;
    });

    final res = await AuthService.resendVerification(email: widget.email);

    if (mounted) {
      setState(() {
        _isResending = false;
        _resendSuccess = res['success'] == true;
        _resendMessage = res['message'];
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
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(22.0, topInset + 78.0, 22.0, 32.0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(
                            child: NutriVietEntranceMotion(
                              child: NutriVietPulseHalo(
                                glowColor: Color(0xFF14803C),
                                size: 84,
                                child: NutriVietGlassIconTile(
                                  icon: PhosphorIconsDuotone.envelope,
                                  color: Color(0xFF14803C),
                                  size: 84,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),

                          NutriVietGlassCard(
                            cornerRadius: 26,
                            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  AppLocale.t(
                                    'Kiểm tra hộp thư Email',
                                    'Check Your Email Inbox',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                Text(
                                  AppLocale.t(
                                    'Chúng tôi đã gửi một liên kết xác thực đến địa chỉ:',
                                    'We sent an account verification link to:',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: Color(0xFF475569),
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD1FAE5).withValues(alpha: 0.78),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF14803C).withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Text(
                                      widget.email,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF065F46),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                Text(
                                  AppLocale.t(
                                    'Vui lòng mở hộp thư và bấm vào nút kích hoạt tài khoản để hoàn tất đăng ký.',
                                    'Please open your email and click the activation button to complete registration.',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF64748B),
                                    height: 1.4,
                                  ),
                                ),

                                if (_resendMessage != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (_resendSuccess
                                              ? const Color(0xFFD1FAE5)
                                              : const Color(0xFFFEE2E2))
                                          .withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _resendSuccess
                                            ? const Color(0xFF14803C)
                                            : const Color(0xFFEF4444),
                                      ),
                                    ),
                                    child: Text(
                                      _resendMessage!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _resendSuccess
                                            ? const Color(0xFF065F46)
                                            : const Color(0xFF991B1B),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          NutriVietGlassActionButton(
                            label: AppLocale.t(
                              'Tôi đã kích hoạt - Đăng nhập',
                              'I have verified - Sign in',
                            ),
                            icon: PhosphorIconsDuotone.checkCircle,
                            onPressed: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                                (route) => false,
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          NutriVietGlassActionButton(
                            label: AppLocale.t(
                              'Chưa nhận được? Gửi lại email',
                              'Didn\'t receive it? Resend email',
                            ),
                            icon: PhosphorIconsDuotone.paperPlaneTilt,
                            isPrimary: false,
                            isLoading: _isResending,
                            onPressed: _handleResend,
                          ),
                        ],
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
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: LiquidGlassBatch.exclude(
                    child: LiquidGlassAppBar(
                      style: NutriVietGlass.appBar,
                      width: double.infinity,
                      leading: IconButton(
                        icon: const PhosphorIcon(
                          PhosphorIconsBold.caretLeft,
                          color: Color(0xFF0F172A),
                          size: 20,
                        ),
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        },
                      ),
                      title: Text(
                        AppLocale.t('Xác Thực Email', 'Verify Email'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
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
}
