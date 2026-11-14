import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../l10n/app_locale.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../theme/nutriviet_glass.dart';
import '../widgets/nutriviet_ui.dart';
import 'allergy_profile_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final int userId;
  final String userName;
  final String userEmail;
  final VoidCallback? onProfileUpdated;

  const SettingsScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
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
  String _language = AppLocale.code;
  bool _notifyBadges = true;
  bool _notifyReminders = false;
  bool _isLoading = true;

  List<Map<String, String>> get _chronicCatalog => [
        {
          'code': 'diabetes',
          'name': AppLocale.t('Tiểu đường', 'Diabetes'),
          'desc': AppLocale.t(
            'Cảnh báo đường tinh luyện, si-rô, mạch nha và đường đơn trong thực phẩm',
            'Warns about refined sugar, syrups, maltose, and glucose in food products',
          ),
        },
        {
          'code': 'hypertension',
          'name': AppLocale.t('Tăng huyết áp', 'Hypertension'),
          'desc': AppLocale.t(
            'Cảnh báo muối natri, bột ngọt (E621) và các phụ gia giàu natri',
            'Warns about dietary sodium, MSG (E621), and high-sodium food additives',
          ),
        },
        {
          'code': 'gout',
          'name': AppLocale.t('Bệnh Gút (Axit Uric)', 'Gout (High Uric Acid)'),
          'desc': AppLocale.t(
            'Cảnh báo hải sản giàu purin, chất điều vị và đồ uống lên men',
            'Warns about high-purine seafood, flavor enhancers, and fermented drinks',
          ),
        },
        {
          'code': 'cholesterol',
          'name': AppLocale.t('Mỡ máu / Cholesterol cao', 'High Cholesterol'),
          'desc': AppLocale.t(
            'Cảnh báo mỡ động vật, dầu cọ tinh luyện và chất béo bão hòa',
            'Warns about animal fats, refined palm oil, and saturated fatty acids',
          ),
        },
      ];

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
    final trimmed = _currentName.trim();
    if (trimmed.isEmpty) return AppLocale.t('Tôi', 'Me');
    final parts = trimmed.split(RegExp(r'\s+'));
    for (final p in parts) {
      if (p.toLowerCase() == 'bình' || p.toLowerCase() == 'binh') {
        return 'Bình';
      }
    }
    final target = parts.length > 3 ? parts.first : parts.last;
    return target[0].toUpperCase() + (target.length > 1 ? target.substring(1) : '');
  }

  String get _chronicsSummary {
    if (_chronics.isEmpty) return AppLocale.t('Không có', 'None');
    if (_chronics.length == 1) {
      final c = _chronics.first;
      return AppLocale.translateChronicCode(
        c['code']?.toString(),
        fallback: (c['name'] ?? c['code']).toString(),
      );
    }
    return AppLocale.t(
      '${_chronics.length} tình trạng',
      '${_chronics.length} conditions',
    );
  }

  String get _languageLabel {
    return AppLocale.isEn ? 'English' : 'Tiếng Việt';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ProfileService.getChronics(widget.userId),
      ProfileService.getAllergens(widget.userId),
      ProfileService.getSettings(widget.userId),
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
    }
    setState(() => _isLoading = false);
  }

  Future<void> _persistSettings() async {
    await ProfileService.saveSettings(
      userId: widget.userId,
      language: _language,
      notifyBadges: _notifyBadges,
      notifyReminders: _notifyReminders,
    );
    widget.onProfileUpdated?.call();
  }

  Future<void> _openChronicsSheet() async {
    final activeCodes = _chronics.map((c) => c['code'].toString()).toSet();
    final catalog = _chronicCatalog;
    await showLiquidGlassSheet(
      context: context,
      isScrollControlled: true,
      anchor: LiquidGlassSheetAnchor.attached,
      grabber: true,
      style: NutriVietGlass.lightSheet,
      foregroundColor: NutriVietGlass.inkPrimary,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    AppLocale.t('Tình trạng của tôi', 'My Health Conditions'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppLocale.t(
                      'Chọn các tình trạng sức khỏe để hệ thống tự động cảnh báo đường, muối hoặc chất béo khi quét nhãn.',
                      'Select your health conditions so the system automatically flags sugar, salt, or fat when scanning labels.',
                    ),
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF4B5563)),
                  ),
                  const SizedBox(height: 14),
                  ...catalog.map((item) {
                    final code = item['code']!;
                    final isChecked = activeCodes.contains(code);
                    return CheckboxListTile(
                      value: isChecked,
                      activeColor: _brandGreen,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item['name']!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                          color: Color(0xFF111827),
                        ),
                      ),
                      subtitle: Text(
                        item['desc']!,
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          if (val == true) {
                            activeCodes.add(code);
                          } else {
                            activeCodes.remove(code);
                          }
                        });
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                  LiquidGlassButton(
                    width: double.infinity,
                    height: 50,
                    style: NutriVietGlass.emeraldButton,
                    foregroundColor: Colors.white,
                    label: AppLocale.t('Lưu tình trạng sức khỏe', 'Save health conditions'),
                    touch: const LiquidGlassTouch.flexing(LiquidGlassFlex.subtle()),
                    onPressed: () async {
                      final payload = catalog
                          .where((c) => activeCodes.contains(c['code']))
                          .map((c) => {'code': c['code']!, 'name': c['name']!})
                          .toList();
                      final res = await ProfileService.saveChronics(
                        userId: widget.userId,
                        chronics: payload,
                      );
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (res['success'] == true) {
                        await _loadData();
                        widget.onProfileUpdated?.call();
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              res['message'] ??
                                  AppLocale.t(
                                    'Không thể lưu tình trạng sức khỏe.',
                                    'Unable to save health conditions.',
                                  ),
                            ),
                            backgroundColor: const Color(0xFFDC2626),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
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

    await showLiquidGlassSheet(
      context: context,
      anchor: LiquidGlassSheetAnchor.attached,
      grabber: true,
      style: NutriVietGlass.lightSheet,
      foregroundColor: NutriVietGlass.inkPrimary,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                AppLocale.t('Ngôn ngữ giao diện', 'App Language'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 10),
              ...options.map((opt) {
                final selected = AppLocale.code == opt['value'];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    opt['label']!,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? _brandGreen : const Color(0xFF111827),
                    ),
                  ),
                  subtitle: Text(
                    opt['sub']!,
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                  ),
                  trailing: selected
                      ? const PhosphorIcon(
                          PhosphorIconsFill.checkCircle,
                          color: _brandGreen,
                          size: 22,
                        )
                      : null,
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
      MaterialPageRoute(
        builder: (_) => AllergyProfileScreen(
          userId: widget.userId,
          userName: _currentName,
          userEmail: widget.userEmail,
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

    await showLiquidGlassDialog(
      context: context,
      builder: (ctx) {
        String? errorMsg;
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return LiquidGlassAlertDialog(
              style: NutriVietGlass.lightSheet,
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
                LiquidGlassButton(
                  height: 42,
                  style: NutriVietGlass.neutralButton,
                  foregroundColor: const Color(0xFF1F2937),
                  label: AppLocale.t('Hủy', 'Cancel'),
                  onPressed: () => Navigator.pop(ctx),
                ),
                LiquidGlassButton(
                  height: 42,
                  style: NutriVietGlass.emeraldButton,
                  foregroundColor: Colors.white,
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            res['message'] ??
                                AppLocale.t(
                                  'Đổi mật khẩu thành công!',
                                  'Password changed successfully!',
                                ),
                          ),
                          backgroundColor: _brandGreen,
                        ),
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
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: ListView(
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
                    icon: PhosphorIconsDuotone.heartbeat,
                    iconColor: _brandGreen,
                    title: AppLocale.t('Tình trạng của tôi', 'My conditions'),
                    trailingText: _isLoading ? '...' : _chronicsSummary,
                    onTap: _openChronicsSheet,
                  ),
                  _buildSettingRow(
                    icon: PhosphorIconsDuotone.usersThree,
                    iconColor: _brandGreen,
                    title: AppLocale.t('Quản lý hồ sơ', 'Manage profiles'),
                    trailingText: _shortName,
                    onTap: _openAllergyProfile,
                  ),
                  _buildSettingRow(
                    icon: PhosphorIconsDuotone.shieldWarning,
                    iconColor: _brandGreen,
                    title: AppLocale.t('Quản lý dị ứng', 'Manage allergies'),
                    trailingText: _allergens.isEmpty
                        ? ''
                        : AppLocale.t(
                            '${_allergens.length} nhóm',
                            '${_allergens.length} groups',
                          ),
                    onTap: _openAllergyProfile,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                AppLocale.t(
                  'Các cài đặt này cung cấp cảnh báo thực phẩm cá nhân hóa, chẳng hạn như cảnh báo đường cho bệnh tiểu đường.',
                  'These settings provide personalized food alerts, such as sugar warnings for diabetes.',
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
              child: Column(
                children: [
                  _buildSwitchRow(
                    icon: PhosphorIconsDuotone.medal,
                    iconColor: _brandPurple,
                    title: AppLocale.t('Chúc mừng huy hiệu', 'Badge celebrations'),
                    subtitle: AppLocale.t(
                      'Một thông báo ngắn khi bạn mở khóa huy hiệu mới.',
                      'A brief notification when you unlock a new badge.',
                    ),
                    value: _notifyBadges,
                    onChanged: (v) async {
                      setState(() => _notifyBadges = v);
                      await _persistSettings();
                    },
                  ),
                  const SizedBox(height: 6),
                  _buildSwitchRow(
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
                ],
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
                  _buildSettingRow(
                    icon: PhosphorIconsDuotone.lockKey,
                    iconColor: _brandGreen,
                    title: AppLocale.t('Đổi mật khẩu', 'Change password'),
                    trailingText: widget.userEmail,
                    onTap: _openPasswordDialog,
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
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
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
              if (trailingText.isNotEmpty) ...[
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
          LiquidGlassSwitch(
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
