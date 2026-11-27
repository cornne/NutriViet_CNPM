import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:phosphor_icons/phosphor_icons.dart';
import '../l10n/app_locale.dart';
import '../services/auth_service.dart';
import '../services/local_guest_store.dart';
import '../services/profile_service.dart';
import '../theme/nutriviet_glass.dart';
import '../theme/nutriviet_route.dart';
import '../widgets/nutriviet_glass_modal.dart';
import '../widgets/nutriviet_notice.dart';
import '../widgets/nutriviet_shimmer.dart';
import '../widgets/nutriviet_ui.dart';
import 'admin_moderation_screen.dart';
import 'allergy_profile_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final int userId;
  final String userName;
  final String userEmail;
  final bool isGuest;
  final String userRole;
  final String authToken;
  final VoidCallback? onProfileUpdated;

  const SettingsScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.isGuest = false,
    this.userRole = 'user',
    this.authToken = '',
    this.onProfileUpdated,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color _brandGreen = Color(0xFF14803C);
  static const Color _brandPurple = Color(0xFF4F37C8);

  late String _currentName;
  List<Map<String, dynamic>> _chronics = [];
  List<Map<String, dynamic>> _allergens = [];
  List<Map<String, dynamic>> _familyMembers = [];
  String _language = AppLocale.code;
  bool _notifyBadges = true;
  bool _notifyReminders = false;
  bool _scanDerivatives = true;
  bool _warnTraces = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentName = widget.userName;
    _language = AppLocale.code;
    _loadData();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userName != widget.userName) {
      _currentName = widget.userName;
    }
  }

  String get _shortName {
    if (widget.isGuest) return AppLocale.t('Khách', 'Guest');
    final trimmed = _currentName.trim();
    if (trimmed.isEmpty) return AppLocale.t('Tôi', 'Me');
    final parts = trimmed.split(RegExp(r'\s+'));
    final target = parts.length > 3 ? parts.first : parts.last;
    return target[0].toUpperCase() + (target.length > 1 ? target.substring(1) : '');
  }

  String get _healthProfileSummary {
    final alCount = _allergens.length;
    final chCount = _chronics.length;
    if (alCount == 0 && chCount == 0) {
      return AppLocale.t('Chưa thiết lập', 'Not set');
    }
    final parts = <String>[];
    if (alCount > 0) {
      parts.add(
        AppLocale.t(
          '$alCount dị ứng',
          '$alCount ${alCount == 1 ? 'allergy' : 'allergies'}',
        ),
      );
    }
    if (chCount > 0) {
      parts.add(
        AppLocale.t(
          '$chCount bệnh nền',
          '$chCount ${chCount == 1 ? 'condition' : 'conditions'}',
        ),
      );
    }
    return parts.join(' · ');
  }

  String get _familySummary {
    if (_familyMembers.length > 1) {
      return AppLocale.t(
        '${_familyMembers.length} thành viên',
        '${_familyMembers.length} members',
      );
    }
    return _shortName;
  }

  String get _languageLabel {
    return AppLocale.isEn ? 'English' : 'Tiếng Việt';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    if (widget.isGuest) {
      final results = await Future.wait([
        LocalGuestStore.getChronics(),
        LocalGuestStore.getAllergens(),
        LocalGuestStore.getSettings(),
        LocalGuestStore.getFamilyMembers(),
      ]);
      if (!mounted) return;
      _chronics = List<Map<String, dynamic>>.from(results[0]['chronics'] ?? []);
      _allergens = List<Map<String, dynamic>>.from(results[1]['allergens'] ?? []);
      final s = results[2]['settings'] is Map
          ? Map<String, dynamic>.from(results[2]['settings'] as Map)
          : <String, dynamic>{};
      _familyMembers = List<Map<String, dynamic>>.from(results[3]['members'] ?? []);
      final localLang = (s['language'] ?? '').toString();
      if (localLang == 'en' || localLang == 'vi') {
        _language = localLang;
        await AppLocale.setLanguage(_language);
      } else {
        _language = AppLocale.code;
      }
      _notifyBadges = s['notify_badges'] ?? true;
      _notifyReminders = s['notify_reminders'] ?? false;
      _scanDerivatives = s['scan_derivatives'] ?? true;
      _warnTraces = s['warn_traces'] ?? true;
      setState(() => _isLoading = false);
      return;
    }

    final results = await Future.wait([
      ProfileService.getChronics(widget.userId),
      ProfileService.getAllergens(widget.userId),
      ProfileService.getSettings(widget.userId),
      ProfileService.getFamilyMembers(widget.userId),
    ]);
    if (!mounted) return;

    if (results[0]['success'] == true) {
      _chronics = List<Map<String, dynamic>>.from(results[0]['chronics'] ?? []);
    }
    if (results[1]['success'] == true) {
      _allergens = List<Map<String, dynamic>>.from(results[1]['allergens'] ?? []);
    }
    if (results[2]['success'] == true && results[2]['settings'] is Map) {
      final s = results[2]['settings'] as Map;
      final backendLang = (s['language'] ?? '').toString();
      if (backendLang == 'en' || backendLang == 'vi') {
        _language = backendLang;
        await AppLocale.setLanguage(_language);
      } else {
        _language = AppLocale.code;
      }
      _notifyBadges = s['notify_badges'] ?? true;
      _notifyReminders = s['notify_reminders'] ?? false;
      _scanDerivatives = s['scan_derivatives'] ?? true;
      _warnTraces = s['warn_traces'] ?? true;
    }
    if (results[3]['success'] == true) {
      _familyMembers = List<Map<String, dynamic>>.from(results[3]['members'] ?? []);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _persistSettings() async {
    if (widget.isGuest) {
      await LocalGuestStore.saveSettings({
        'language': _language,
        'notify_badges': _notifyBadges,
        'notify_reminders': _notifyReminders,
        'scan_derivatives': _scanDerivatives,
        'warn_traces': _warnTraces,
      });
      widget.onProfileUpdated?.call();
      return;
    }
    await ProfileService.saveSettings(
      userId: widget.userId,
      language: _language,
      notifyBadges: _notifyBadges,
      notifyReminders: _notifyReminders,
      scanDerivatives: _scanDerivatives,
      warnTraces: _warnTraces,
    );
    widget.onProfileUpdated?.call();
  }

  Future<void> _openFamilyProfilesSheet() async {
    await showNutriVietGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      anchor: NutriVietGlassSheetAnchor.attached,
      grabber: true,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      builder: (_) => _FamilyProfilesSheet(
        userId: widget.userId,
        isGuest: widget.isGuest,
        initialUserName: _currentName,
        initialMembers: List<Map<String, dynamic>>.from(_familyMembers),
        onUserNameChanged: (newName) {
          if (!mounted) return;
          setState(() => _currentName = newName);
          widget.onProfileUpdated?.call();
        },
        onMembersChanged: (updatedMembers) {
          if (!mounted) return;
          setState(() => _familyMembers = updatedMembers);
          widget.onProfileUpdated?.call();
        },
      ),
    );
  }

  Future<void> _openLanguageSheet() async {
    final options = [
      {
        'value': 'vi',
        'label': 'Tiếng Việt',
        'sub': AppLocale.t(
          'Hiển thị toàn bộ giao diện và dữ liệu bằng Tiếng Việt',
          'Display the entire interface and data in Vietnamese',
        ),
      },
      {
        'value': 'en',
        'label': 'English',
        'sub': AppLocale.t(
          'Hiển thị toàn bộ giao diện và dữ liệu bằng Tiếng Anh',
          'Display the entire interface and data in English',
        ),
      },
    ];

    await showNutriVietGlassSheet(
      context: context,
      anchor: NutriVietGlassSheetAnchor.attached,
      grabber: true,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(
                AppLocale.t('Ngôn ngữ giao diện', 'App Language'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              ...options.map((opt) {
                final selected = AppLocale.code == opt['value'];
                return NutriVietGlassOptionRow(
                  title: opt['label']!,
                  subtitle: opt['sub']!,
                  selected: selected,
                  activeColor: _brandGreen,
                  onTap: () async {
                    final newLang = opt['value']!;
                    Navigator.pop(ctx);
                    await AppLocale.setLanguage(newLang);
                    if (mounted) {
                      setState(() => _language = newLang);
                    }
                    await _persistSettings();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAllergyProfile() async {
    final result = await Navigator.push(
      context,
      NutriVietPageRoute(
        builder: (_) => AllergyProfileScreen(
          userId: widget.userId,
          userName: _currentName,
          userEmail: widget.userEmail,
          isGuest: widget.isGuest,
        ),
      ),
    );
    if (result != null && result is Map) {
      final updatedName = result['full_name'] ?? result['name'];
      if (updatedName != null && updatedName.toString().isNotEmpty) {
        setState(() => _currentName = updatedName.toString());
      }
    }
    await _loadData();
    widget.onProfileUpdated?.call();
  }

  Future<void> _openPasswordDialog() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    await showNutriVietGlassDialog(
      context: context,
      builder: (ctx) {
        String? errorMsg;
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return NutriVietGlassDialog(
              title: Text(
                AppLocale.t('Đổi mật khẩu tài khoản', 'Change Account Password'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              content: DefaultTextStyle(
                style: const TextStyle(color: Color(0xFF111827)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMsg != null) ...[
                      Text(
                        errorMsg!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextField(
                      controller: currentCtrl,
                      obscureText: true,
                      style: const TextStyle(color: Color(0xFF111827)),
                      decoration: InputDecoration(
                        labelText: AppLocale.t('Mật khẩu hiện tại', 'Current password'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: newCtrl,
                      obscureText: true,
                      style: const TextStyle(color: Color(0xFF111827)),
                      decoration: InputDecoration(
                        labelText: AppLocale.t(
                          'Mật khẩu mới (tối thiểu 6 ký tự)',
                          'New password (min 6 characters)',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: confirmCtrl,
                      obscureText: true,
                      style: const TextStyle(color: Color(0xFF111827)),
                      decoration: InputDecoration(
                        labelText: AppLocale.t('Xác nhận mật khẩu mới', 'Confirm new password'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                NutriVietGlassPillButton(
                  height: 44,
                  variant: NutriVietGlassButtonVariant.neutral,
                  label: AppLocale.t('Hủy', 'Cancel'),
                  onPressed: () => Navigator.pop(ctx),
                ),
                NutriVietGlassPillButton(
                  height: 44,
                  isLoading: saving,
                  label: saving
                      ? AppLocale.t('Đang lưu...', 'Saving...')
                      : AppLocale.t('Lưu mật khẩu', 'Save password'),
                  onPressed: () async {
                    if (saving) return;
                    if (newCtrl.text.length < 6) {
                      setModalState(
                        () => errorMsg = AppLocale.t(
                          'Mật khẩu mới phải từ 6 ký tự trở lên.',
                          'New password must be at least 6 characters.',
                        ),
                      );
                      return;
                    }
                    if (newCtrl.text != confirmCtrl.text) {
                      setModalState(
                        () => errorMsg = AppLocale.t(
                          'Xác nhận mật khẩu không khớp.',
                          'Password confirmation does not match.',
                        ),
                      );
                      return;
                    }
                    setModalState(() {
                      saving = true;
                      errorMsg = null;
                    });
                    final res = await AuthService.changePassword(
                      userId: widget.userId,
                      currentPassword: currentCtrl.text,
                      newPassword: newCtrl.text,
                    );
                    if (!ctx.mounted) return;
                    if (res['success'] == true) {
                      Navigator.pop(ctx);
                      if (!mounted) return;
                      showNutriVietNotice(
                        context,
                        (res['message'] ??
                                AppLocale.t(
                                  'Đổi mật khẩu thành công!',
                                  'Password changed successfully!',
                                ))
                            .toString(),
                        tone: NutriVietNoticeTone.success,
                      );
                    } else {
                      setModalState(() {
                        saving = false;
                        errorMsg = res['message'] ??
                            AppLocale.t(
                              'Đổi mật khẩu thất bại.',
                              'Failed to change password.',
                            );
                      });
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        bottom: false,
        child: NutriVietGlassScrollArea(
          child: ListView(
            scrollCacheExtent: const ScrollCacheExtent.pixels(360),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            addRepaintBoundaries: false,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 128),
            children: [
              Text(
                AppLocale.t('Cài đặt', 'Settings'),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 18),

              // Section 1: Hồ sơ sức khỏe của bạn / Your health profile
              Text(
                AppLocale.t('Hồ sơ sức khỏe của bạn', 'Your health profile'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 10),
              NutriVietGlassCard(
                cornerRadius: 22,
                child: Column(
                  children: [
                    _buildSettingRow(
                      icon: PhosphorIconsDuotone.shieldWarning,
                      iconColor: _brandGreen,
                      title: AppLocale.t(
                        'Dị ứng & sức khỏe',
                        'Allergies & health',
                      ),
                      trailingText: _healthProfileSummary,
                      isRowLoading: _isLoading,
                      onTap: _openAllergyProfile,
                    ),
                    Divider(
                      height: 1,
                      indent: 68,
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                    _buildSettingRow(
                      icon: PhosphorIconsDuotone.usersThree,
                      iconColor: _brandGreen,
                      title: AppLocale.t('Hồ sơ gia đình', 'Family profiles'),
                      trailingText: _familySummary,
                      isRowLoading: _isLoading,
                      onTap: _openFamilyProfilesSheet,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                AppLocale.t(
                  'Quản lý nhóm dị ứng, bệnh nền và danh sách thành viên gia đình để nhận cảnh báo phù hợp khi quét nhãn.',
                  'Manage food allergies, health conditions, and family members for tailored alerts when scanning labels.',
                ),
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Section 2: Tùy chọn / Preferences
            Text(
              AppLocale.t('Tùy chọn', 'Preferences'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 10),
            NutriVietGlassCard(
              cornerRadius: 22,
              child: _buildSettingRow(
                icon: PhosphorIconsDuotone.translate,
                iconColor: _brandPurple,
                title: AppLocale.t('Ngôn ngữ', 'Language'),
                trailingText: _languageLabel,
                onTap: _openLanguageSheet,
              ),
            ),

            const SizedBox(height: 24),

            // Section 3: Thông báo / Notifications
            Text(
              AppLocale.t('Thông báo', 'Notifications'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 10),
            NutriVietGlassCard(
              cornerRadius: 22,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _buildSwitchRow(
                icon: PhosphorIconsDuotone.bellRinging,
                iconColor: _brandPurple,
                title: AppLocale.t('Nhắc nhở nhẹ nhàng', 'Gentle reminders'),
                subtitle: AppLocale.t(
                  'Nhắc nhở đôi khi nếu bạn chưa quét trong một thời gian.',
                  'Occasional reminders if you have not scanned labels in a while.',
                ),
                value: _notifyReminders,
                onChanged: (v) async {
                  setState(() => _notifyReminders = v);
                  await _persistSettings();
                },
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                AppLocale.t(
                  'Bạn tự chọn những gì ứng dụng có thể thông báo cho bạn.',
                  'You choose what the app can notify you about.',
                ),
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Section 4: Tài khoản & Bảo mật / Account
            Text(
              AppLocale.t('Tài khoản', 'Account'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 10),
            NutriVietGlassCard(
              cornerRadius: 22,
              child: Column(
                children: [
                  if (widget.isGuest) ...[
                    _buildSettingRow(
                      icon: PhosphorIconsDuotone.signIn,
                      iconColor: _brandGreen,
                      title: AppLocale.t(
                        'Đăng nhập & Đồng bộ Cloud',
                        'Sign In & Cloud Sync',
                      ),
                      trailingText: AppLocale.t('Khách', 'Guest'),
                      onTap: () {
                        Navigator.push(
                          context,
                          NutriVietPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      indent: 68,
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                    _buildSettingRow(
                      icon: PhosphorIconsDuotone.signOut,
                      iconColor: const Color(0xFFDC2626),
                      title: AppLocale.t('Thoát chế độ Khách', 'Exit Guest Mode'),
                      trailingText: '',
                      onTap: () async {
                        await AuthService.logout();
                        if (!context.mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          NutriVietPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                    ),
                  ] else ...[
                    if (widget.userRole.toLowerCase() == 'admin') ...[
                      _buildSettingRow(
                        icon: PhosphorIconsDuotone.shieldCheck,
                        iconColor: _brandPurple,
                        title: AppLocale.t('Quản trị Cộng đồng', 'Admin Moderation'),
                        trailingText: 'ADMIN',
                        onTap: () {
                          Navigator.push(
                            context,
                            NutriVietPageRoute(
                              builder: (_) => AdminModerationScreen(
                                token: widget.authToken,
                                currentUserId: widget.userId,
                              ),
                            ),
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        indent: 68,
                        color: Colors.black.withValues(alpha: 0.05),
                      ),
                    ],
                    _buildSettingRow(
                      icon: PhosphorIconsDuotone.lockKey,
                      iconColor: _brandGreen,
                      title: AppLocale.t('Đổi mật khẩu', 'Change password'),
                      trailingText: widget.userEmail,
                      onTap: _openPasswordDialog,
                    ),
                    Divider(
                      height: 1,
                      indent: 68,
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                    _buildSettingRow(
                      icon: PhosphorIconsDuotone.signOut,
                      iconColor: const Color(0xFFDC2626),
                      title: AppLocale.t('Đăng xuất', 'Sign out'),
                      trailingText: '',
                      onTap: () async {
                        await AuthService.logout();
                        if (!context.mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          NutriVietPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String trailingText,
    required VoidCallback onTap,
    bool isRowLoading = false,
  }) {
    return NutriVietPressScale(
      pressedScale: 0.985,
      enableHaptic: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              NutriVietGlassIconTile(
                icon: icon,
                color: iconColor,
                size: 38,
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 12),
              if (isRowLoading) ...[
                const Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: NutriVietSettingsRowSkeleton(width: 84),
                  ),
                ),
                const SizedBox(width: 6),
              ] else if (trailingText.isNotEmpty) ...[
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      ),
                      child: Text(
                        trailingText,
                        key: ValueKey(trailingText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ] else
                const Spacer(),
              const PhosphorIcon(
                PhosphorIconsBold.caretRight,
                color: Color(0xFF9CA3AF),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final activeTileColor = value ? iconColor : const Color(0xFF6B7280);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: value ? 1.04 : 0.98,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: NutriVietGlassIconTile(
              icon: icon,
              color: activeTileColor,
              size: 38,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF6B7280),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          NutriVietGlassSwitch(
            value: value,
            activeColor: _brandGreen,
            inactiveColor: const Color(0xFFD1D5DB),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _FamilyProfilesSheet extends StatefulWidget {
  final int userId;
  final bool isGuest;
  final String initialUserName;
  final List<Map<String, dynamic>> initialMembers;
  final ValueChanged<String> onUserNameChanged;
  final ValueChanged<List<Map<String, dynamic>>> onMembersChanged;

  const _FamilyProfilesSheet({
    required this.userId,
    required this.isGuest,
    required this.initialUserName,
    required this.initialMembers,
    required this.onUserNameChanged,
    required this.onMembersChanged,
  });

  @override
  State<_FamilyProfilesSheet> createState() => _FamilyProfilesSheetState();
}

class _FamilyProfilesSheetState extends State<_FamilyProfilesSheet> {
  static const Color _brandGreen = Color(0xFF14803C);
  static const Color _brandPurple = Color(0xFF4F37C8);

  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _memberNameCtrl;
  late final TextEditingController _memberRelCtrl;
  late List<Map<String, dynamic>> _members;

  bool _savingName = false;
  bool _addingMember = false;
  final Set<int> _deletingIds = {};
  String? _errorText;

  List<String> get _quickRelationships => [
        AppLocale.t('Con cái', 'Child'),
        AppLocale.t('Vợ/Chồng', 'Spouse'),
        AppLocale.t('Bố/Mẹ', 'Parent'),
        AppLocale.t('Người thân', 'Family'),
      ];

  @override
  void initState() {
    super.initState();
    _displayNameCtrl = TextEditingController(text: widget.initialUserName);
    _memberNameCtrl = TextEditingController();
    _memberRelCtrl = TextEditingController(
      text: AppLocale.t('Người thân', 'Family'),
    );
    _members = List<Map<String, dynamic>>.from(widget.initialMembers);
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _memberNameCtrl.dispose();
    _memberRelCtrl.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14.5),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.82),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _brandGreen, width: 1.5),
      ),
    );
  }

  Future<void> _saveDisplayName() async {
    final trimmed = _displayNameCtrl.text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _errorText = AppLocale.t(
          'Vui lòng nhập tên hiển thị.',
          'Please enter a display name.',
        );
      });
      return;
    }
    if (_savingName) return;
    setState(() {
      _savingName = true;
      _errorText = null;
    });

    final res = await AuthService.updateProfile(
      userId: widget.userId,
      fullName: trimmed,
    );
    if (!mounted) return;
    setState(() => _savingName = false);
    if (res['success'] == true) {
      widget.onUserNameChanged(trimmed);
      showNutriVietNotice(
        context,
        AppLocale.t('Đã cập nhật tên hiển thị.', 'Display name updated.'),
        tone: NutriVietNoticeTone.success,
      );
    } else {
      setState(() {
        _errorText = (res['message'] ??
                AppLocale.t(
                  'Không thể cập nhật tên hiển thị.',
                  'Unable to update display name.',
                ))
            .toString();
      });
    }
  }

  Future<void> _addMember() async {
    final name = _memberNameCtrl.text.trim();
    final rel = _memberRelCtrl.text.trim().isEmpty
        ? AppLocale.t('Người thân', 'Family')
        : _memberRelCtrl.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorText = AppLocale.t(
          'Vui lòng nhập tên thành viên.',
          'Please enter a member name.',
        );
      });
      return;
    }
    if (_addingMember) return;
    setState(() {
      _addingMember = true;
      _errorText = null;
    });

    final res = widget.isGuest
        ? await LocalGuestStore.addFamilyMember(
            memberName: name,
            relationship: rel,
          )
        : await ProfileService.addFamilyMember(
            userId: widget.userId,
            memberName: name,
            relationship: rel,
          );
    if (!mounted) return;
    setState(() => _addingMember = false);

    if (res['success'] == true) {
      final updated = List<Map<String, dynamic>>.from(res['members'] ?? []);
      setState(() {
        _members = updated;
        _memberNameCtrl.clear();
      });
      widget.onMembersChanged(updated);
      showNutriVietNotice(
        context,
        AppLocale.t('Đã thêm thành viên "$name".', 'Added member "$name".'),
        tone: NutriVietNoticeTone.success,
      );
    } else {
      setState(() {
        _errorText = (res['message'] ??
                AppLocale.t(
                  'Không thể thêm thành viên.',
                  'Unable to add family member.',
                ))
            .toString();
      });
    }
  }

  Future<void> _deleteMember(int memberId, String displayName) async {
    if (_deletingIds.contains(memberId)) return;
    setState(() {
      _deletingIds.add(memberId);
      _errorText = null;
    });

    final res = widget.isGuest
        ? await LocalGuestStore.deleteFamilyMember(memberId)
        : await ProfileService.deleteFamilyMember(
            userId: widget.userId,
            memberId: memberId,
          );
    if (!mounted) return;
    setState(() => _deletingIds.remove(memberId));

    if (res['success'] == true) {
      final updated = List<Map<String, dynamic>>.from(res['members'] ?? []);
      setState(() => _members = updated);
      widget.onMembersChanged(updated);
      showNutriVietNotice(
        context,
        AppLocale.t('Đã xóa "$displayName".', 'Removed "$displayName".'),
        tone: NutriVietNoticeTone.info,
      );
    } else {
      setState(() {
        _errorText = (res['message'] ??
                AppLocale.t(
                  'Không thể xóa thành viên.',
                  'Unable to remove family member.',
                ))
            .toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: NutriVietGlassScrollArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                const SizedBox(height: 6),
                Text(
                  AppLocale.t('Hồ sơ gia đình', 'Family profiles'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppLocale.t(
                    'Quản lý tên hiển thị và thành viên gia đình để chọn nhanh khi quét nhãn thực phẩm.',
                    'Manage your display name and family members for quick selection when scanning food labels.',
                  ),
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF4B5563),
                    height: 1.4,
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      _errorText!,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (!widget.isGuest) ...[
                  const SizedBox(height: 16),
                  Text(
                    AppLocale.t('Tên hiển thị', 'Display name'),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _displayNameCtrl,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _saveDisplayName(),
                          decoration: _fieldDecoration(
                            AppLocale.t('Họ và tên của bạn', 'Your full name'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      NutriVietGlassPillButton(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        isLoading: _savingName,
                        label: AppLocale.t('Lưu', 'Save'),
                        onPressed: _saveDisplayName,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  AppLocale.t(
                    'Thành viên (${_members.length})',
                    'Members (${_members.length})',
                  ),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                if (_members.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Text(
                      AppLocale.t(
                        'Chưa có thành viên nào.',
                        'No family members yet.',
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  )
                else
                  ..._members.map((member) {
                    final rawId = member['id'];
                    final memberId = rawId is int ? rawId : int.tryParse('$rawId');
                    final isPrimary =
                        member['is_primary'] == 1 || member['is_primary'] == true;
                    final displayName = AppLocale.translateMemberName(
                      member['member_name']?.toString(),
                    );
                    final relationship = AppLocale.translateRelationship(
                      member['relationship']?.toString(),
                    );
                    final isDeleting =
                        memberId != null && _deletingIds.contains(memberId);
                    final initial = displayName.isNotEmpty
                        ? displayName.substring(0, 1).toUpperCase()
                        : 'U';
                    final accent = isPrimary ? _brandGreen : _brandPurple;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              initial,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  relationship,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isPrimary)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _brandGreen.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                AppLocale.t('Chính', 'Primary'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _brandGreen,
                                ),
                              ),
                            )
                          else if (memberId != null)
                            IconButton(
                              onPressed: isDeleting
                                  ? null
                                  : () => _deleteMember(memberId, displayName),
                              tooltip: AppLocale.t(
                                'Xóa thành viên',
                                'Remove member',
                              ),
                              icon: isDeleting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFDC2626),
                                      ),
                                    )
                                  : const PhosphorIcon(
                                      PhosphorIconsRegular.trash,
                                      size: 19,
                                      color: Color(0xFFDC2626),
                                    ),
                            ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 14),
                Text(
                  AppLocale.t('Thêm thành viên mới', 'Add a family member'),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _memberNameCtrl,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 15,
                  ),
                  textInputAction: TextInputAction.next,
                  decoration: _fieldDecoration(
                    AppLocale.t(
                      'Tên thành viên (VD: Mẹ, Bé An)',
                      'Member name (e.g., Mom, Leo)',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _quickRelationships.map((rel) {
                    final selected = _memberRelCtrl.text.trim() == rel;
                    return GestureDetector(
                      onTap: () => setState(() => _memberRelCtrl.text = rel),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? _brandGreen.withValues(alpha: 0.14)
                              : Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: selected
                                ? _brandGreen
                                : Colors.black.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text(
                          rel,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? _brandGreen
                                : const Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _memberRelCtrl,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 14.5,
                  ),
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _addMember(),
                  decoration: _fieldDecoration(
                    AppLocale.t('Mối quan hệ', 'Relationship'),
                  ),
                ),
                const SizedBox(height: 12),
                NutriVietGlassPillButton(
                  width: double.infinity,
                  height: 48,
                  isLoading: _addingMember,
                  label: AppLocale.t('Thêm thành viên', 'Add member'),
                  onPressed: _addMember,
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
