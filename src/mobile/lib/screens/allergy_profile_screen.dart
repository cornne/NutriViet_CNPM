import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../l10n/app_locale.dart';
import '../services/auth_service.dart';
import '../services/local_guest_store.dart';
import '../services/profile_service.dart';
import '../theme/nutriviet_glass.dart';
import '../widgets/nutriviet_glass_modal.dart';
import '../widgets/nutriviet_notice.dart';
import '../widgets/nutriviet_shimmer.dart';
import '../widgets/nutriviet_ui.dart';
import 'home_screen.dart';

class AllergenChipItem {
  final String code;
  final String emoji;
  final String displayNameVi;
  final String displayNameEn;
  final String descriptionVi;
  final String descriptionEn;
  String? sourceFoodVi;
  String? sourceFoodEn;
  bool isSelected;
  String severity; // 'anaphylaxis', 'high', 'moderate', 'mild'

  AllergenChipItem({
    required this.code,
    required this.emoji,
    required this.displayNameVi,
    required this.displayNameEn,
    required this.descriptionVi,
    required this.descriptionEn,
    this.sourceFoodVi,
    this.sourceFoodEn,
    this.isSelected = false,
    this.severity = 'high',
  });

  String get displayName => AppLocale.t(displayNameVi, displayNameEn);
  String get description => AppLocale.t(descriptionVi, descriptionEn);

  String? get sourceFoodName {
    final v = AppLocale.isEn
        ? (sourceFoodEn ?? sourceFoodVi)
        : (sourceFoodVi ?? sourceFoodEn);
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  String get persistedName => sourceFoodName ?? displayName;

  String get severityLabel {
    switch (severity) {
      case 'anaphylaxis':
        return AppLocale.t('Sốc phản vệ', 'Anaphylaxis');
      case 'high':
        return AppLocale.t('Nghiêm trọng', 'Severe');
      case 'moderate':
        return AppLocale.t('Trung bình', 'Moderate');
      case 'mild':
        return AppLocale.t('Nhẹ', 'Mild');
      default:
        return AppLocale.t('Nghiêm trọng', 'Severe');
    }
  }

  Color get severityColor {
    switch (severity) {
      case 'anaphylaxis':
        return const Color(0xFFB91C1C);
      case 'high':
        return const Color(0xFFDC2626);
      case 'moderate':
        return const Color(0xFFD97706);
      case 'mild':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFFDC2626);
    }
  }
}

class ChronicConditionItem {
  final String id;
  final IconData icon;
  final String titleVi;
  final String titleEn;
  final String subtitleVi;
  final String subtitleEn;
  bool isActive;

  ChronicConditionItem({
    required this.id,
    required this.icon,
    required this.titleVi,
    required this.titleEn,
    required this.subtitleVi,
    required this.subtitleEn,
    this.isActive = false,
  });

  String get title => AppLocale.t(titleVi, titleEn);
  String get subtitle => AppLocale.t(subtitleVi, subtitleEn);
}

/// Focused Health & Allergy Profile screen.
///
/// Designed around what matters for label safety: food allergens (FoodOn
/// smart search + tactile 2-column allergen cards with dedicated severity
/// controls), dietary health conditions, and scan protection switches —
/// zero gender, height, weight, age, or BMI form clutter.
class AllergyProfileScreen extends StatefulWidget {
  final int userId;
  final String userName;
  final String? userEmail;
  final bool isInitialSetup;
  final bool isGuest;

  const AllergyProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userEmail,
    this.isInitialSetup = false,
    this.isGuest = false,
  });

  @override
  State<AllergyProfileScreen> createState() => _AllergyProfileScreenState();
}

class _AllergyProfileScreenState extends State<AllergyProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  late String _displayName;
  String _currentEmail = '';
  bool _nameEdited = false;

  late final TextEditingController _foodSearchController;

  bool _scanDerivatives = true;
  bool _warnTraces = true;
  bool _notifyBadges = true;
  bool _notifyReminders = false;
  bool _isSearchingFood = false;
  bool _allergensChanged = false;
  List<Map<String, dynamic>> _foodSearchResults = [];
  List<Map<String, String>> _quickEverydayFoods = [];

  final List<AllergenChipItem> _allergens = [
    AllergenChipItem(
      code: 'peanuts',
      emoji: '🥜',
      displayNameVi: 'Đậu phộng',
      displayNameEn: 'Peanuts',
      descriptionVi: 'Bơ đậu phộng, dầu lạc, kẹo lạc',
      descriptionEn: 'Peanut butter, oil, nut snacks',
      severity: 'anaphylaxis',
    ),
    AllergenChipItem(
      code: 'seafood',
      emoji: '🦐',
      displayNameVi: 'Hải sản & Cá',
      displayNameEn: 'Seafood & Fish',
      descriptionVi: 'Tôm, cua, mực, cá, nước mắm',
      descriptionEn: 'Shrimp, crab, squid, fish sauce',
      severity: 'high',
    ),
    AllergenChipItem(
      code: 'milk',
      emoji: '🥛',
      displayNameVi: 'Sữa & Chế phẩm',
      displayNameEn: 'Milk & Dairy',
      descriptionVi: 'Sữa bột, whey, casein, bơ, phô mai',
      descriptionEn: 'Milk powder, whey, casein, butter',
      severity: 'high',
    ),
    AllergenChipItem(
      code: 'gluten',
      emoji: '🌾',
      displayNameVi: 'Lúa mì / Gluten',
      displayNameEn: 'Wheat & Gluten',
      descriptionVi: 'Bột mì, mì gói, bánh mì, mạch nha',
      descriptionEn: 'Wheat flour, noodles, bread, malt',
      severity: 'high',
    ),
    AllergenChipItem(
      code: 'eggs',
      emoji: '🥚',
      displayNameVi: 'Trứng',
      displayNameEn: 'Eggs',
      descriptionVi: 'Bột trứng, sốt mayonnaise, E1105',
      descriptionEn: 'Egg powder, mayonnaise, E1105',
      severity: 'high',
    ),
    AllergenChipItem(
      code: 'soy',
      emoji: '🌱',
      displayNameVi: 'Đậu nành',
      displayNameEn: 'Soybeans',
      descriptionVi: 'Nước tương, đậu phụ, lecithin E322',
      descriptionEn: 'Soy sauce, tofu, lecithin E322',
      severity: 'high',
    ),
    AllergenChipItem(
      code: 'tree_nuts',
      emoji: '🌰',
      displayNameVi: 'Hạt cây',
      displayNameEn: 'Tree Nuts',
      descriptionVi: 'Điều, hạnh nhân, óc chó, mắc ca',
      descriptionEn: 'Cashew, almond, walnut, macadamia',
      severity: 'high',
    ),
    AllergenChipItem(
      code: 'sesame',
      emoji: '🌿',
      displayNameVi: 'Mè (Vừng)',
      displayNameEn: 'Sesame',
      descriptionVi: 'Hạt mè, dầu mè, bơ mè tahini',
      descriptionEn: 'Sesame seeds, oil, tahini paste',
      severity: 'high',
    ),
  ];

  final List<ChronicConditionItem> _conditions = [
    ChronicConditionItem(
      id: 'diabetes',
      icon: PhosphorIconsDuotone.drop,
      titleVi: 'Tiểu đường',
      titleEn: 'Diabetes',
      subtitleVi: 'Hạn chế đường & si-rô',
      subtitleEn: 'Limit sugars & syrups',
    ),
    ChronicConditionItem(
      id: 'hypertension',
      icon: PhosphorIconsDuotone.heartbeat,
      titleVi: 'Tăng huyết áp',
      titleEn: 'Hypertension',
      subtitleVi: 'Giảm muối & bột ngọt E621',
      subtitleEn: 'Reduce sodium & MSG',
    ),
    ChronicConditionItem(
      id: 'gout',
      icon: PhosphorIconsDuotone.flame,
      titleVi: 'Bệnh Gút',
      titleEn: 'Gout',
      subtitleVi: 'Tránh purin & đồ lên men',
      subtitleEn: 'Avoid purines & ferments',
    ),
    ChronicConditionItem(
      id: 'cholesterol',
      icon: PhosphorIconsDuotone.heartHalf,
      titleVi: 'Mỡ máu cao',
      titleEn: 'High Cholesterol',
      subtitleVi: 'Giảm chất béo bão hòa',
      subtitleEn: 'Limit saturated fats',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _displayName = widget.userName.trim();
    _currentEmail = (widget.userEmail ?? '').trim();
    _foodSearchController = TextEditingController();
    _loadUserEmail();
    _loadProfile();
    _loadQuickTriggerFoods();
  }

  @override
  void dispose() {
    _foodSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserEmail() async {
    if (_currentEmail.isEmpty && !widget.isGuest) {
      final session = await AuthService.getSession();
      if (session != null && mounted) {
        setState(() {
          _currentEmail = (session['email'] ?? '').toString().trim();
        });
      }
    }
  }

  Future<void> _loadQuickTriggerFoods() async {
    final res = await ProfileService.searchAllergyFoods(
      query: '',
      lang: AppLocale.code,
      limit: 8,
    );
    if (!mounted || res['success'] != true) return;
    final items = (res['items'] as List? ?? [])
        .whereType<Map>()
        .map((m) => {
              'label':
                  (m['food_name_en'] ?? m['food_name'] ?? '').toString().trim(),
              'emoji': (m['emoji'] ?? '🍽️').toString(),
            })
        .where((m) => (m['label'] ?? '').isNotEmpty)
        .toList();
    if (items.isNotEmpty) {
      setState(() => _quickEverydayFoods = items);
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final results = widget.isGuest
        ? await Future.wait([
            LocalGuestStore.getAllergens(),
            LocalGuestStore.getChronics(),
            LocalGuestStore.getSettings(),
          ])
        : await Future.wait([
            ProfileService.getAllergens(widget.userId),
            ProfileService.getChronics(widget.userId),
            ProfileService.getSettings(widget.userId),
          ]);

    if (!mounted) return;

    final allergenRes = results[0];
    final chronicsRes = results[1];
    final settingsRes = results[2];

    if (allergenRes['success'] == true) {
      final List saved = allergenRes['allergens'] ?? [];
      for (final a in _allergens) {
        a.isSelected = false;
        a.sourceFoodVi = null;
        a.sourceFoodEn = null;
      }
      for (final savedItem in saved) {
        final code = (savedItem['code'] ?? '').toString();
        final severity = (savedItem['severity'] ?? 'high').toString();
        final rawName = (savedItem['name'] ?? '').toString().trim();
        final srcEn =
            (savedItem['source_food_en'] ?? savedItem['source_food'] ?? '')
                .toString()
                .trim();
        bool matched = false;
        for (final item in _allergens) {
          if (item.code == code) {
            item.isSelected = true;
            item.severity = severity;
            if (srcEn.isNotEmpty) {
              item.sourceFoodVi = srcEn;
              item.sourceFoodEn = srcEn;
            } else if (rawName.isNotEmpty &&
                rawName != item.displayNameVi &&
                rawName != item.displayNameEn) {
              item.sourceFoodVi = rawName;
              item.sourceFoodEn = rawName;
            }
            matched = true;
          }
        }
        if (!matched && code.isNotEmpty) {
          final cleanLabel = srcEn.isNotEmpty
              ? srcEn
              : (rawName.isNotEmpty ? rawName : code);
          _allergens.add(
            AllergenChipItem(
              code: code,
              emoji: '🍽️',
              displayNameVi: cleanLabel,
              displayNameEn: cleanLabel,
              descriptionVi: 'FoodOn',
              descriptionEn: 'FoodOn',
              sourceFoodVi: cleanLabel,
              sourceFoodEn: cleanLabel,
              isSelected: true,
              severity: severity,
            ),
          );
        }
      }
    } else {
      _errorMessage = allergenRes['message'];
    }

    if (chronicsRes['success'] == true) {
      final List savedChronics = chronicsRes['chronics'] ?? [];
      for (final c in _conditions) {
        c.isActive = false;
      }
      for (final savedCh in savedChronics) {
        final code = savedCh['code'];
        for (final c in _conditions) {
          if (c.id == code) c.isActive = true;
        }
      }
    }

    if (settingsRes['success'] == true && settingsRes['settings'] is Map) {
      final s = settingsRes['settings'] as Map;
      _scanDerivatives = s['scan_derivatives'] ?? true;
      _warnTraces = s['warn_traces'] ?? true;
      _notifyBadges = s['notify_badges'] ?? true;
      _notifyReminders = s['notify_reminders'] ?? false;
    }

    setState(() => _isLoading = false);
  }

  Future<void> _searchEverydayAllergyFood(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      if (mounted) {
        setState(() {
          _foodSearchResults = [];
          _isSearchingFood = false;
        });
      }
      return;
    }
    setState(() => _isSearchingFood = true);
    final res = await ProfileService.searchAllergyFoods(
      query: q,
      lang: AppLocale.code,
      limit: 6,
    );
    if (!mounted) return;
    final items = (res['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    setState(() {
      _foodSearchResults = items;
      _isSearchingFood = false;
    });
  }

  Future<void> _autoSaveAllergens() async {
    _allergensChanged = true;
    final selectedAllergens = _allergens
        .where((item) => item.isSelected)
        .map((item) => {
              'code': item.code,
              'name': item.persistedName,
              'severity': item.severity,
            })
        .toList();
    if (widget.isGuest) {
      await LocalGuestStore.saveAllergens(selectedAllergens);
      return;
    }
    await ProfileService.saveAllergens(
      userId: widget.userId,
      allergens: selectedAllergens,
    );
  }

  Future<void> _selectEverydayAllergyFood(Map<String, dynamic> food) async {
    final alCode = (food['allergen_code'] ?? '').toString().trim();
    final foodEn =
        (food['food_name_en'] ?? food['food_name'] ?? '').toString().trim();
    final famEn = (food['family_name_en'] ?? food['family_name'] ?? foodEn)
        .toString()
        .trim();
    final relEn = (food['related_ingredients_en'] ??
            food['related_ingredients'] ??
            '')
        .toString()
        .trim();
    final emoji = (food['emoji'] ?? '🍽️').toString();

    if (alCode.isEmpty) return;
    HapticFeedback.mediumImpact();

    AllergenChipItem? target;
    for (final item in _allergens) {
      if (item.code == alCode) {
        target = item;
        break;
      }
    }

    setState(() {
      if (target != null) {
        target.isSelected = true;
        target.severity = 'high';
        target.sourceFoodVi = foodEn;
        target.sourceFoodEn = foodEn;
      } else {
        _allergens.add(
          AllergenChipItem(
            code: alCode,
            emoji: emoji,
            displayNameVi: famEn.isNotEmpty ? famEn : foodEn,
            displayNameEn: famEn.isNotEmpty ? famEn : foodEn,
            descriptionVi: relEn.isNotEmpty ? relEn : foodEn,
            descriptionEn: relEn.isNotEmpty ? relEn : foodEn,
            sourceFoodVi: foodEn,
            sourceFoodEn: foodEn,
            isSelected: true,
            severity: 'high',
          ),
        );
      }
      _foodSearchController.clear();
      _foodSearchResults = [];
    });

    await _autoSaveAllergens();
    if (!mounted) return;
    showNutriVietNotice(
      context,
      AppLocale.t(
        'Đã bật cảnh báo đỏ cho "$foodEn" (nhóm $famEn).',
        'Enabled RED alert for "$foodEn" ($famEn family).',
      ),
      tone: NutriVietNoticeTone.warning,
      duration: const Duration(seconds: 2),
    );
  }

  void _cycleSeverity(AllergenChipItem item) {
    HapticFeedback.selectionClick();
    setState(() {
      if (item.severity == 'anaphylaxis') {
        item.severity = 'high';
      } else if (item.severity == 'high') {
        item.severity = 'moderate';
      } else if (item.severity == 'moderate') {
        item.severity = 'mild';
      } else {
        item.severity = 'anaphylaxis';
      }
    });
    _autoSaveAllergens();
  }

  Future<void> _openRenameDialog() async {
    final ctrl = TextEditingController(text: _displayName);
    try {
      final updated = await showNutriVietGlassDialog<String>(
        context: context,
        builder: (ctx) => NutriVietGlassDialog(
          title: Text(
            AppLocale.t('Đổi tên hiển thị', 'Edit Display Name'),
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(fontSize: 15.5, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: AppLocale.t('Nhập họ và tên...', 'Enter full name...'),
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
              label: AppLocale.t('Lưu tên', 'Save'),
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            ),
          ],
        ),
      );
      if (updated != null && updated.isNotEmpty && updated != _displayName) {
        setState(() {
          _displayName = updated;
          _nameEdited = true;
        });
      }
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    if (!widget.isGuest &&
        _nameEdited &&
        _displayName.isNotEmpty &&
        _displayName != widget.userName) {
      await AuthService.updateProfile(
        userId: widget.userId,
        fullName: _displayName,
      );
    }

    final selectedAllergens = _allergens
        .where((item) => item.isSelected)
        .map((item) => {
              'code': item.code,
              'name': item.persistedName,
              'severity': item.severity,
            })
        .toList();

    final selectedChronics = _conditions
        .where((item) => item.isActive)
        .map((item) => {
              'code': item.id,
              'name': item.title,
            })
        .toList();

    final results = widget.isGuest
        ? await Future.wait([
            LocalGuestStore.saveAllergens(selectedAllergens),
            LocalGuestStore.saveChronics(selectedChronics),
            LocalGuestStore.saveSettings({
              'language': AppLocale.code,
              'notify_badges': _notifyBadges,
              'notify_reminders': _notifyReminders,
              'scan_derivatives': _scanDerivatives,
              'warn_traces': _warnTraces,
            }),
          ])
        : await Future.wait([
            ProfileService.saveAllergens(
              userId: widget.userId,
              allergens: selectedAllergens,
            ),
            ProfileService.saveChronics(
              userId: widget.userId,
              chronics: selectedChronics,
            ),
            ProfileService.saveSettings(
              userId: widget.userId,
              language: AppLocale.code,
              notifyBadges: _notifyBadges,
              notifyReminders: _notifyReminders,
              scanDerivatives: _scanDerivatives,
              warnTraces: _warnTraces,
            ),
          ]);

    final res = results[0];
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res['success'] == true) {
      showNutriVietNotice(
        context,
        AppLocale.t(
          'Đã lưu hồ sơ sức khỏe (${selectedAllergens.length} nhóm dị ứng).',
          'Health profile saved (${selectedAllergens.length} allergen groups).',
        ),
        tone: NutriVietNoticeTone.success,
      );
      final finalName =
          _displayName.isNotEmpty ? _displayName : widget.userName;
      if (widget.isInitialSetup) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(user: {
              'id': widget.userId,
              'full_name': finalName,
              'email': _currentEmail,
            }),
          ),
        );
      } else {
        Navigator.pop(context, {
          'updated': true,
          'full_name': finalName,
          'email': _currentEmail,
        });
      }
    } else {
      setState(() => _errorMessage = res['message']);
    }
  }

  Widget _buildSummaryBanner(int selectedAllergens, int selectedChronics) {
    final bool hasAlerts = selectedAllergens > 0;
    final Color accent =
        hasAlerts ? const Color(0xFFDC2626) : const Color(0xFF14803C);
    final String shownName = _displayName.isNotEmpty
        ? _displayName
        : (widget.isGuest
            ? AppLocale.t('Chế độ Khách', 'Guest Mode')
            : AppLocale.t('Hồ sơ của tôi', 'My Profile'));

    final String statusText;
    if (selectedAllergens == 0 && selectedChronics == 0) {
      statusText = AppLocale.t(
        'Chọn dị ứng hoặc tình trạng sức khỏe cần cảnh báo khi quét nhãn',
        'Select allergies or health conditions to monitor on food labels',
      );
    } else {
      final parts = <String>[];
      if (selectedAllergens > 0) {
        parts.add(
          AppLocale.t(
            '$selectedAllergens nhóm dị ứng đang bật',
            '$selectedAllergens active allergens',
          ),
        );
      }
      if (selectedChronics > 0) {
        parts.add(
          AppLocale.t(
            '$selectedChronics lưu ý sức khỏe',
            '$selectedChronics health conditions',
          ),
        );
      }
      statusText = parts.join('  •  ');
    }

    return NutriVietGlassCard(
      cornerRadius: 24,
      padding: const EdgeInsets.all(18),
      color: hasAlerts ? const Color(0xE8FFF5F5) : const Color(0xE8F3FBF6),
      border: Border.all(
        color: accent.withValues(alpha: 0.25),
        width: 1.2,
      ),
      child: Row(
        children: [
          NutriVietGlassIconTile(
            icon: hasAlerts
                ? PhosphorIconsDuotone.shieldWarning
                : PhosphorIconsDuotone.shieldCheck,
            color: accent,
            size: 50,
            isCircle: true,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        shownName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (!widget.isGuest) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _openRenameDialog,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: PhosphorIcon(
                            PhosphorIconsDuotone.pencilSimple,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: hasAlerts
                        ? const Color(0xFFB91C1C)
                        : const Color(0xFF334155),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodOnSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocale.t('Tìm món gây dị ứng', 'Find a trigger food'),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppLocale.t(
            'Nhập tên thực phẩm bất kỳ để FoodOn tự suy luận nhóm dị ứng liên quan',
            'Type any food and FoodOn automatically maps its allergen family',
          ),
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF64748B),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _foodSearchController,
          onChanged: _searchEverydayAllergyFood,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: AppLocale.t(
              'VD: Butter, Shrimp, Peanut, Whey...',
              'e.g. Butter, Shrimp, Peanut, Whey...',
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 14, right: 10),
              child: PhosphorIcon(
                PhosphorIconsBold.magnifyingGlass,
                size: 20,
                color: Color(0xFF14803C),
              ),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 44, minHeight: 44),
            suffixIcon: _foodSearchController.text.isNotEmpty
                ? IconButton(
                    icon: const PhosphorIcon(
                      PhosphorIconsBold.xCircle,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    onPressed: () {
                      _foodSearchController.clear();
                      _searchEverydayAllergyFood('');
                    },
                  )
                : null,
          ),
        ),
        if (_quickEverydayFoods.isNotEmpty && _foodSearchResults.isEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _quickEverydayFoods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final qf = _quickEverydayFoods[index];
                final label = qf['label']!;
                final isCurrent =
                    _foodSearchController.text.trim().toLowerCase() ==
                        label.toLowerCase();
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    _foodSearchController.text = label;
                    _searchEverydayAllergyFood(label);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xD8FFFFFF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCurrent
                            ? const Color(0xFFDC2626)
                            : const Color(0xFFDDE5DF),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${qf['emoji']} $label',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isCurrent
                              ? const Color(0xFFB91C1C)
                              : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        if (_isSearchingFood) ...[
          const SizedBox(height: 12),
          const NutriVietFoodSearchSkeleton(itemCount: 3),
        ] else if (_foodSearchResults.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._foodSearchResults.map((food) {
            final alCode = (food['allergen_code'] ?? '').toString();
            final curie = (food['curie'] ?? '').toString();
            final emoji = (food['emoji'] ?? '🍽️').toString();
            final foodName =
                (food['food_name_en'] ?? food['food_name'] ?? curie).toString();
            final famName =
                (food['family_name_en'] ?? food['family_name'] ?? '')
                    .toString();
            final isAlreadySelected = _allergens.any(
              (a) => a.code == alCode && a.isSelected,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _selectEverydayAllergyFood(food),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isAlreadySelected
                        ? const Color(0xFFFEF2F2)
                        : const Color(0xE8FFFFFF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isAlreadySelected
                          ? const Color(0xFFDC2626)
                          : const Color(0xFFDDE5DF),
                      width: isAlreadySelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              foodName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppLocale.t(
                                'Nhóm FoodOn: $famName',
                                'FoodOn family: $famName',
                              ),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isAlreadySelected
                              ? const Color(0xFFDC2626)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isAlreadySelected
                              ? AppLocale.t('Đã bật', 'Active')
                              : AppLocale.t('+ Chọn', '+ Add'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isAlreadySelected
                                ? Colors.white
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildAllergenGridSection(int selectedCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                AppLocale.t('Nhóm dị ứng thực phẩm', 'Food Allergens'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (selectedCount > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  AppLocale.t('$selectedCount đã chọn', '$selectedCount active'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          AppLocale.t(
            'Chạm thẻ để bật/tắt cảnh báo đỏ · Chạm mức độ để điều chỉnh',
            'Tap a card to toggle RED alerts · Tap severity pill to adjust',
          ),
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 600 ? 3 : 2;
            const spacing = 12.0;
            final cardWidth =
                (constraints.maxWidth - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: _allergens.map((item) {
                return SizedBox(
                  width: cardWidth,
                  child: _buildAllergenCard(item),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAllergenCard(AllergenChipItem item) {
    final bool active = item.isSelected;
    final src = item.sourceFoodName;
    final hasCustomSrc = active && src != null && src != item.displayName;

    return NutriVietPressScale(
      pressedScale: 0.97,
      enableHaptic: true,
      child: GestureDetector(
        onTap: () {
          setState(() {
            item.isSelected = !item.isSelected;
            if (!item.isSelected) {
              item.sourceFoodVi = null;
              item.sourceFoodEn = null;
            }
          });
          _autoSaveAllergens();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: active ? const Color(0xF5FFF1F2) : const Color(0xDCFFFFFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFDDE5DF),
              width: active ? 1.6 : 1.1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item.emoji, style: const TextStyle(fontSize: 26)),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active
                          ? const Color(0xFFDC2626)
                          : const Color(0xFFF1F5F9),
                      border: Border.all(
                        color: active
                            ? const Color(0xFFDC2626)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: active
                        ? const Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: active
                      ? const Color(0xFF991B1B)
                      : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              if (active)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _cycleSeverity(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: item.severityColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            hasCustomSrc
                                ? '${item.severityLabel} · $src'
                                : item.severityLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.sync_rounded,
                          size: 12,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Text(
                  item.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthConditionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocale.t('Tình trạng sức khỏe', 'Health Conditions'),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppLocale.t(
            'Tự động cảnh báo vàng với thành phần cần hạn chế theo bệnh lý',
            'Automatically flags ingredients to limit based on your health needs',
          ),
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 600 ? 4 : 2;
            const spacing = 12.0;
            final cardWidth =
                (constraints.maxWidth - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: _conditions.map((item) {
                final active = item.isActive;
                return SizedBox(
                  width: cardWidth,
                  child: NutriVietPressScale(
                    pressedScale: 0.97,
                    enableHaptic: true,
                    child: GestureDetector(
                      onTap: () => setState(() => item.isActive = !item.isActive),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xF5FFFBEB)
                              : const Color(0xDCFFFFFF),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: active
                                ? const Color(0xFFD97706)
                                : const Color(0xFFDDE5DF),
                            width: active ? 1.6 : 1.1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                PhosphorIcon(
                                  item.icon,
                                  size: 22,
                                  color: active
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFF64748B),
                                ),
                                Icon(
                                  active
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  size: 20,
                                  color: active
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFFCBD5E1),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? const Color(0xFF92400E)
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProtectionSwitchesCard() {
    return NutriVietGlassCard(
      cornerRadius: 22,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocale.t('Mức độ bảo vệ khi quét', 'Label Scan Sensitivity'),
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocale.t(
                        'Quét dẫn xuất gián tiếp',
                        'Detect hidden derivatives',
                      ),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocale.t(
                        'Nhận diện casein, whey, lecithin E322 từ sữa hoặc đậu nành',
                        'Flag casein, whey, and E322 lecithin as milk or soy derivatives',
                      ),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              LiquidGlassBatch.exclude(
                child: LiquidGlassSwitch(
                  value: _scanDerivatives,
                  activeColor: NutriVietGlass.brandGreen,
                  inactiveColor: const Color(0xFFD1D5DB),
                  onChanged: (val) => setState(() => _scanDerivatives = val),
                ),
              ),
            ],
          ),
          const Divider(color: Color(0x1E0F172A), height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocale.t(
                        'Cảnh báo dấu vết dây chuyền',
                        'Warn about trace statements',
                      ),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocale.t(
                        'Bắt các dòng "Có thể chứa vết đậu phộng, sữa..."',
                        'Detect "May contain traces of peanuts, milk..." notices',
                      ),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              LiquidGlassBatch.exclude(
                child: LiquidGlassSwitch(
                  value: _warnTraces,
                  activeColor: NutriVietGlass.brandGreen,
                  inactiveColor: const Color(0xFFD1D5DB),
                  onChanged: (val) => setState(() => _warnTraces = val),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedAllergens = _allergens.where((a) => a.isSelected).length;
    final selectedChronics = _conditions.where((c) => c.isActive).length;
    final topInset = MediaQuery.paddingOf(context).top;
    final screenW = MediaQuery.sizeOf(context).width;

    void handleBack() {
      final finalName =
          _displayName.isNotEmpty ? _displayName : widget.userName;
      if (widget.isInitialSetup) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(user: {
              'id': widget.userId,
              'full_name': finalName,
              'email': _currentEmail,
            }),
          ),
        );
      } else {
        Navigator.pop(context, {
          'updated': _allergensChanged || _nameEdited,
          'full_name': finalName,
          'email': _currentEmail,
        });
      }
    }

    return NutriVietGlassBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: NutriVietGlassScrollArea(
                child: _isLoading
                    ? SingleChildScrollView(
                        padding: EdgeInsets.only(top: topInset + 72),
                        child: const NutriVietAllergyProfileSkeleton(),
                      )
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          18,
                          topInset + 84,
                          18,
                          36,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xEEFDE8E8),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFFEF4444),
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
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Compact Health Shield Banner (no gender/height/weight/BMI)
                                _buildSummaryBanner(
                                  selectedAllergens,
                                  selectedChronics,
                                ),
                                const SizedBox(height: 22),

                                // Primary: FoodOn Smart Food Search
                                _buildFoodOnSearchSection(),
                                const SizedBox(height: 24),

                                // Primary: 8 Allergen Families Grid
                                _buildAllergenGridSection(selectedAllergens),
                                const SizedBox(height: 26),

                                // Health Conditions Grid
                                _buildHealthConditionsSection(),
                                const SizedBox(height: 22),

                                // Scan Sensitivity Switches
                                _buildProtectionSwitchesCard(),
                                const SizedBox(height: 26),

                                // Single clear bottom Save CTA
                                LiquidGlassBatch.exclude(
                                  child: NutriVietGlassActionButton(
                                    label: widget.isInitialSetup
                                        ? AppLocale.t(
                                            'Hoàn tất & Bắt đầu quét',
                                            'Finish & Start Scanning',
                                          )
                                        : AppLocale.t(
                                            'Lưu hồ sơ sức khỏe',
                                            'Save Health Profile',
                                          ),
                                    icon: PhosphorIconsBold.checkCircle,
                                    isLoading: _isSaving,
                                    width: double.infinity,
                                    height: 56,
                                    onPressed: _handleSave,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),

            // Soft top scroll edge
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LiquidGlassScrollEdge(
                edge: LiquidGlassEdge.top,
                height: topInset + 84,
                blur: 0,
                style: LiquidGlassScrollEdgeStyle.soft,
                curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
                color: const Color(0xDDEEF6F2),
              ),
            ),

            // Clean Floating Glass AppBar (no duplicate Save button)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LiquidGlassBatch.exclude(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Center(
                      child: LiquidGlassAppBar(
                        width: screenW - 28,
                        height: 58,
                        style: NutriVietGlass.appBar,
                        touch: NutriVietGlass.touchSubtle,
                        centerTitle: true,
                        leading: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: LiquidGlassTabBarAction(
                            icon: widget.isInitialSetup
                                ? PhosphorIconsBold.x
                                : PhosphorIconsBold.arrowLeft,
                            foregroundColor: const Color(0xFF1F2937),
                            size: 40,
                            style: NutriVietGlass.circleOrb,
                            touch: NutriVietGlass.touchPronounced,
                            onTap: handleBack,
                          ),
                        ),
                        title: Text(
                          AppLocale.t(
                            'Hồ Sơ Dị Ứng & Sức Khỏe',
                            'Allergy & Health Profile',
                          ),
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        actions: const [SizedBox(width: 44)],
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
