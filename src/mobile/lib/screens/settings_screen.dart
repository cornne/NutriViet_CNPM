import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../theme/nutriviet_glass.dart';
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
  String _language = 'system';
  bool _notifyBadges = true;
  bool _notifyReminders = false;
  bool _isLoading = true;

  static const List<Map<String, String>> _chronicCatalog = [
    {
      'code': 'diabetes',
      'name': 'Tiểu đường',
      'desc': 'Cảnh báo đường tinh luyện, si-rô, maltose, glucose trong thực phẩm',
    },
    {
      'code': 'hypertension',
      'name': 'Tăng huyết áp',
      'desc': 'Cảnh báo muối natri, bột ngọt (E621) và phụ gia giàu natri',
    },
    {
      'code': 'gout',
      'name': 'Bệnh Gút (Axit Uric)',
      'desc': 'Cảnh báo hải sản giàu purin, chất điều vị E621 và đồ uống lên men',
    },
    {
      'code': 'cholesterol',
      'name': 'Mỡ máu / Cholesterol cao',
      'desc': 'Cảnh báo mỡ động vật, dầu cọ tinh luyện và axit béo bão hòa',
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentName = widget.userName;
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
    if (trimmed.isEmpty) return 'Bình';
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
    if (_chronics.isEmpty) return 'Không có';
    final names = _chronics.map((c) => (c['name'] ?? c['code']).toString()).toList();
    if (names.length == 1) return names.first;
    return '${names.length} tình trạng';
  }

  String get _languageLabel {
    switch (_language) {
      case 'vi':
        return 'Tiếng Việt (VI)';
      case 'en':
        return 'English (EN)';
      default:
        return 'Mặc định của hệ thống';
    }
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
      _language = (s['language'] ?? 'system').toString();
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
                  const Text(
                    'Tình trạng của tôi',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Chọn các tình trạng sức khỏe để hệ thống FoodOn tự động cảnh báo đường, muối hoặc chất béo khi quét nhãn.',
                    style: TextStyle(fontSize: 13.5, color: Color(0xFF4B5563)),
                  ),
                  const SizedBox(height: 14),
                  ..._chronicCatalog.map((item) {
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
                    label: 'Lưu tình trạng sức khỏe',
                    touch: const LiquidGlassTouch.flexing(LiquidGlassFlex.subtle()),
                    onPressed: () async {
                      final payload = _chronicCatalog
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
                            content: Text(res['message'] ?? 'Không thể lưu tình trạng sức khỏe.'),
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
      {'value': 'system', 'label': 'Mặc định của hệ thống', 'sub': 'Tự động nhận diện Song ngữ (Tiếng Việt + Tiếng Anh)'},
      {'value': 'vi', 'label': 'Tiếng Việt (VI)', 'sub': 'Ưu tiên thuật ngữ Tiếng Việt từ Kala + FoodOn'},
      {'value': 'en', 'label': 'English (EN)', 'sub': 'Ưu tiên thuật ngữ chuẩn quốc tế FoodOn OWL'},
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
              const Text(
                'Ngôn ngữ',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 10),
              ...options.map((opt) {
                final selected = _language == opt['value'];
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
                  trailing: selected ? const Icon(Icons.check_circle_rounded, color: _brandGreen) : null,
                  onTap: () async {
                    setState(() => _language = opt['value']!);
                    Navigator.pop(ctx);
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
      if (result['name'] != null && result['name'].toString().isNotEmpty) {
        setState(() => _currentName = result['name'].toString());
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
              title: const Text(
                'Đổi mật khẩu tài khoản',
                style: TextStyle(
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
                      decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: newCtrl,
                      obscureText: true,
                      style: const TextStyle(color: Color(0xFF111827)),
                      decoration: const InputDecoration(labelText: 'Mật khẩu mới (tối thiểu 6 ký tự)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: confirmCtrl,
                      obscureText: true,
                      style: const TextStyle(color: Color(0xFF111827)),
                      decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu mới'),
                    ),
                  ],
                ),
              ),
              actions: [
                LiquidGlassButton(
                  height: 42,
                  style: NutriVietGlass.neutralButton,
                  foregroundColor: const Color(0xFF1F2937),
                  label: 'Hủy',
                  onPressed: () => Navigator.pop(ctx),
                ),
                LiquidGlassButton(
                  height: 42,
                  style: NutriVietGlass.emeraldButton,
                  foregroundColor: Colors.white,
                  label: saving ? 'Đang lưu...' : 'Lưu mật khẩu',
                  onPressed: () async {
                    if (saving) return;
                    if (newCtrl.text.length < 6) {
                      setModalState(() => errorMsg = 'Mật khẩu mới phải từ 6 ký tự trở lên.');
                      return;
                    }
                    if (newCtrl.text != confirmCtrl.text) {
                      setModalState(() => errorMsg = 'Xác nhận mật khẩu không khớp.');
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
                          content: Text(res['message'] ?? 'Đổi mật khẩu thành công!'),
                          backgroundColor: _brandGreen,
                        ),
                      );
                    } else {
                      setModalState(() {
                        saving = false;
                        errorMsg = res['message'] ?? 'Đổi mật khẩu thất bại.';
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
            const Text(
              'Cài đặt',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 18),

            // Section 1: Hồ sơ sức khỏe của bạn
            const Text(
              'Hồ sơ sức khỏe của bạn',
              style: TextStyle(
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
                    icon: Icons.assignment_ind_rounded,
                    iconColor: _brandGreen,
                    title: 'Tình trạng của tôi',
                    trailingText: _isLoading ? '...' : _chronicsSummary,
                    onTap: _openChronicsSheet,
                  ),
                  _buildSettingRow(
                    icon: Icons.people_alt_rounded,
                    iconColor: _brandGreen,
                    title: 'Quản lý hồ sơ',
                    trailingText: _shortName,
                    onTap: _openAllergyProfile,
                  ),
                  _buildSettingRow(
                    icon: Icons.warning_rounded,
                    iconColor: _brandGreen,
                    title: 'Quản lý dị ứng',
                    trailingText: _allergens.isEmpty ? '' : '${_allergens.length} nhóm',
                    onTap: _openAllergyProfile,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Các cài đặt này cung cấp cảnh báo thực phẩm cá nhân hóa, chẳng hạn như cảnh báo đường cho bệnh tiểu đường.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Section 2: Tùy chọn
            const Text(
              'Tùy chọn',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 10),
            NutriVietGlassCard(
              cornerRadius: 22,
              child: _buildSettingRow(
                icon: Icons.language_rounded,
                iconColor: _brandPurple,
                title: 'Ngôn ngữ',
                trailingText: _languageLabel,
                onTap: _openLanguageSheet,
              ),
            ),

            const SizedBox(height: 24),

            // Section 3: Thông báo
            const Text(
              'Thông báo',
              style: TextStyle(
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
                    icon: Icons.workspace_premium_outlined,
                    iconColor: _brandPurple,
                    title: 'Chúc mừng huy hiệu',
                    subtitle: 'Một thông báo ngắn khi bạn mở khóa huy hiệu mới.',
                    value: _notifyBadges,
                    onChanged: (v) async {
                      setState(() => _notifyBadges = v);
                      await _persistSettings();
                    },
                  ),
                  const SizedBox(height: 6),
                  _buildSwitchRow(
                    icon: Icons.notifications_rounded,
                    iconColor: _brandPurple,
                    title: 'Nhắc nhở nhẹ nhàng',
                    subtitle: 'Nhắc nhở đôi khi nếu bạn chưa quét trong một thời gian.',
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Bạn tự chọn những gì ứng dụng có thể thông báo cho bạn.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Section 4: Tài khoản & Bảo mật
            const Text(
              'Tài khoản',
              style: TextStyle(
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
                    icon: Icons.lock_outline_rounded,
                    iconColor: _brandGreen,
                    title: 'Đổi mật khẩu',
                    trailingText: widget.userEmail,
                    onTap: _openPasswordDialog,
                  ),
                  _buildSettingRow(
                    icon: Icons.logout_rounded,
                    iconColor: const Color(0xFFDC2626),
                    title: 'Đăng xuất',
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
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            if (trailingText.isNotEmpty) ...[
              Flexible(
                child: Text(
                  trailingText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9CA3AF),
              size: 22,
            ),
          ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
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
