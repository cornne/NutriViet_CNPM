import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentPwdController = TextEditingController();
  final _newPwdController = TextEditingController();
  final _confirmPwdController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isChangingPwd = false;
  String? _pwdMessage;
  bool _pwdSuccess = false;

  String _displayName = '';
  String _displayEmail = '';

  @override
  void initState() {
    super.initState();
    _displayName = widget.user['full_name'] ?? '';
    _displayEmail = widget.user['email'] ?? '';
    _loadUserSession();
  }

  Future<void> _loadUserSession() async {
    if (_displayEmail.isEmpty || _displayName.isEmpty) {
      final session = await AuthService.getSession();
      if (session != null && mounted) {
        setState(() {
          if (_displayEmail.isEmpty) _displayEmail = session['email'] ?? '';
          if (_displayName.isEmpty) _displayName = session['full_name'] ?? '';
        });
      }
    }
  }

  @override
  void dispose() {
    _currentPwdController.dispose();
    _newPwdController.dispose();
    _confirmPwdController.dispose();
    super.dispose();
  }

  int get _userId {
    final rawId = widget.user['id'];
    if (rawId is int) return rawId;
    return int.tryParse(rawId?.toString() ?? '1') ?? 1;
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPwdController.text != _confirmPwdController.text) {
      setState(() {
        _pwdSuccess = false;
        _pwdMessage = 'Mật khẩu mới và xác nhận mật khẩu không trùng khớp!';
      });
      return;
    }

    setState(() {
      _isChangingPwd = true;
      _pwdMessage = null;
    });

    final res = await AuthService.changePassword(
      userId: _userId,
      currentPassword: _currentPwdController.text,
      newPassword: _newPwdController.text,
    );

    if (!mounted) return;

    setState(() {
      _isChangingPwd = false;
      _pwdSuccess = res['success'] == true;
      _pwdMessage = res['message'];
      if (_pwdSuccess) {
        _currentPwdController.clear();
        _newPwdController.clear();
        _confirmPwdController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final String fullName = _displayName.isNotEmpty ? _displayName : (widget.user['full_name'] ?? 'Người dùng');
    final String email = _displayEmail.isNotEmpty ? _displayEmail : (widget.user['email'] ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF334155), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Đổi Mật Khẩu',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User identity header card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : 'N',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Change Password Form Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.lock_reset_rounded, color: Color(0xFF10B981), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Cài Đặt Mật Khẩu Mới',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Nếu bạn vừa đăng nhập bằng mật khẩu tạm nhận từ Gmail, hãy nhập mật khẩu tạm vào ô "Mật khẩu hiện tại" để thiết lập mật khẩu mới an toàn.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                    ),
                    const SizedBox(height: 16),

                    // Current / Temp Password
                    const Text(
                      'Mật khẩu hiện tại (hoặc mật khẩu tạm):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _currentPwdController,
                      obscureText: _obscureCurrent,
                      decoration: InputDecoration(
                        hintText: 'Nhập mật khẩu cũ hoặc Nutri@...',
                        prefixIcon: const Icon(Icons.key_outlined, size: 20, color: Color(0xFF94A3B8)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 20,
                            color: const Color(0xFF94A3B8),
                          ),
                          onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Vui lòng nhập mật khẩu hiện tại' : null,
                    ),
                    const SizedBox(height: 14),

                    // New Password
                    const Text(
                      'Mật khẩu mới (tối thiểu 6 ký tự):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _newPwdController,
                      obscureText: _obscureNew,
                      decoration: InputDecoration(
                        hintText: 'Nhập mật khẩu mới',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20, color: Color(0xFF94A3B8)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 20,
                            color: const Color(0xFF94A3B8),
                          ),
                          onPressed: () => setState(() => _obscureNew = !_obscureNew),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Vui lòng nhập mật khẩu mới';
                        if (val.length < 6) return 'Mật khẩu phải từ 6 ký tự trở lên';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Confirm New Password
                    const Text(
                      'Xác nhận mật khẩu mới:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _confirmPwdController,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        hintText: 'Nhập lại mật khẩu mới',
                        prefixIcon: const Icon(Icons.lock_clock_outlined, size: 20, color: Color(0xFF94A3B8)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 20,
                            color: const Color(0xFF94A3B8),
                          ),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Vui lòng xác nhận mật khẩu mới' : null,
                    ),
                    const SizedBox(height: 18),

                    if (_pwdMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _pwdSuccess ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _pwdSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _pwdSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                              color: _pwdSuccess ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _pwdMessage!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _pwdSuccess ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    ElevatedButton(
                      onPressed: _isChangingPwd ? null : _handleChangePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isChangingPwd
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Cập Nhật Mật Khẩu Mới', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
