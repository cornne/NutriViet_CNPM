import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../l10n/app_locale.dart';
import '../services/auth_service.dart';
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
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: NutriVietEntranceMotion(
                  child: NutriVietPulseHalo(
                    glowColor: Color(0xFF14803C),
                    size: 80,
                    child: NutriVietGlassIconTile(
                      icon: PhosphorIconsDuotone.envelope,
                      color: Color(0xFF14803C),
                      size: 80,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                AppLocale.t('Kiểm tra hộp thư Email', 'Check Your Email Inbox'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),

              Text(
                AppLocale.t(
                  'Chúng tôi đã gửi một liên kết xác thực đến địa chỉ:\n${widget.email}',
                  'We sent an account verification link to:\n${widget.email}',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                AppLocale.t(
                  'Vui lòng mở hộp thư và bấm vào nút kích hoạt tài khoản để hoàn tất đăng ký.',
                  'Please open your email and click the activation button to complete registration.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 28),

              if (_resendMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _resendSuccess
                        ? const Color(0xFFD1FAE5)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _resendSuccess
                          ? const Color(0xFF10B981)
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
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

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
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    AppLocale.t(
                      'Tôi đã kích hoạt - Đăng nhập',
                      'I have verified - Sign in',
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: _isResending ? null : _handleResend,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isResending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF10B981),
                        ),
                      )
                    : Text(
                        AppLocale.t(
                          'Chưa nhận được? Gửi lại email',
                          'Didn\'t receive it? Resend email',
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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
