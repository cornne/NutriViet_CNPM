import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../l10n/app_locale.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../theme/nutriviet_glass.dart';
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
      case 'high':
        return const Color(0xFFEF4444);
      case 'moderate':
        return const Color(0xFFD97706);
      case 'mild':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFFEF4444);
    }
  }
}

class ChronicConditionItem {
  final String id;
  final String titleVi;
  final String titleEn;
  bool isActive;

  ChronicConditionItem({
    required this.id,
    required this.titleVi,
    required this.titleEn,
    this.isActive = false,
  });

  String get title => AppLocale.t(titleVi, titleEn);
}

class AllergyProfileScreen extends StatefulWidget {
  final int userId;
  final String userName;
  final String? userEmail;
  final bool isInitialSetup;

  const AllergyProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userEmail,
    this.isInitialSetup = false,
  });

  @override
  State<AllergyProfileScreen> createState() => _AllergyProfileScreenState();
}

class _AllergyProfileScreenState extends State<AllergyProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  late TextEditingController _nameController;
  String _currentEmail = '';

  int _age = 22;
  String _gender = 'male';
  double _height = 170.0;
  double _weight = 65.0;
  String _activityLevel = 'moderate';

  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _foodSearchController;

  bool _scanDerivatives = true;
  bool _warnTraces = true;
  bool _isSearchingFood = false;
  bool _allergensChanged = false;
  List<Map<String, dynamic>> _foodSearchResults = [];

  static const List<Map<String, String>> _quickEverydayFoods = [
    {'vi': 'Bơ', 'en': 'Butter', 'emoji': '🧈'},
    {'vi': 'Phô mai', 'en': 'Cheese', 'emoji': '🧀'},
    {'vi': 'Bánh mì', 'en': 'Bread', 'emoji': '🍞'},
    {'vi': 'Tôm', 'en': 'Shrimp', 'emoji': '🦐'},
    {'vi': 'Nước mắm', 'en': 'Fish sauce', 'emoji': '🐟'},
    {'vi': 'Sốt trứng gà', 'en': 'Mayonnaise', 'emoji': '🥚'},
    {'vi': 'Đậu phụ', 'en': 'Tofu', 'emoji': '🌱'},
    {'vi': 'Bơ đậu phộng', 'en': 'Peanut butter', 'emoji': '🥜'},
  ];

  final List<AllergenChipItem> _allergens = [
    AllergenChipItem(
      code: 'peanuts',
      emoji: '🥜',
      displayNameVi: 'Đậu phộng (Lạc)',
      displayNameEn: 'Peanuts',
      descriptionVi: 'Bơ đậu phộng, dầu lạc thô, kẹo lạc, bột đậu phộng',
      descriptionEn: 'Peanut butter, peanut oil, nut snacks, peanut flour',
      isSelected: false,
      severity: 'anaphylaxis',
    ),
    AllergenChipItem(
      code: 'seafood',
      emoji: '🦐',
      displayNameVi: 'Hải sản / Giáp xác & Cá',
      displayNameEn: 'Seafood / Crustaceans & Fish',
      descriptionVi: 'Tôm, cua, ghẹ, mực, cá, nước mắm cốt cá, bột nêm hải sản',
      descriptionEn: 'Shrimp, crab, squid, fish, fish sauce, seafood seasoning',
      isSelected: false,
      severity: 'high',
    ),
    AllergenChipItem(
      code: 'milk',
      emoji: '🥛',
      displayNameVi: 'Sữa bò & Chế phẩm sữa',
      displayNameEn: 'Cow\'s Milk & Dairy Products',
      descriptionVi: 'Sữa bột, sữa tươi, đạm váng sữa, đạm sữa bò, đường sữa, phô mai, kem sữa, sữa chua, bơ sữa',
      descriptionEn: 'Milk powder, fresh milk, dairy whey protein, casein, lactose, cheese, cream, yogurt, butter',
      isSelected: false,
      severity: 'high',
    ),
    AllergenChipItem(
      code: 'gluten',
      emoji: '🌾',
      displayNameVi: 'Lúa mì & Ngũ cốc đạm lúa mì',
      displayNameEn: 'Wheat & Gluten Grains',
      descriptionVi: 'Bột mì, đạm lúa mì, mì ăn liền, bánh mì, bánh quy, mạch nha đại mạch',
      descriptionEn: 'Wheat flour, wheat gluten, noodles, bread, cookies, barley malt',
      isSelected: false,
      severity: 'high',
    ),
    AllergenChipItem(
      code: 'eggs',
      emoji: '🥚',
      displayNameVi: 'Trứng & Chế phẩm trứng',
      displayNameEn: 'Eggs & Egg Products',
      descriptionVi: 'Lòng trắng trứng, lòng đỏ trứng, bột trứng, sốt trứng gà, hoạt chất từ trứng (E1105)',
      descriptionEn: 'Egg white, egg yolk, egg powder, mayonnaise, egg lysozyme (E1105)',
      isSelected: false,
      severity: 'high',
    ),
    AllergenChipItem(
      code: 'soy',
      emoji: '🌱',
      displayNameVi: 'Đậu nành (Đỗ tương)',
      displayNameEn: 'Soybeans',
      descriptionVi: 'Đậu phụ, nước tương, sữa đậu nành, chất nhũ hóa đậu nành (E322), đạm đậu nành',
      descriptionEn: 'Tofu, soy sauce, soy milk, soy lecithin (E322), soy protein',
      isSelected: false,
      severity: 'high',
    ),
    AllergenChipItem(
      code: 'tree_nuts',
      emoji: '🌰',
      displayNameVi: 'Hạt cây (Điều, Hạnh nhân, Óc chó)',
      displayNameEn: 'Tree Nuts (Cashew, Almond, Walnut)',
      descriptionVi: 'Hạt điều, hạnh nhân, hạt óc chó, hạt dẻ cười, hạt mắc ca, sữa hạt',
      descriptionEn: 'Cashews, almonds, walnuts, pistachios, macadamia nuts, nut milk',
      isSelected: false,
      severity: 'high',
    ),
    AllergenChipItem(
      code: 'sesame',
      emoji: '🌿',
      displayNameVi: 'Mè (Vừng)',
      displayNameEn: 'Sesame',
      descriptionVi: 'Hạt mè, dầu mè, bơ mè, bánh kẹo rắc mè',
      descriptionEn: 'Sesame seeds, sesame oil, tahini paste, sesame crackers',
      isSelected: false,
      severity: 'high',
    ),
  ];

  final List<ChronicConditionItem> _conditions = [
    ChronicConditionItem(
      id: 'gout',
      titleVi: '🩸 Bệnh Gút / Axit Uric cao',
      titleEn: '🩸 Gout / High Uric Acid',
      isActive: false,
    ),
    ChronicConditionItem(
      id: 'diabetes',
      titleVi: '🍬 Tiểu đường',
      titleEn: '🍬 Diabetes',
      isActive: false,
    ),
    ChronicConditionItem(
      id: 'hypertension',
      titleVi: '🫀 Tăng huyết áp (Giảm muối)',
      titleEn: '🫀 Hypertension (Low Sodium)',
      isActive: false,
    ),
    ChronicConditionItem(
      id: 'cholesterol',
      titleVi: '🥗 Mỡ máu / Giảm chất béo',
      titleEn: '🥗 High Cholesterol / Low Fat',
      isActive: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
    _nameController.addListener(() {
      setState(() {});
    });
    _currentEmail = widget.userEmail ?? '';
    _loadUserEmail();
    _ageController = TextEditingController(text: '$_age');
    _heightController = TextEditingController(text: '$_height');
    _weightController = TextEditingController(text: '$_weight');
    _foodSearchController = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadUserEmail() async {
    if (_currentEmail.isEmpty) {
      final session = await AuthService.getSession();
      if (session != null && mounted) {
        setState(() {
          _currentEmail = session['email'] ?? '';
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _foodSearchController.dispose();
    super.dispose();
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
    await ProfileService.saveAllergens(
      userId: widget.userId,
      allergens: selectedAllergens,
    );
  }

  Future<void> _selectEverydayAllergyFood(Map<String, dynamic> food) async {
    final alCode = (food['allergen_code'] ?? '').toString().trim();
    final foodVi = (food['food_name_vi'] ?? food['food_name'] ?? '').toString().trim();
    final foodEn = (food['food_name_en'] ?? food['food_name'] ?? '').toString().trim();
    final famVi = (food['family_name_vi'] ?? food['family_name'] ?? foodVi).toString().trim();
    final famEn = (food['family_name_en'] ?? food['family_name'] ?? foodEn).toString().trim();
    final relVi = (food['related_ingredients_vi'] ?? food['related_ingredients'] ?? '').toString().trim();
    final relEn = (food['related_ingredients_en'] ?? food['related_ingredients'] ?? '').toString().trim();
    final emoji = (food['emoji'] ?? '🍽️').toString();

    if (alCode.isEmpty) return;

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
        target.sourceFoodVi = foodVi;
        target.sourceFoodEn = foodEn;
      } else {
        _allergens.add(
          AllergenChipItem(
            code: alCode,
            emoji: emoji,
            displayNameVi: famVi.isNotEmpty ? famVi : foodVi,
            displayNameEn: famEn.isNotEmpty ? famEn : foodEn,
            descriptionVi: relVi.isNotEmpty ? relVi : foodVi,
            descriptionEn: relEn.isNotEmpty ? relEn : foodEn,
            sourceFoodVi: foodVi,
            sourceFoodEn: foodEn,
            isSelected: true,
            severity: 'high',
          ),
        );
      }
    });

    await _autoSaveAllergens();
    if (!mounted) return;
    final chosenFood = AppLocale.t(foodVi, foodEn);
    final famName = AppLocale.t(
      (food['family_name_vi'] ?? food['family_name'] ?? '').toString(),
      (food['family_name_en'] ?? food['family_name'] ?? '').toString(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocale.t(
            '🚨 Đã bật BÁO ĐỎ cho "$chosenFood" → Tự động cảnh báo toàn bộ nhóm "$famName" khi quét nhãn!',
            '🚨 Activated RED ALERT for "$chosenFood" → Automatically flags all "$famName" ingredients on labels!',
          ),
        ),
        backgroundColor: const Color(0xFFDC2626),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  double _calculateBmi() {
    final hM = _height / 100.0;
    if (hM <= 0) return 22.0;
    return double.parse((_weight / (hM * hM)).toStringAsFixed(1));
  }

  String _getBmiStatus(double bmi) {
    if (bmi < 18.5) return AppLocale.t('Thiếu cân (Gầy)', 'Underweight');
    if (bmi < 23.0) return AppLocale.t('Cân đối (Chuẩn khuyến nghị)', 'Healthy weight');
    if (bmi < 25.0) return AppLocale.t('Tiền béo phì (Thừa cân)', 'Overweight');
    return AppLocale.t('Béo phì', 'Obese');
  }

  Color _getBmiColor(double bmi) {
    if (bmi < 18.5) return const Color(0xFF3B82F6);
    if (bmi < 23.0) return const Color(0xFF10B981);
    if (bmi < 25.0) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  int _calculateTdee() {
    double bmr = _gender == 'female'
        ? (10 * _weight + 6.25 * _height - 5 * _age - 161)
        : (10 * _weight + 6.25 * _height - 5 * _age + 5);
    return (bmr * 1.55).round();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final results = await Future.wait([
      ProfileService.getAllergens(widget.userId),
      ProfileService.getMetrics(widget.userId),
      ProfileService.getChronics(widget.userId),
      ProfileService.getSettings(widget.userId),
    ]);

    if (!mounted) return;

    final res = results[0];
    final metricsRes = results[1];
    final chronicsRes = results[2];
    final settingsRes = results[3];

    if (res['success'] == true) {
      final List saved = res['allergens'] ?? [];
      for (var a in _allergens) {
        a.isSelected = false;
        a.sourceFoodVi = null;
        a.sourceFoodEn = null;
      }
      for (var savedItem in saved) {
        final code = (savedItem['code'] ?? '').toString();
        final severity = (savedItem['severity'] ?? 'high').toString();
        final rawName = (savedItem['name'] ?? '').toString().trim();
        final srcVi = (savedItem['source_food_vi'] ?? '').toString().trim();
        final srcEn = (savedItem['source_food_en'] ?? '').toString().trim();
        bool matched = false;
        for (var item in _allergens) {
          if (item.code == code) {
            item.isSelected = true;
            item.severity = severity;
            if (srcVi.isNotEmpty || srcEn.isNotEmpty) {
              item.sourceFoodVi = srcVi.isNotEmpty ? srcVi : rawName;
              item.sourceFoodEn = srcEn.isNotEmpty ? srcEn : rawName;
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
          final isRedMeat = code == 'curie:FOODON:00001006' ||
              code == 'curie:FOODON:00001134' ||
              code == 'curie:FOODON:00001038';
          final isPoultry = code == 'curie:FOODON:00001131' || code == 'curie:FOODON:00001040';
          final famVi = isRedMeat
              ? 'Thịt động vật có vú (Thịt đỏ: Bò, Heo, Cừu)'
              : (isPoultry
                  ? 'Thịt gia cầm (Gà, Vịt, Ngan, Ngỗng)'
                  : (srcVi.isNotEmpty ? srcVi : (rawName.isNotEmpty ? rawName : code)));
          final famEn = isRedMeat
              ? 'Mammalian Meat (Red Meat: Beef, Pork, Lamb)'
              : (isPoultry
                  ? 'Poultry Meat (Chicken, Duck, Turkey)'
                  : (srcEn.isNotEmpty ? srcEn : (rawName.isNotEmpty ? rawName : code)));
          final descVi = isRedMeat
              ? 'Thịt bò, thịt heo (thịt lợn), thịt cừu, thịt băm, xúc xích thịt, thịt hộp, giăm bông, mỡ heo'
              : (isPoultry
                  ? 'Thịt gà, ức gà, thịt vịt, gà tây, nước cốt gà, bột thịt gà, xúc xích gà'
                  : 'Các thành phần và dẫn xuất cùng họ trên cây phân loại FoodOn');
          final descEn = isRedMeat
              ? 'Beef, pork, lamb, ground meat, meat sausages, luncheon meat, ham, bacon, lard'
              : (isPoultry
                  ? 'Chicken meat, chicken breast, duck meat, turkey, chicken broth, chicken extract'
                  : 'Ingredients and derivatives in the same FoodOn ontology family');
          _allergens.add(
            AllergenChipItem(
              code: code,
              emoji: isRedMeat ? '🥩' : (isPoultry ? '🍗' : '🍽️'),
              displayNameVi: famVi,
              displayNameEn: famEn,
              descriptionVi: descVi,
              descriptionEn: descEn,
              sourceFoodVi: srcVi.isNotEmpty ? srcVi : rawName,
              sourceFoodEn: srcEn.isNotEmpty ? srcEn : rawName,
              isSelected: true,
              severity: severity,
            ),
          );
        }
      }
    } else {
      _errorMessage = res['message'];
    }

    if (chronicsRes['success'] == true) {
      final List savedChronics = chronicsRes['chronics'] ?? [];
      for (var c in _conditions) {
        c.isActive = false;
      }
      for (var savedCh in savedChronics) {
        final code = savedCh['code'];
        for (var c in _conditions) {
          if (c.id == code) {
            c.isActive = true;
          }
        }
      }
    }

    if (settingsRes['success'] == true && settingsRes['settings'] is Map) {
      final s = settingsRes['settings'] as Map;
      _scanDerivatives = s['scan_derivatives'] ?? true;
      _warnTraces = s['warn_traces'] ?? true;
    }

    if (metricsRes['success'] == true && metricsRes['metrics'] != null) {
      final m = metricsRes['metrics'];
      _age = m['age'] is int ? m['age'] : int.tryParse(m['age'].toString()) ?? 22;
      _gender = m['gender'] ?? 'male';
      _height = (m['height'] is num) ? (m['height'] as num).toDouble() : 170.0;
      _weight = (m['weight'] is num) ? (m['weight'] as num).toDouble() : 65.0;
      _activityLevel = m['activity_level'] ?? 'moderate';

      _ageController.text = '$_age';
      _heightController.text = _height.toStringAsFixed(_height.truncateToDouble() == _height ? 0 : 1);
      _weightController.text = _weight.toStringAsFixed(_weight.truncateToDouble() == _weight ? 0 : 1);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != widget.userName) {
      await AuthService.updateProfile(userId: widget.userId, fullName: newName);
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

    final results = await Future.wait([
      ProfileService.saveAllergens(
        userId: widget.userId,
        allergens: selectedAllergens,
      ),
      ProfileService.saveChronics(
        userId: widget.userId,
        chronics: selectedChronics,
      ),
      ProfileService.saveMetrics(
        userId: widget.userId,
        age: _age,
        gender: _gender,
        height: _height,
        weight: _weight,
        activityLevel: _activityLevel,
      ),
    ]);

    final res = results[0];

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocale.t(
              'Đã lưu hồ sơ dinh dưỡng & ${selectedAllergens.length} nhóm dị ứng thành công!',
              'Saved nutrition profile & ${selectedAllergens.length} allergy groups successfully!',
            ),
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      if (widget.isInitialSetup) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(user: {
              'id': widget.userId,
              'full_name': newName.isNotEmpty ? newName : widget.userName,
              'email': _currentEmail,
            }),
          ),
        );
      } else {
        Navigator.pop(context, {
          'updated': true,
          'full_name': newName.isNotEmpty ? newName : widget.userName,
          'email': _currentEmail,
        });
      }
    } else {
      setState(() => _errorMessage = res['message']);
    }
  }

  void _cycleSeverity(AllergenChipItem item) {
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

  Widget _buildAllergyAndFoodOnSection(int selectedCount) {
    final activeItems = _allergens.where((a) => a.isSelected).toList();
    return NutriVietGlassCard(
      cornerRadius: 22,
      padding: const EdgeInsets.all(14),
      color: const Color(0xD4FFFFFF),
      border: Border.all(color: const Color(0x99FCA5A5), width: 1.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  AppLocale.t(
                    '🚨 Dị Ứng Thực Phẩm & Suy Luận FoodOn',
                    '🚨 Food Allergies & FoodOn Inference',
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  AppLocale.t(
                    '$selectedCount đang bật BÁO ĐỎ',
                    '$selectedCount RED alerts active',
                  ),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Everyday FoodOn Allergy Search Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const PhosphorIcon(
                      PhosphorIconsFill.sparkle,
                      color: Color(0xFFD97706),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        AppLocale.t(
                          'Bạn ăn món gì bị dị ứng? (Tra cứu thông minh FoodOn)',
                          'Which food caused your allergy? (Smart FoodOn Lookup)',
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocale.t(
                    'Không cần biết mình dị ứng đạm sữa hay chất gì — Ví dụ ăn Bơ bị dị ứng, chỉ cần tìm "Bơ". Khi quét nhãn có Sữa bột, Đạm váng sữa, Phô mai... FoodOn sẽ tự động BÁO ĐỎ!',
                    'No need to know medical allergen names — e.g. if eating Butter caused a reaction, just search "Butter". Scanning any label with Milk powder, Whey, or Cheese will automatically trigger a RED ALERT!',
                  ),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF78350F),
                    height: 1.38,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _foodSearchController,
                  onChanged: _searchEverydayAllergyFood,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    prefixIcon: const Icon(
                      PhosphorIconsBold.magnifyingGlass,
                      size: 18,
                      color: Color(0xFFDC2626),
                    ),
                    suffixIcon: _foodSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              PhosphorIconsBold.xCircle,
                              size: 18,
                              color: Color(0xFF64748B),
                            ),
                            onPressed: () {
                              _foodSearchController.clear();
                              _searchEverydayAllergyFood('');
                            },
                          )
                        : null,
                    hintText: AppLocale.t(
                      'Tìm món bạn ăn bị dị ứng (VD: Bơ, Phô mai, Tôm, Bánh mì...)',
                      'Search food that caused allergy (e.g. Butter, Cheese, Shrimp...)',
                    ),
                    hintStyle: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFFCA5A5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFFCA5A5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocale.t(
                    'Chạm nhanh món ăn phổ biến:',
                    'Quick tap common trigger foods:',
                  ),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _quickEverydayFoods.map((qf) {
                    final label = AppLocale.t(qf['vi']!, qf['en']!);
                    final isCurrentQuery =
                        _foodSearchController.text.trim().toLowerCase() ==
                        label.toLowerCase();
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        _foodSearchController.text = label;
                        _searchEverydayAllergyFood(label);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isCurrentQuery
                              ? const Color(0xFFFEE2E2)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCurrentQuery
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFFCD34D),
                          ),
                        ),
                        child: Text(
                          '${qf['emoji']} $label',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isCurrentQuery
                                ? const Color(0xFFB91C1C)
                                : const Color(0xFF78350F),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                if (_isSearchingFood) ...[
                  const SizedBox(height: 10),
                  const NutriVietFoodSearchSkeleton(itemCount: 3),
                ] else if (_foodSearchResults.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ..._foodSearchResults.map((food) {
                    final alCode = (food['allergen_code'] ?? '').toString();
                    final curie = (food['curie'] ?? '').toString();
                    final emoji = (food['emoji'] ?? '🍽️').toString();
                    final foodName = AppLocale.t(
                      (food['food_name_vi'] ?? food['food_name'] ?? '').toString(),
                      (food['food_name_en'] ?? food['food_name'] ?? '').toString(),
                    );
                    final famName = AppLocale.t(
                      (food['family_name_vi'] ?? food['family_name'] ?? '').toString(),
                      (food['family_name_en'] ?? food['family_name'] ?? '').toString(),
                    );
                    final relIng = AppLocale.t(
                      (food['related_ingredients_vi'] ?? food['related_ingredients'] ?? '').toString(),
                      (food['related_ingredients_en'] ?? food['related_ingredients'] ?? '').toString(),
                    );
                    final isAlreadySelected = _allergens.any(
                      (a) => a.code == alCode && a.isSelected,
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _selectEverydayAllergyFood(food),
                        child: Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: isAlreadySelected
                                ? const Color(0xFFFEF2F2)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isAlreadySelected
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFCBD5E1),
                              width: isAlreadySelected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(emoji, style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          foodName,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          curie,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isAlreadySelected
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isAlreadySelected
                                          ? AppLocale.t('✓ Đã bật BÁO ĐỎ', '✓ RED Alert ON')
                                          : AppLocale.t('+ Chọn dị ứng này', '+ Select allergy'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: isAlreadySelected
                                            ? Colors.white
                                            : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      PhosphorIconsFill.gitBranch,
                                      size: 14,
                                      color: Color(0xFFDC2626),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        AppLocale.t(
                                          'Suy luận FoodOn → Nhóm: $famName',
                                          'FoodOn Inference → Family: $famName',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFB91C1C),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                AppLocale.t(
                                  '🚨 Tự động BÁO ĐỎ khi nhãn chứa: $relIng',
                                  '🚨 Auto RED ALERT when label contains: $relIng',
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                  height: 1.35,
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
            ),
          ),

          if (activeItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        PhosphorIconsFill.shieldWarning,
                        size: 16,
                        color: Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          AppLocale.t(
                            'Đang bảo vệ BÁO ĐỎ theo cây phân loại FoodOn:',
                            'Active FoodOn Ontology RED ALERT Protection:',
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...activeItems.map((a) {
                    final src = a.sourceFoodName;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        src != null && src != a.displayName
                            ? AppLocale.t(
                                '• Dị ứng "$src" → Liên kết nhóm ${a.displayName}: Tự động BÁO ĐỎ (${a.description})',
                                '• "$src" allergy → Linked to ${a.displayName}: Auto RED ALERT (${a.description})',
                              )
                            : AppLocale.t(
                                '• Nhóm ${a.displayName}: Tự động BÁO ĐỎ (${a.description})',
                                '• ${a.displayName}: Auto RED ALERT (${a.description})',
                              ),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB91C1C),
                          height: 1.35,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          Text(
            AppLocale.t(
              'Hoặc chọn trực tiếp theo 8 nhóm dị ứng chính của FoodOn:',
              'Or toggle directly from the 8 primary FoodOn allergen families:',
            ),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allergens.map((item) {
              final bool active = item.isSelected;
              final src = item.sourceFoodName;
              final chipTitle = (active && src != null && src != item.displayName)
                  ? '${item.emoji} ${item.displayName} (${AppLocale.t("Từ", "From")}: $src)'
                  : '${item.emoji} ${item.displayName}';
              return InkWell(
                borderRadius: BorderRadius.circular(20),
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
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                    border: Border.all(
                      color: active ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1),
                      width: active ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          chipTitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: active ? const Color(0xFFDC2626) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      if (active) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _cycleSeverity(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: item.severityColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.severityLabel,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _allergens.where((a) => a.isSelected).length;
    final topInset = MediaQuery.paddingOf(context).top;
    final screenW = MediaQuery.sizeOf(context).width;

    void handleBack() {
      if (widget.isInitialSetup) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(user: {
              'id': widget.userId,
              'full_name': _nameController.text.trim().isNotEmpty
                  ? _nameController.text.trim()
                  : widget.userName,
              'email': _currentEmail,
            }),
          ),
        );
      } else {
        Navigator.pop(context, {
          'updated': _allergensChanged,
          'full_name': _nameController.text.trim().isNotEmpty
              ? _nameController.text.trim()
              : widget.userName,
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
                        padding:
                            EdgeInsets.fromLTRB(16, topInset + 82, 16, 36),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xEEFDE8E8),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFFEF4444), width: 1),
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

                            // Profile Banner Card
                            NutriVietGlassCard(
                              cornerRadius: 22,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                      children: [
                        const NutriVietGlassIconTile(
                          icon: PhosphorIconsDuotone.userCircle,
                          color: Color(0xFF14803C),
                          size: 44,
                          isCircle: true,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      AppLocale.t(
                                        '${_nameController.text.trim().isNotEmpty ? _nameController.text.trim() : widget.userName} ($_age tuổi)',
                                        '${_nameController.text.trim().isNotEmpty ? _nameController.text.trim() : widget.userName} ($_age yrs)',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  const PhosphorIcon(
                                    PhosphorIconsDuotone.pencilSimple,
                                    size: 17,
                                    color: Color(0xFF14803C),
                                  ),
                                ],
                              ),
                              if (_currentEmail.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _currentEmail,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _getBmiColor(_calculateBmi()),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'BMI ${_calculateBmi().toStringAsFixed(1)} • ${_getBmiStatus(_calculateBmi())}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _getBmiColor(_calculateBmi()),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section 1: Smart FoodOn Everyday Allergy Search & Allergen Families
                  _buildAllergyAndFoodOnSection(selectedCount),
                  const SizedBox(height: 16),

                  // Personal Info & Physical Metrics
                  NutriVietGlassCard(
                    cornerRadius: 22,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const PhosphorIcon(
                              PhosphorIconsDuotone.identificationBadge,
                              color: Color(0xFF14803C),
                              size: 21,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                AppLocale.t(
                                  'Thông Tin Cá Nhân & Chỉ Số Thể Trạng',
                                  'Personal Info & Body Metrics',
                                ),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocale.t(
                            'Cung cấp họ tên và chỉ số thể chất để NutriViet cá nhân hóa dinh dưỡng phù hợp.',
                            'Provide your name and physical metrics so NutriViet can personalize nutrition guidance.',
                          ),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 14),

                        Text(
                          AppLocale.t(
                            'Họ và tên người dùng (Có thể chỉnh sửa)',
                            'Full name (Editable)',
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: AppLocale.t('Nhập họ và tên...', 'Enter full name...'),
                            prefixIcon: const PhosphorIcon(
                              PhosphorIconsDuotone.identificationBadge,
                              color: Color(0xFF14803C),
                              size: 20,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          AppLocale.t('Email tài khoản', 'Account Email'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const PhosphorIcon(
                                PhosphorIconsDuotone.envelope,
                                color: Color(0xFF64748B),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _currentEmail.isNotEmpty
                                      ? _currentEmail
                                      : AppLocale.t('Chưa có thông tin email', 'No email linked'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF334155),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const PhosphorIcon(
                                PhosphorIconsDuotone.lock,
                                color: Color(0xFF94A3B8),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Row 1: Age & Gender
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocale.t('Tuổi', 'Age'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _ageController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      hintText: '22',
                                      suffixText: AppLocale.t('tuổi', 'yrs'),
                                      suffixStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onChanged: (val) {
                                      final parsed = int.tryParse(val.trim());
                                      if (parsed != null && parsed > 0 && parsed < 120) {
                                        setState(() => _age = parsed);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocale.t('Giới tính', 'Gender'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => setState(() => _gender = 'male'),
                                          borderRadius: BorderRadius.circular(10),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            decoration: BoxDecoration(
                                              color: _gender == 'male'
                                                  ? const Color(0xFFD1FAE5)
                                                  : const Color(0xFFF1F5F9),
                                              border: Border.all(
                                                color: _gender == 'male'
                                                    ? const Color(0xFF10B981)
                                                    : const Color(0xFFCBD5E1),
                                                width: 1.2,
                                              ),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              AppLocale.t('Nam 👨', 'Male 👨'),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: _gender == 'male' ? FontWeight.w700 : FontWeight.w500,
                                                color: _gender == 'male'
                                                    ? const Color(0xFF065F46)
                                                    : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => setState(() => _gender = 'female'),
                                          borderRadius: BorderRadius.circular(10),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            decoration: BoxDecoration(
                                              color: _gender == 'female'
                                                  ? const Color(0xFFFCE7F3)
                                                  : const Color(0xFFF1F5F9),
                                              border: Border.all(
                                                color: _gender == 'female'
                                                    ? const Color(0xFFEC4899)
                                                    : const Color(0xFFCBD5E1),
                                                width: 1.2,
                                              ),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              AppLocale.t('Nữ 👩', 'Female 👩'),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: _gender == 'female' ? FontWeight.w700 : FontWeight.w500,
                                                color: _gender == 'female'
                                                    ? const Color(0xFF9D174D)
                                                    : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Row 2: Height & Weight
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocale.t('Chiều cao', 'Height'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _heightController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      hintText: '170',
                                      suffixText: 'cm',
                                      suffixStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onChanged: (val) {
                                      final parsed = double.tryParse(val.trim());
                                      if (parsed != null && parsed > 50 && parsed < 260) {
                                        setState(() => _height = parsed);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocale.t('Cân nặng', 'Weight'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _weightController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      hintText: '65',
                                      suffixText: 'kg',
                                      suffixStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onChanged: (val) {
                                      final parsed = double.tryParse(val.trim());
                                      if (parsed != null && parsed > 20 && parsed < 300) {
                                        setState(() => _weight = parsed);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // BMI & Calorie Result Badge
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getBmiColor(_calculateBmi()).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _getBmiColor(_calculateBmi()).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _calculateBmi().toStringAsFixed(1),
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: _getBmiColor(_calculateBmi()),
                                      ),
                                    ),
                                    const Text(
                                      'BMI',
                                      style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getBmiStatus(_calculateBmi()),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _getBmiColor(_calculateBmi()),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      AppLocale.t(
                                        'Nhu cầu năng lượng ước tính: ~${_calculateTdee()} kcal/ngày',
                                        'Estimated daily energy need: ~${_calculateTdee()} kcal/day',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF475569),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section 2: Sensitivity Setup
                  NutriVietGlassCard(
                    cornerRadius: 22,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocale.t(
                            '⚖️ Mức Độ Nhạy Cảm & Dẫn Xuất',
                            '⚖️ Sensitivity & Derivatives',
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocale.t(
                                      'Quét dẫn xuất gián tiếp',
                                      'Scan indirect derivatives',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppLocale.t(
                                      'Tự động nhận diện đạm sữa, chất nhũ hóa từ sữa hoặc đậu nành',
                                      'Automatically detect casein, lecithin, and whey as milk or soy derivatives',
                                    ),
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            LiquidGlassBatch.exclude(
                              child: LiquidGlassSwitch(
                                value: _scanDerivatives,
                                activeColor: NutriVietGlass.brandGreen,
                                inactiveColor: const Color(0xFFD1D5DB),
                                onChanged: (val) =>
                                    setState(() => _scanDerivatives = val),
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Color(0x220F172A), height: 22),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocale.t(
                                      'Cảnh báo dấu vết / Dây chuyền sản xuất',
                                      'Warn about traces / shared equipment',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppLocale.t(
                                      'Nhận diện câu cảnh báo: "Có thể chứa vết đậu phộng..."',
                                      'Detect precautionary statements like "May contain traces of peanuts..."',
                                    ),
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            LiquidGlassBatch.exclude(
                              child: LiquidGlassSwitch(
                                value: _warnTraces,
                                activeColor: NutriVietGlass.brandGreen,
                                inactiveColor: const Color(0xFFD1D5DB),
                                onChanged: (val) =>
                                    setState(() => _warnTraces = val),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section 3: Chronic Conditions
                  NutriVietGlassCard(
                    cornerRadius: 22,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocale.t(
                            '🩺 Bệnh Lý Mãn Tính & Tiết Chế',
                            '🩺 Chronic Conditions & Dietary Limits',
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _conditions.map((item) {
                            final active = item.isActive;
                            return NutriVietPressScale(
                              pressedScale: 0.94,
                              enableHaptic: true,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    item.isActive = !item.isActive;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? const Color(0xEEFEF3C7)
                                        : Colors.white.withValues(alpha: 0.72),
                                    border: Border.all(
                                      color: active
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFFCBD5E1),
                                      width: active ? 1.5 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    item.title,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: active
                                          ? const Color(0xFFD97706)
                                          : const Color(0xFF334155),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bottom Liquid Glass Save CTA
                  LiquidGlassBatch.exclude(
                    child: NutriVietGlassActionButton(
                      label: AppLocale.t(
                        'Xác Nhận & Bắt Đầu Quét Nhãn',
                        'Confirm & Start Scanning Labels',
                      ),
                      icon: PhosphorIconsBold.checkCircle,
                      isLoading: _isSaving,
                      width: double.infinity,
                      height: 52,
                      onPressed: _handleSave,
                    ),
                  ),
                  const SizedBox(height: 20),
                        ],
                      ),
                    ),
            ),
          ),

          // Soft feathered scroll edge under floating glass AppBar
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

          // Floating Liquid Glass App Bar
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
                          'Hồ Sơ Dị Ứng',
                          'Allergy Profile',
                        ),
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      actions: [
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: LiquidGlassButton(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            style: NutriVietGlass.emeraldButton,
                            touch: NutriVietGlass.touchPronounced,
                            foregroundColor: Colors.white,
                            onPressed: _isSaving ? null : _handleSave,
                            child: _isSaving
                                ? NutriVietShimmerBox(
                                    width: 34,
                                    height: 11,
                                    borderRadius: 6,
                                    baseColor:
                                        Colors.white.withValues(alpha: 0.3),
                                    highlightColor: Colors.white,
                                  )
                                : Text(
                                    AppLocale.t('Lưu', 'Save'),
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
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
        ],
      ),
    ),
    );
  }
}
