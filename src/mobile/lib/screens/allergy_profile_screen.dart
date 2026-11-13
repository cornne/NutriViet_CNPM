import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class AllergenChipItem {
  final String code;
  final String emoji;
  final String displayName;
  final String description;
  bool isSelected;
  String severity; // 'anaphylaxis' (Sốc phản vệ), 'high' (Nghiêm trọng), 'moderate' (Trung bình), 'mild' (Nhẹ)

  AllergenChipItem({
    required this.code,
    required this.emoji,
    required this.displayName,
    required this.description,
    this.isSelected = false,
    this.severity = 'high',
  });

  String get severityLabel {
    switch (severity) {
      case 'anaphylaxis':
        return 'Sốc phản vệ';
      case 'high':
        return 'Nghiêm trọng';
      case 'moderate':
        return 'Trung bình';
      case 'mild':
        return 'Nhẹ';
      default:
        return 'Nghiêm trọng';
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
  final String title;
  bool isActive;

  ChronicConditionItem({
    required this.id,
    required this.title,
    this.isActive = false,
  });
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

  // Editable Name & User Email
  late TextEditingController _nameController;
  String _currentEmail = '';

  // Physical & Nutrition Metrics (Standard Nutrition App)
  int _age = 22;
  String _gender = 'male';
  double _height = 170.0;
  double _weight = 65.0;
  String _activityLevel = 'moderate';

  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;

  // Sensitivity Toggles
  bool _scanDerivatives = true;
  bool _warnTraces = true;

  // Master Allergens Catalog matching prototype
  final List<AllergenChipItem> _allergens = [
    AllergenChipItem(
      code: 'peanuts',
      emoji: '🥜',
      displayName: 'Đậu phộng (Lạc)',
      description: 'Bơ đậu phộng, dầu phụng, bánh kẹo hạt, sốt satay',
      isSelected: true,
      severity: 'anaphylaxis',
    ),
    AllergenChipItem(
      code: 'seafood',
      emoji: '🦐',
      displayName: 'Hải sản / Giáp xác',
      description: 'Nước mắm cá tôm, chả cá, bột nêm chiết xuất hải sản',
      isSelected: true,
      severity: 'high',
    ),
    AllergenChipItem(
      code: 'milk',
      emoji: '🥛',
      displayName: 'Sữa bò (Casein/Whey)',
      description: 'Casein, đạm whey, bơ thực vật, phô mai, sữa chua',
      isSelected: true,
      severity: 'moderate',
    ),
    AllergenChipItem(
      code: 'gluten',
      emoji: '🌾',
      displayName: 'Gluten / Lúa mì',
      description: 'Bột mì, mì ăn liền, bánh mì, bia, mạch nha lúa mạch',
      isSelected: false,
      severity: 'high',
    ),
    AllergenChipItem(
      code: 'eggs',
      emoji: '🥚',
      displayName: 'Trứng gà',
      description: 'Lòng trắng trứng, mayonnaise, albumin, bánh nướng',
      isSelected: false,
      severity: 'moderate',
    ),
    AllergenChipItem(
      code: 'soy',
      emoji: '🌱',
      displayName: 'Đậu nành (Soy)',
      description: 'Xì dầu, đậu phụ, lecithin đậu nành (E322), dầu đậu nành',
      isSelected: false,
      severity: 'mild',
    ),
    AllergenChipItem(
      code: 'tree_nuts',
      emoji: '🌰',
      displayName: 'Hạt cây (Hạnh nhân, Óc chó)',
      description: 'Hạt dẻ cười, óc chó, sữa hạt dinh dưỡng, granola',
      isSelected: false,
      severity: 'high',
    ),
    AllergenChipItem(
      code: 'sesame',
      emoji: '🌿',
      displayName: 'Mè (Vừng)',
      description: 'Dầu mè, hạt mè rắc bánh, sốt tahini',
      isSelected: false,
      severity: 'moderate',
    ),
  ];

  // Chronic conditions matching prototype
  final List<ChronicConditionItem> _conditions = [
    ChronicConditionItem(id: 'gout', title: '🩸 Gút / Axit Uric cao', isActive: true),
    ChronicConditionItem(id: 'diabetes', title: '🍬 Tiểu đường Type 2', isActive: false),
    ChronicConditionItem(id: 'hypertension', title: '🫀 Tăng huyết áp (Giảm Natri)', isActive: false),
    ChronicConditionItem(id: 'cholesterol', title: '🥗 Giảm chất béo (Mỡ máu)', isActive: false),
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
    super.dispose();
  }

  double _calculateBmi() {
    final hM = _height / 100.0;
    if (hM <= 0) return 22.0;
    return double.parse((_weight / (hM * hM)).toStringAsFixed(1));
  }

  String _getBmiStatus(double bmi) {
    if (bmi < 18.5) return 'Thiếu cân (Gầy)';
    if (bmi < 23.0) return 'Cân đối (Chuẩn WHO/VN)';
    if (bmi < 25.0) return 'Tiền béo phì (Thừa cân)';
    return 'Béo phì';
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

    // Load allergens and metrics in parallel
    final results = await Future.wait([
      ProfileService.getAllergens(widget.userId),
      ProfileService.getMetrics(widget.userId),
    ]);

    if (!mounted) return;

    final res = results[0];
    final metricsRes = results[1];

    if (res['success'] == true) {
      final List saved = res['allergens'] ?? [];
      if (saved.isNotEmpty) {
        // Reset selections first
        for (var a in _allergens) {
          a.isSelected = false;
        }
        for (var savedItem in saved) {
          final code = savedItem['code'];
          final severity = savedItem['severity'] ?? 'high';
          for (var item in _allergens) {
            if (item.code == code) {
              item.isSelected = true;
              item.severity = severity;
            }
          }
        }
      }
    } else {
      _errorMessage = res['message'];
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
              'name': item.displayName,
              'severity': item.severity,
            })
        .toList();

    // Save both metrics and allergens
    final results = await Future.wait([
      ProfileService.saveAllergens(
        userId: widget.userId,
        allergens: selectedAllergens,
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
          content: Text('Đã lưu hồ sơ dinh dưỡng & ${selectedAllergens.length} nhóm dị ứng thành công!'),
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
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _allergens.where((a) => a.isSelected).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      widget.isInitialSetup ? Icons.close_rounded : Icons.arrow_back,
                      color: const Color(0xFF334155),
                      size: 22,
                    ),
                    tooltip: widget.isInitialSetup ? 'Bỏ qua & Vào trang chủ' : 'Quay lại',
                    onPressed: () {
                      if (widget.isInitialSetup) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HomeScreen(user: {
                              'id': widget.userId,
                              'full_name': _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : widget.userName,
                              'email': _currentEmail,
                            }),
                          ),
                        );
                      } else {
                        Navigator.pop(context, {
                          'updated': false,
                          'full_name': _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : widget.userName,
                          'email': _currentEmail,
                        });
                      }
                    },
                  ),
                  const Text(
                    'Hồ Sơ Sức Khỏe & Dị Ứng',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  TextButton(
                    onPressed: _isSaving ? null : _handleSave,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                          )
                        : const Text(
                            'Lưu',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF10B981),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Error Banner if any
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEF4444), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
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

                  // Profile Banner Card matching prototype
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE2E8F0),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text('👤', style: TextStyle(fontSize: 22)),
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
                                      '${_nameController.text.trim().isNotEmpty ? _nameController.text.trim() : widget.userName} ($_age tuổi)',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF10B981)),
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

                  // ================= SECTION: PERSONAL INFO & PHYSICAL METRICS =================
                  Container(
                    padding: const EdgeInsets.all(16),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.person_pin_rounded, color: Color(0xFF10B981), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Thông Tin Cá Nhân & Chỉ Số Thể Trạng',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Cung cấp họ tên và chỉ số thể chất để NutriViet cá nhân hóa dinh dưỡng phù hợp.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 14),

                        // Editable Full Name Input
                        const Text(
                          'Họ và tên người dùng (Có thể chỉnh sửa)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: 'Nhập họ và tên...',
                            prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF10B981), size: 20),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Real User Email
                        const Text(
                          'Email tài khoản',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
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
                              const Icon(Icons.mail_outline_rounded, color: Color(0xFF64748B), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _currentEmail.isNotEmpty ? _currentEmail : 'Chưa có thông tin email',
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                ),
                              ),
                              const Icon(Icons.lock_outline_rounded, color: Color(0xFF94A3B8), size: 16),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Row 1: Age & Gender
                        Row(
                          children: [
                            // Age Input
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tuổi',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _ageController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      hintText: '22',
                                      suffixText: 'tuổi',
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

                            // Gender Selector
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Giới tính',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
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
                                              color: _gender == 'male' ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
                                              border: Border.all(
                                                color: _gender == 'male' ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                                                width: 1.2,
                                              ),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              'Nam 👨',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: _gender == 'male' ? FontWeight.w700 : FontWeight.w500,
                                                color: _gender == 'male' ? const Color(0xFF065F46) : const Color(0xFF64748B),
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
                                              color: _gender == 'female' ? const Color(0xFFFCE7F3) : const Color(0xFFF1F5F9),
                                              border: Border.all(
                                                color: _gender == 'female' ? const Color(0xFFEC4899) : const Color(0xFFCBD5E1),
                                                width: 1.2,
                                              ),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              'Nữ 👩',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: _gender == 'female' ? FontWeight.w700 : FontWeight.w500,
                                                color: _gender == 'female' ? const Color(0xFF9D174D) : const Color(0xFF64748B),
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
                            // Height Input
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Chiều cao',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
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

                            // Weight Input
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Cân nặng',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
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

                        // Interactive BMI & Calorie Result Badge
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _getBmiColor(_calculateBmi()).withValues(alpha: 0.3)),
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
                                    const Text('BMI', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
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
                                      'Nhu cầu năng lượng ước tính: ~${_calculateTdee()} kcal/ngày',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
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

                  // Section 1: Severe Allergens
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '🚨 Dị Ứng Thực Phẩm Cần Tránh',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$selectedCount đã chọn',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Hệ thống sẽ gắn cờ CẢNH BÁO ĐỎ tức thì khi phát hiện các chất này hoặc dẫn xuất FoodOn.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                        ),
                        const SizedBox(height: 12),

                        // Chip Grid matching prototype
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _allergens.map((item) {
                            final bool active = item.isSelected;
                            return InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                setState(() {
                                  item.isSelected = !item.isSelected;
                                });
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
                                    Text(
                                      '${item.emoji} ${item.displayName}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: active ? const Color(0xFFDC2626) : const Color(0xFF334155),
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
                  ),
                  const SizedBox(height: 16),

                  // Section 2: Sensitivity Setup
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '⚖️ Mức Độ Nhạy Cảm & Dẫn Xuất',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Row 1: Indirect derivatives
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Quét dẫn xuất gián tiếp (FoodOn)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Tự động nhận diện Casein, Lecithin, đạm Whey là sữa/đậu nành',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _scanDerivatives,
                              activeTrackColor: const Color(0xFF10B981),
                              onChanged: (val) => setState(() => _scanDerivatives = val),
                            ),
                          ],
                        ),
                        const Divider(color: Color(0xFFE2E8F0), height: 20),

                        // Row 2: Warning traces
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Cảnh báo dấu vết / Dây chuyền sản xuất',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Nhận diện câu cảnh báo: "Có thể chứa vết đậu phộng..."',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _warnTraces,
                              activeTrackColor: const Color(0xFF10B981),
                              onChanged: (val) => setState(() => _warnTraces = val),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section 3: Chronic Conditions
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🩺 Bệnh Lý Mãn Tính & Tiết Chế',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _conditions.map((item) {
                            final active = item.isActive;
                            return InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                setState(() {
                                  item.isActive = !item.isActive;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: active ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                                  border: Border.all(
                                    color: active ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                                    width: active ? 1.5 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: active ? const Color(0xFFD97706) : const Color(0xFF334155),
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

                  // Bottom Button: "Xác Nhận & Bắt Đầu Quét Nhãn"
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
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                            )
                          : const Text(
                              'Xác Nhận & Bắt Đầu Quét Nhãn',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
