import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../l10n/app_locale.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../theme/nutriviet_glass.dart';
import '../widgets/nutriviet_shimmer.dart';
import '../widgets/nutriviet_ui.dart';
import 'allergy_profile_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? user;

  const HomeScreen({super.key, this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _brandGreen = Color(0xFF14803C);
  static const Color _riskHighRed = Color(0xFFDC2626);

  final ValueNotifier<int> _tabNotifier = ValueNotifier<int>(0); // 0: Home, 1: Additives, 2: History, 3: Settings

  int _userId = 0;
  String _userName = '';
  String _userEmail = '';
  String _langPref = AppLocale.code;

  // Real data from Backend SQLite DB & FoodOn Hybrid Engine
  List<Map<String, dynamic>> _allergens = [];
  List<Map<String, dynamic>> _familyMembers = [];
  String _selectedMemberName = '';

  List<Map<String, dynamic>> _scans = [];
  int _monthlyScans = 0;
  int _monthlyWarnings = 0;
  int _totalScans = 0;
  int _warningScans = 0;
  bool _loadingInitialData = true;
  final Set<int> _expandedScanIds = {};

  // Tab 1: Additives (Live from nutriviet_hybrid.db)
  final TextEditingController _additiveSearchCtrl = TextEditingController();
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _additiveItems = [];
  bool _loadingAdditives = false;
  String? _additiveError;

  // Home category filter ('sugar', 'salt', 'fat', 'allergen')
  String _selectedCategory = 'sugar';
  List<Map<String, dynamic>> _categoryItems = [];
  bool _loadingCategory = false;

  late final VoidCallback _localeListener;

  @override
  void initState() {
    super.initState();
    _localeListener = () {
      if (!mounted) return;
      final newLang = AppLocale.code;
      if (_langPref != newLang) {
        setState(() {
          _langPref = newLang;
        });
        _loadAdditives(_additiveSearchCtrl.text);
        _loadCategoryConcepts(_selectedCategory);
      } else {
        setState(() {});
      }
    };
    AppLocale.current.addListener(_localeListener);
    _initSessionAndData();
  }

  @override
  void dispose() {
    AppLocale.current.removeListener(_localeListener);
    _searchDebounce?.cancel();
    _additiveSearchCtrl.dispose();
    _tabNotifier.dispose();
    super.dispose();
  }

  String get _shortName {
    if (_selectedMemberName.isNotEmpty) {
      return AppLocale.translateMemberName(_selectedMemberName);
    }
    final trimmed = _userName.trim();
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

  Future<void> _initSessionAndData() async {
    final session = await AuthService.getSession();
    final uid = widget.user?['id'] ?? session?['id'] ?? 0;
    final parsedUid = uid is int ? uid : (int.tryParse(uid.toString()) ?? 0);
    final name = (widget.user?['full_name'] ?? session?['full_name'] ?? '').toString();
    final email = (widget.user?['email'] ?? session?['email'] ?? '').toString();

    if (!mounted) return;
    setState(() {
      _userId = parsedUid;
      _userName = name;
      _userEmail = email;
      _langPref = AppLocale.code;
    });

    await Future.wait([
      _refreshUserData(),
      _loadAdditives(''),
    ]);
    if (mounted && _loadingInitialData) {
      setState(() => _loadingInitialData = false);
    }
  }

  Future<void> _refreshUserData() async {
    if (_userId <= 0) {
      if (mounted && _loadingInitialData) {
        setState(() => _loadingInitialData = false);
      }
      return;
    }
    final results = await Future.wait([
      ProfileService.getAllergens(_userId),
      ProfileService.getChronics(_userId),
      ProfileService.getFamilyMembers(_userId),
      ProfileService.getScans(_userId),
      ProfileService.getSettings(_userId),
    ]);
    if (!mounted) return;

    String? backendLang;
    if (results[4]['success'] == true && results[4]['settings'] is Map) {
      final s = results[4]['settings'] as Map;
      final l = (s['language'] ?? '').toString();
      if (l == 'vi' || l == 'en') {
        backendLang = l;
      }
    }
    if (backendLang != null && backendLang != AppLocale.code) {
      await AppLocale.setLanguage(backendLang);
    }

    if (!mounted) return;
    setState(() {
      _loadingInitialData = false;
      _langPref = AppLocale.code;
      if (results[0]['success'] == true) {
        _allergens = List<Map<String, dynamic>>.from(results[0]['allergens'] ?? []);
      }
      if (results[2]['success'] == true) {
        _familyMembers = List<Map<String, dynamic>>.from(results[2]['members'] ?? []);
        if (_familyMembers.isNotEmpty && _selectedMemberName.isEmpty) {
          _selectedMemberName = (_familyMembers.first['member_name'] ?? '').toString();
        }
      }
      if (results[3]['success'] == true) {
        _scans = List<Map<String, dynamic>>.from(results[3]['scans'] ?? []);
        _totalScans = (results[3]['total_scans'] ?? _scans.length) as int;
        _warningScans = (results[3]['warning_scans'] ?? 0) as int;
        _monthlyScans = (results[3]['monthly_scans'] ?? 0) as int;
        _monthlyWarnings = (results[3]['monthly_warnings'] ?? 0) as int;
        for (final sc in _scans) {
          final ev = sc['evaluation'];
          if (ev is Map) {
            final reds = ev['red_triggers'];
            if (reds is List && reds.isNotEmpty) {
              final sid = sc['id'];
              if (sid is int) {
                _expandedScanIds.add(sid);
              }
            }
          }
        }
        if (_expandedScanIds.isEmpty && _scans.isNotEmpty) {
          final firstId = _scans.first['id'];
          if (firstId is int) {
            _expandedScanIds.add(firstId);
          }
        }
      }
    });

    await Future.wait([
      _loadCategoryConcepts(_selectedCategory),
      _loadAdditives(_additiveSearchCtrl.text),
    ]);
  }

  Future<void> _loadAdditives(String query) async {
    if (!mounted) return;
    setState(() {
      _loadingAdditives = true;
      _additiveError = null;
    });

    final res = await ProfileService.getAdditives(
      query: query,
      lang: AppLocale.code,
      limit: 60,
    );

    if (!mounted) return;
    setState(() {
      _loadingAdditives = false;
      if (res['success'] == true) {
        _additiveItems = List<Map<String, dynamic>>.from(res['items'] ?? []);
      } else {
        _additiveError = res['message']?.toString();
      }
    });
  }

  Future<void> _loadCategoryConcepts(String category) async {
    if (!mounted) return;
    setState(() {
      _selectedCategory = category;
      _loadingCategory = true;
    });

    final alCodes = _allergens
        .map((a) => (a['code'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();
    final res = await ProfileService.getCategoryConcepts(
      category: category,
      allergens: alCodes,
      lang: AppLocale.code,
      limit: 12,
    );

    if (!mounted) return;
    setState(() {
      _loadingCategory = false;
      if (res['success'] == true) {
        _categoryItems = List<Map<String, dynamic>>.from(res['items'] ?? []);
      }
    });
  }

  Future<void> _openAllergyProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AllergyProfileScreen(
          userId: _userId,
          userName: _userName,
          userEmail: _userEmail,
        ),
      ),
    );
    if (result != null && result is Map) {
      final updatedName = result['full_name'] ?? result['name'];
      if (updatedName != null && updatedName.toString().isNotEmpty) {
        setState(() => _userName = updatedName.toString());
      }
    }
    await _refreshUserData();
  }

  Future<void> _openAddFamilyMemberDialog() async {
    final nameCtrl = TextEditingController();
    final relCtrl = TextEditingController(
      text: AppLocale.t('Người thân', 'Family'),
    );

    await showLiquidGlassDialog(
      context: context,
      builder: (ctx) {
        return LiquidGlassAlertDialog(
          style: NutriVietGlass.lightSheet,
          title: Text(
            AppLocale.t('Thêm hồ sơ gia đình', 'Add Family Profile'),
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
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Color(0xFF111827)),
                  decoration: InputDecoration(
                    labelText: AppLocale.t(
                      'Tên thành viên (VD: Mẹ, Bé An)',
                      'Member name (e.g., Mom, Leo)',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: relCtrl,
                  style: const TextStyle(color: Color(0xFF111827)),
                  decoration: InputDecoration(
                    labelText: AppLocale.t('Mối quan hệ', 'Relationship'),
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
              label: AppLocale.t('Lưu hồ sơ', 'Save profile'),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final res = await ProfileService.addFamilyMember(
                  userId: _userId,
                  memberName: name,
                  relationship: relCtrl.text.trim(),
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (res['success'] == true) {
                  setState(() {
                    _familyMembers = List<Map<String, dynamic>>.from(res['members'] ?? []);
                    _selectedMemberName = name;
                  });
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        res['message'] ??
                            AppLocale.t(
                              'Không thể thêm hồ sơ.',
                              'Unable to add profile.',
                            ),
                      ),
                      backgroundColor: _riskHighRed,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Screen 3: Full-Screen Camera / Packaging Label Scanner
  // ---------------------------------------------------------------------------
  Future<void> _openScannerScreen() async {
    HapticFeedback.lightImpact();
    final scanRes = await Navigator.push<Map<String, dynamic>>(
      context,
      PageRouteBuilder(
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, __, ___) => _PackagingScannerScreen(
          userId: _userId,
          memberName: _shortName,
        ),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );

    if (scanRes != null && scanRes['success'] == true) {
      await _refreshUserData();
      if (!mounted) return;
      final latest = scanRes['latest_scan'];
      if (latest is Map<String, dynamic>) {
        _tabNotifier.value = 2;
        if (latest['id'] is int) {
          setState(() {
            _expandedScanIds.add(latest['id'] as int);
          });
        }
      }
    }
  }

  Widget _buildRiskPill(String riskLevel, {String? customLabel}) {
    return NutriVietRiskPill(riskLevel: riskLevel, customLabel: customLabel);
  }

  // ---------------------------------------------------------------------------
  // Concept Detail Bottom Sheet (Strictly Monolingual: 100% VI or 100% EN)
  // ---------------------------------------------------------------------------
  void _showConceptDetailSheet(Map<String, dynamic> item) {
    final code = (item['code'] ?? item['curie'] ?? '').toString();
    final curie = (item['curie'] ?? '').toString();
    final title = AppLocale.isEn
        ? (item['title_en'] ?? item['title'] ?? item['label_en'] ?? '').toString()
        : (item['title_vi'] ?? item['title'] ?? item['label_vi'] ?? '').toString();
    final desc = AppLocale.isEn
        ? (item['description_en'] ?? item['description'] ?? '').toString()
        : (item['description_vi'] ?? item['description'] ?? '').toString();
    final riskLevel = (item['risk_level'] ?? 'low').toString();
    final lineageNodes = List<Map<String, dynamic>>.from(item['lineage_nodes'] ?? []);
    final viTerms = List<String>.from(item['terms_vi'] ?? []);
    final enTerms = List<String>.from(item['terms_en'] ?? []);
    final ecodes = List<String>.from(item['ecodes'] ?? []);

    showLiquidGlassSheet(
      context: context,
      isScrollControlled: true,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5EDE7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  _buildRiskPill(riskLevel),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 14.5,
                  color: Color(0xFF4B5563),
                  height: 1.45,
                ),
              ),
              if (ecodes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  AppLocale.t(
                    'Mã phụ gia quốc tế: ${ecodes.join(", ")}',
                    'International additive code: ${ecodes.join(", ")}',
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _brandGreen,
                  ),
                ),
              ],
              if (AppLocale.isVi && viTerms.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Tên gọi tương đương: ${viTerms.join(", ")}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                ),
              ],
              if (AppLocale.isEn && enTerms.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Synonyms: ${enTerms.join(", ")}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                ),
              ],
              if (lineageNodes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  AppLocale.t(
                    'Phân cấp nhóm chất thực phẩm:',
                    'Food Classification Hierarchy:',
                  ),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: lineageNodes.map((n) {
                    final lbl = AppLocale.isEn
                        ? (n['display_label_en'] ?? n['label_en'] ?? '').toString()
                        : (n['display_label_vi'] ?? n['label_vi'] ?? '').toString();
                    if (lbl.isEmpty) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        lbl,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  AppLocale.t('Mã định danh: $curie', 'Identifier: $curie'),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 0: Trang chủ / Home
  // ---------------------------------------------------------------------------
  Widget _buildHomeTab() {
    final members = _familyMembers.isNotEmpty
        ? _familyMembers
        : [
            {'id': 0, 'member_name': _shortName, 'is_primary': 1}
          ];

    final badgeFirstScan = _totalScans >= 1;
    final badgeFirstWarning = _warningScans >= 1;
    final badgeTenScans = _totalScans >= 10;
    final tenProgress = (_totalScans.clamp(0, 10)) / 10.0;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: _brandGreen,
        onRefresh: _refreshUserData,
        child: NutriVietGlassScrollArea(
          child: ListView(
            scrollCacheExtent: const ScrollCacheExtent.pixels(800),
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
            // Top-right Liquid Glass support/info orb
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  showLiquidGlassDialog(
                    context: context,
                    builder: (ctx) => LiquidGlassAlertDialog(
                      style: NutriVietGlass.lightSheet,
                      title: Text(
                        AppLocale.t('Hỗ trợ & Thông tin', 'Support & Information'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      content: Text(
                        AppLocale.t(
                          'Hệ thống tra cứu nhãn thực phẩm kết nối trực tiếp cơ sở dữ liệu dinh dưỡng (25.577 thành phần và 742 mã phụ gia thực phẩm).',
                          'Live food label analysis powered by the nutrition ontology database (25,577 food concepts and 742 additive E-codes).',
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: Color(0xFF374151),
                        ),
                      ),
                      actions: [
                        LiquidGlassButton(
                          height: 42,
                          style: NutriVietGlass.emeraldButton,
                          foregroundColor: Colors.white,
                          label: AppLocale.t('Đóng', 'Close'),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  );
                },
                child: const NutriVietPressScale(
                  pressedScale: 0.92,
                  enableHaptic: true,
                  child: LiquidGlassBatch.exclude(
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: LiquidGlassLens(
                        style: NutriVietGlass.circleOrb,
                        touch: LiquidGlassTouch.flexing(LiquidGlassFlex.subtle()),
                        child: Center(
                          child: PhosphorIcon(
                            PhosphorIconsDuotone.chatsCircle,
                            color: _brandGreen,
                            size: 22,
                            duotoneSecondaryOpacity: 0.28,
                            duotoneSecondaryColor: _brandGreen,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Text(
              AppLocale.t('Trang chủ', 'Home'),
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 14),

            // Main Hero Emerald Glass Card (crisp luminous rim + isolated
            // RepaintBoundary so 120Hz scrolling runs zero shaders/blend barriers)
            RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xF01C944A),
                      Color(0xEE147D3B),
                      Color(0xF20D5E2C),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.36),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0E632E).withValues(alpha: 0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: Stack(
                  children: [
                    const NutriVietHeroSheen(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppLocale.t('THÁNG NÀY', 'THIS MONTH'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              NutriVietPressScale(
                                pressedScale: 0.90,
                                child: GestureDetector(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          AppLocale.t(
                                            'Thống kê số nhãn thực phẩm đã quét và số cảnh báo phát hiện trong tháng hiện tại.',
                                            'Summary of food labels scanned and warnings detected in the current month.',
                                          ),
                                        ),
                                        backgroundColor: _brandGreen,
                                      ),
                                    );
                                  },
                                  child: const PhosphorIcon(
                                    PhosphorIconsDuotone.info,
                                    color: Colors.white,
                                    size: 22,
                                    duotoneSecondaryOpacity: 0.28,
                                    duotoneSecondaryColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (_loadingInitialData && _scans.isEmpty)
                            NutriVietShimmerGroup(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  NutriVietShimmerBox(
                                    width: 72,
                                    height: 46,
                                    borderRadius: 14,
                                    baseColor:
                                        Colors.white.withValues(alpha: 0.24),
                                    highlightColor: Colors.white,
                                  ),
                                  const SizedBox(height: 12),
                                  NutriVietShimmerBox(
                                    width: 230,
                                    height: 14,
                                    borderRadius: 7,
                                    baseColor:
                                        Colors.white.withValues(alpha: 0.22),
                                    highlightColor: Colors.white,
                                  ),
                                  const SizedBox(height: 7),
                                  NutriVietShimmerBox(
                                    width: 150,
                                    height: 12,
                                    borderRadius: 6,
                                    baseColor:
                                        Colors.white.withValues(alpha: 0.18),
                                    highlightColor: Colors.white,
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                  begin: 0, end: _monthlyScans.toDouble()),
                              duration: const Duration(milliseconds: 620),
                              curve: Curves.easeOutCubic,
                              builder: (context, val, _) {
                                return Text(
                                  '${val.round()}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 56,
                                    fontWeight: FontWeight.w800,
                                    height: 1.05,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppLocale.t(
                                'Đã đọc $_monthlyScans nhãn · Phát hiện $_monthlyWarnings cảnh báo',
                                'Read $_monthlyScans labels · Detected $_monthlyWarnings warnings',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppLocale.t(
                                'Còn 1 lần quét miễn phí',
                                '1 free scan remaining',
                              ),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),

                          // HỒ SƠ GIA ĐÌNH / FAMILY PROFILES Header Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppLocale.t('HỒ SƠ GIA ĐÌNH', 'FAMILY PROFILES'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              NutriVietPressScale(
                                pressedScale: 0.95,
                                child: GestureDetector(
                                  onTap: _openAllergyProfile,
                                  child: Row(
                                    children: [
                                      Text(
                                        AppLocale.t(
                                            'Quản lý hồ sơ', 'Manage profiles'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const PhosphorIcon(
                                        PhosphorIconsBold.caretRight,
                                        color: Colors.white,
                                        size: 15,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Family Member Glass Avatars Row
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ...members.map((m) {
                                  final rawName =
                                      (m['member_name'] ?? _shortName)
                                          .toString();
                                  final mName =
                                      AppLocale.translateMemberName(rawName);
                                  final isSelected =
                                      rawName == _selectedMemberName ||
                                          (_selectedMemberName.isEmpty &&
                                              m == members.first);
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 22),
                                    child: NutriVietPressScale(
                                      pressedScale: 0.93,
                                      enableHaptic: true,
                                      child: GestureDetector(
                                        onTap: () => setState(
                                            () => _selectedMemberName = rawName),
                                        child: Column(
                                          children: [
                                            AnimatedScale(
                                              scale: isSelected ? 1.06 : 0.96,
                                              duration: const Duration(
                                                  milliseconds: 220),
                                              curve: Curves.easeOutBack,
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                    milliseconds: 220),
                                                curve: Curves.easeOutCubic,
                                                width: 54,
                                                height: 54,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: isSelected
                                                        ? [
                                                            Colors.white
                                                                .withValues(
                                                                    alpha: 0.34),
                                                            const Color(
                                                                    0xFF86EFAC)
                                                                .withValues(
                                                                    alpha: 0.22),
                                                          ]
                                                        : [
                                                            Colors.white
                                                                .withValues(
                                                                    alpha: 0.18),
                                                            Colors.white
                                                                .withValues(
                                                                    alpha: 0.08),
                                                          ],
                                                  ),
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? Colors.white
                                                        : Colors.white
                                                            .withValues(
                                                                alpha: 0.45),
                                                    width:
                                                        isSelected ? 2.4 : 1.3,
                                                  ),
                                                  boxShadow: isSelected
                                                      ? [
                                                          BoxShadow(
                                                            color: Colors.white
                                                                .withValues(
                                                                    alpha:
                                                                        0.26),
                                                            blurRadius: 12,
                                                            spreadRadius: 1,
                                                          ),
                                                        ]
                                                      : null,
                                                ),
                                                child: Center(
                                                  child: PhosphorIcon(
                                                    PhosphorIconsDuotone.user,
                                                    color: Colors.white,
                                                    size: 27,
                                                    duotoneSecondaryOpacity:
                                                        isSelected
                                                            ? 0.38
                                                            : 0.24,
                                                    duotoneSecondaryColor:
                                                        Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              mName,
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                    alpha:
                                                        isSelected ? 1.0 : 0.85),
                                                fontSize: 13.5,
                                                fontWeight: isSelected
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),

                                // Dashed "+ Thêm / Add" button
                                NutriVietPressScale(
                                  pressedScale: 0.93,
                                  enableHaptic: true,
                                  child: GestureDetector(
                                    onTap: _openAddFamilyMemberDialog,
                                    child: Column(
                                      children: [
                                        RepaintBoundary(
                                          child: CustomPaint(
                                            painter: _DashedCirclePainter(
                                                color: Colors.white
                                                    .withValues(alpha: 0.85)),
                                            child: const SizedBox(
                                              width: 54,
                                              height: 54,
                                              child: Center(
                                                child: PhosphorIcon(
                                                  PhosphorIconsBold.plus,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          AppLocale.t('Thêm', 'Add'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Bottom Liquid Glass Pill Button "[ ] Quét nhãn / Scan label"
                          NutriVietPressScale(
                            pressedScale: 0.965,
                            enableHaptic: true,
                            child: GestureDetector(
                              onTap: _openScannerScreen,
                              child: Container(
                                width: double.infinity,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFCFFFFFF),
                                      Color(0xECF4FBF6),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF064E3B)
                                          .withValues(alpha: 0.14),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const PhosphorIcon(
                                        PhosphorIconsDuotone.scan,
                                        color: _brandGreen,
                                        size: 22,
                                        duotoneSecondaryOpacity: 0.25,
                                        duotoneSecondaryColor: _brandGreen,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        AppLocale.t('Quét nhãn', 'Scan label'),
                                        style: const TextStyle(
                                          color: _brandGreen,
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w700,
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
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 26),

            // Section: Huy hiệu / Badges
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocale.t('Huy hiệu', 'Badges'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                GestureDetector(
                  onTap: () => _tabNotifier.value = 2,
                  child: Text(
                    AppLocale.t('Xem tất cả', 'See all'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _brandGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            NutriVietGlassCard(
              cornerRadius: 22,
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildBadgeColumn(
                      icon: PhosphorIconsDuotone.sparkle,
                      unlocked: badgeFirstScan,
                      title: AppLocale.t(
                        'Đọc nhãn đầu\ntiên của bạn',
                        'Read your\nfirst label',
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildBadgeColumn(
                      icon: PhosphorIconsDuotone.shieldWarning,
                      unlocked: badgeFirstWarning,
                      title: AppLocale.t(
                        'Phát hiện cảnh\nbáo đầu tiên',
                        'Detect your\nfirst warning',
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildBadgeColumn(
                      icon: PhosphorIconsDuotone.trophy,
                      unlocked: badgeTenScans,
                      title: AppLocale.t('Đọc 10 nhãn', 'Read 10 labels'),
                      progress: tenProgress,
                      progressText: AppLocale.t(
                        '${_totalScans.clamp(0, 10)}/10 nhãn',
                        '${_totalScans.clamp(0, 10)}/10 labels',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Category Pills Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryPill(
                    id: 'sugar',
                    icon: PhosphorIconsDuotone.cube,
                    label: AppLocale.t('Đường', 'Sugar'),
                  ),
                  const SizedBox(width: 10),
                  _buildCategoryPill(
                    id: 'salt',
                    icon: PhosphorIconsDuotone.grains,
                    label: AppLocale.t('Muối', 'Salt'),
                  ),
                  const SizedBox(width: 10),
                  _buildCategoryPill(
                    id: 'fat',
                    icon: PhosphorIconsDuotone.drop,
                    label: AppLocale.t('Chất béo', 'Fat'),
                  ),
                  const SizedBox(width: 10),
                  _buildCategoryPill(
                    id: 'allergen',
                    icon: PhosphorIconsDuotone.shieldWarning,
                    label: AppLocale.t('Dị ứng', 'Allergens'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Active Category Knowledge Section (items are emitted as direct
            // ListView children so Viewport culls offscreen cards at 120Hz)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: Align(
                key: ValueKey('cat_title_${_selectedCategory}_${AppLocale.code}'),
                alignment: Alignment.centerLeft,
                child: Text(
                  _selectedCategory == 'sugar'
                      ? AppLocale.t('Đường', 'Sugar')
                      : (_selectedCategory == 'salt'
                          ? AppLocale.t('Muối', 'Salt')
                          : (_selectedCategory == 'fat'
                              ? AppLocale.t('Chất béo', 'Fat')
                              : AppLocale.t('Dị ứng', 'Allergens'))),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
                  if (_selectedCategory == 'allergen') ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: NutriVietGlassCard(
                        cornerRadius: 20,
                        padding: const EdgeInsets.all(14),
                        onTap: _openAllergyProfile,
                        child: Row(
                          children: [
                            const NutriVietGlassIconTile(
                              icon: PhosphorIconsDuotone.shieldWarning,
                              color: _riskHighRed,
                              size: 44,
                              isCircle: true,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocale.t(
                                      'Bạn ăn món gì bị dị ứng? (VD: Bơ, Phô mai, Tôm...)',
                                      'Which food caused your allergy? (e.g. Butter, Cheese...)',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFB91C1C),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    AppLocale.t(
                                      'Chạm để tìm món ăn bạn bị dị ứng — Cây FoodOn sẽ tự động BÁO ĐỎ các thành phần liên quan (như Sữa bột, Đạm váng sữa) khi quét nhãn!',
                                      'Tap to search trigger foods — FoodOn automatically triggers a RED ALERT on related label ingredients (like Milk powder, Whey)!',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF4B5563),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            const PhosphorIcon(
                              PhosphorIconsBold.caretRight,
                              size: 16,
                              color: _riskHighRed,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_loadingCategory)
                    const NutriVietConceptListSkeleton(itemCount: 3)
                  else if (_categoryItems.isEmpty)
                    NutriVietGlassCard(
                      cornerRadius: 22,
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        AppLocale.t(
                          'Không có dữ liệu cho danh mục này.',
                          'No data available for this category.',
                        ),
                        style: const TextStyle(color: Color(0xFF6B7280)),
                      ),
                    )
                  else
                    ..._categoryItems.take(6).map((item) => Padding(
                          key: ValueKey('cat_item_${item['id'] ?? item['code'] ?? item['name']}'),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildAdditiveOrConceptCard(item),
                        )),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildBadgeColumn({
    required IconData icon,
    required bool unlocked,
    required String title,
    double? progress,
    String? progressText,
  }) {
    final badgeAccent = unlocked ? _brandGreen : const Color(0xFF6B7280);
    return NutriVietPressScale(
      pressedScale: 0.94,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              NutriVietPulseHalo(
                active: unlocked,
                glowColor: _brandGreen,
                size: 64,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: unlocked
                          ? [
                              const Color(0xFFDCFCE7),
                              const Color(0xFFBAE6CC),
                            ]
                          : [
                              const Color(0xFFF3F2EC),
                              const Color(0xFFE6E4DC),
                            ],
                    ),
                    border: Border.all(
                      color: unlocked
                          ? Colors.white.withValues(alpha: 0.95)
                          : Colors.white.withValues(alpha: 0.8),
                      width: 1.6,
                    ),
                  ),
                  child: Center(
                    child: PhosphorIcon(
                      icon,
                      size: 30,
                      color: badgeAccent,
                      duotoneSecondaryOpacity: unlocked ? 0.34 : 0.20,
                      duotoneSecondaryColor: badgeAccent,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: unlocked ? _brandGreen : const Color(0xFFD6D5CE),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: (unlocked ? _brandGreen : Colors.black)
                            .withValues(alpha: 0.16),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: PhosphorIcon(
                      unlocked
                          ? PhosphorIconsFill.sealCheck
                          : PhosphorIconsDuotone.lockKey,
                      size: 13,
                      color: unlocked ? Colors.white : const Color(0xFF4B5563),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
              height: 1.25,
            ),
          ),
          if (progress != null && progressText != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: math.max(progress, 0.15)),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, animVal, _) {
                    return LinearProgressIndicator(
                      value: animVal,
                      minHeight: 5,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: const AlwaysStoppedAnimation<Color>(_brandGreen),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              progressText,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryPill({
    required String id,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedCategory == id;
    return NutriVietPressScale(
      pressedScale: 0.94,
      enableHaptic: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          _loadCategoryConcepts(id);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isSelected
                  ? const [Color(0xF0E2F8EB), Color(0xDCD0EEDF)]
                  : const [Color(0xF2FFFFFF), Color(0xDCF3F6F9)],
            ),
            border: Border.all(
              color: isSelected
                  ? _brandGreen.withValues(alpha: 0.48)
                  : Colors.white.withValues(alpha: 0.92),
              width: 1.25,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? _brandGreen.withValues(alpha: 0.10)
                    : const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? _brandGreen.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.7),
                ),
                child: Center(
                  child: PhosphorIcon(
                    icon,
                    size: 16,
                    color: isSelected ? _brandGreen : const Color(0xFF4B5563),
                    duotoneSecondaryOpacity: 0.30,
                    duotoneSecondaryColor: _brandGreen,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? _brandGreen : const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Phụ gia / Additives
  // ---------------------------------------------------------------------------
  Widget _buildAdditivesTab() {
    final double topInset = MediaQuery.paddingOf(context).top;
    final double listTopPadding = topInset + 136;

    return Stack(
      children: [
        Positioned.fill(
          child: NutriVietGlassScrollArea(
            child: _loadingAdditives
                ? SingleChildScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(20, listTopPadding, 20, 128),
                    child: const NutriVietConceptListSkeleton(itemCount: 4),
                  )
                : _additiveError != null
                    ? Center(
                        child: Padding(
                          padding:
                              EdgeInsets.fromLTRB(24, listTopPadding, 24, 120),
                          child: NutriVietEntranceMotion(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const NutriVietGlassIconTile(
                                  icon: PhosphorIconsDuotone.cloudSlash,
                                  color: _riskHighRed,
                                  size: 68,
                                  isCircle: true,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _additiveError!,
                                  textAlign: TextAlign.center,
                                  style:
                                      const TextStyle(color: Color(0xFF4B5563)),
                                ),
                                const SizedBox(height: 16),
                                LiquidGlassButton(
                                  height: 44,
                                  style: NutriVietGlass.emeraldButton,
                                  touch: NutriVietGlass.touchHorizontalCapsule,
                                  foregroundColor: Colors.white,
                                  label: AppLocale.t('Thử lại', 'Retry'),
                                  onPressed: () =>
                                      _loadAdditives(_additiveSearchCtrl.text),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : _additiveItems.isEmpty
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                  24, listTopPadding, 24, 120),
                              child: Text(
                                AppLocale.t(
                                  'Không tìm thấy mã E hoặc thành phần phù hợp.',
                                  'No matching E-codes or ingredients found.',
                                ),
                                textAlign: TextAlign.center,
                                style:
                                    const TextStyle(color: Color(0xFF6B7280)),
                              ),
                            ),
                          )
                        : ListView.separated(
                            scrollCacheExtent:
                                const ScrollCacheExtent.pixels(800),
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            addAutomaticKeepAlives: false,
                            padding: EdgeInsets.fromLTRB(
                                20, listTopPadding, 20, 128),
                            itemCount: _additiveItems.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 14),
                            itemBuilder: (ctx, idx) {
                              return RepaintBoundary(
                                child: _buildAdditiveOrConceptCard(
                                    _additiveItems[idx]),
                              );
                            },
                          ),
          ),
        ),

        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LiquidGlassScrollEdge(
            edge: LiquidGlassEdge.top,
            height: topInset + 168,
            blur: 0,
            style: LiquidGlassScrollEdgeStyle.soft,
            curve: const Interval(0.42, 1.0, curve: Curves.easeOut),
            color: const Color(0xDCEEF6F2),
          ),
        ),

        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: RepaintBoundary(
            child: LiquidGlassBatch.exclude(
              child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocale.t('Phụ gia', 'Additives'),
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xEEFFFFFF),
                            Color(0xD8F4FAF6),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.94),
                          width: 1.3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF0F172A).withValues(alpha: 0.05),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: TextField(
                          controller: _additiveSearchCtrl,
                          onChanged: (val) {
                            _searchDebounce?.cancel();
                            _searchDebounce =
                                Timer(const Duration(milliseconds: 220), () {
                              _loadAdditives(val);
                            });
                          },
                          style: const TextStyle(
                              fontSize: 15.5, color: Color(0xFF111827)),
                          decoration: InputDecoration(
                            filled: false,
                            hintText: AppLocale.t(
                              'Tìm mã E hoặc thành phần',
                              'Search E-code or ingredient',
                            ),
                            hintStyle: const TextStyle(
                                fontSize: 15.5, color: Color(0xFF6B7280)),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(left: 14, right: 8),
                              child: PhosphorIcon(
                                PhosphorIconsDuotone.magnifyingGlass,
                                color: _brandGreen,
                                size: 21,
                                duotoneSecondaryOpacity: 0.25,
                                duotoneSecondaryColor: _brandGreen,
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                                minWidth: 42, minHeight: 42),
                            suffixIcon: _additiveSearchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const PhosphorIcon(
                                      PhosphorIconsFill.xCircle,
                                      size: 19,
                                      color: Color(0xFF6B7280),
                                    ),
                                    onPressed: () {
                                      _additiveSearchCtrl.clear();
                                      _loadAdditives('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
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
    );
  }

  Widget _buildAdditiveOrConceptCard(Map<String, dynamic> item) {
    final code = (item['code'] ?? item['curie'] ?? '').toString();
    final title = AppLocale.isEn
        ? (item['title_en'] ?? item['title'] ?? item['label_en'] ?? '').toString()
        : (item['title_vi'] ?? item['title'] ?? item['label_vi'] ?? '').toString();
    final desc = AppLocale.isEn
        ? (item['description_en'] ?? item['description'] ?? '').toString()
        : (item['description_vi'] ?? item['description'] ?? '').toString();
    final riskLevel = (item['risk_level'] ?? 'low').toString();

    return NutriVietGlassCard(
      cornerRadius: 22,
      padding: const EdgeInsets.all(18),
      onTap: () => _showConceptDetailSheet(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5ECE7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              _buildRiskPill(riskLevel),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                        height: 1.38,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const PhosphorIcon(
                PhosphorIconsBold.caretRight,
                color: Color(0xFF6B7280),
                size: 17,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Resolve a localized display name for a scanned ingredient detail entry
  String _localizedDetailName(Map<String, dynamic> detail) {
    final matches = List<Map<String, dynamic>>.from(detail['matches'] ?? []);
    if (matches.isNotEmpty) {
      final first = matches.first;
      if (AppLocale.isEn) {
        final enTitle = (first['title_en'] ?? '').toString().trim();
        if (enTitle.isNotEmpty) return enTitle;
        final labelEn = (first['label_en'] ?? '').toString().trim();
        if (labelEn.isNotEmpty) {
          return labelEn[0].toUpperCase() + (labelEn.length > 1 ? labelEn.substring(1) : '');
        }
      } else {
        final viTitle = (first['title_vi'] ?? '').toString().trim();
        if (viTitle.isNotEmpty) return viTitle;
        final termsVi = List<String>.from(first['terms_vi'] ?? []);
        if (termsVi.isNotEmpty && termsVi.first.trim().isNotEmpty) {
          final v = termsVi.first.trim();
          return v[0].toUpperCase() + (v.length > 1 ? v.substring(1) : '');
        }
      }
    }
    final rawInput = (detail['input'] ?? '').toString().trim();
    return rawInput;
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Lịch sử / History
  // ---------------------------------------------------------------------------
  Widget _buildHistoryTab() {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: _brandGreen,
        onRefresh: _refreshUserData,
        child: NutriVietGlassScrollArea(
          child: ListView(
            scrollCacheExtent: const ScrollCacheExtent.pixels(600),
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 128),
            children: [
              Text(
                AppLocale.t('Lịch sử', 'History'),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 18),
              if (_loadingInitialData && _scans.isEmpty)
                const NutriVietHistoryListSkeleton(itemCount: 3)
              else if (_scans.isEmpty)
              NutriVietEntranceMotion(
                child: NutriVietGlassCard(
                  cornerRadius: 22,
                  padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
                  child: Column(
                    children: [
                      const NutriVietGlassIconTile(
                        icon: PhosphorIconsDuotone.clockCounterClockwise,
                        color: _brandGreen,
                        size: 74,
                        isCircle: true,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocale.t('Chưa có lịch sử quét nhãn', 'No scan history yet'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppLocale.t(
                          'Hãy nhấn nút "Quét nhãn" để kiểm tra thành phần và phụ gia trên bao bì thực phẩm.',
                          'Tap "Scan label" to inspect ingredients and additives on food packaging.',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      NutriVietPressScale(
                        pressedScale: 0.96,
                        enableHaptic: true,
                        child: LiquidGlassButton(
                          height: 46,
                          icon: PhosphorIconsBold.scan,
                          label: AppLocale.t('Quét nhãn ngay', 'Scan label now'),
                          foregroundColor: Colors.white,
                          style: NutriVietGlass.emeraldButton,
                          onPressed: _openScannerScreen,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._scans.asMap().entries.map((entry) {
                final idx = entry.key;
                final scan = entry.value;
                final scanId = (scan['id'] ?? 0) as int;
                final isExpanded = _expandedScanIds.contains(scanId);
                final title = AppLocale.translateScanTitle(
                  (scan['label_title'] ?? '').toString(),
                );
                final additiveCount = (scan['additive_count'] ?? 0) as int;
                final warningCount = (scan['warning_count'] ?? 0) as int;
                final riskLevel = (scan['risk_level'] ?? 'low').toString();
                final rawText = (scan['raw_text'] ?? '').toString();
                final evaluation = (scan['evaluation'] is Map)
                    ? Map<String, dynamic>.from(scan['evaluation'] as Map)
                    : <String, dynamic>{};
                final details = List<Map<String, dynamic>>.from(evaluation['details'] ?? []);
                final redTriggers = List<Map<String, dynamic>>.from(evaluation['red_triggers'] ?? []);
                final yellowTriggers = List<Map<String, dynamic>>.from(evaluation['yellow_triggers'] ?? []);

                final localizedSummaryList = details.isNotEmpty
                    ? details.map(_localizedDetailName).where((s) => s.isNotEmpty).join(', ')
                    : rawText;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: NutriVietEntranceMotion(
                    delayMs: idx < 6 ? idx * 45 : 0,
                    child: RepaintBoundary(
                      child: NutriVietGlassCard(
                        cornerRadius: 22,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  if (isExpanded) {
                                    _expandedScanIds.remove(scanId);
                                  } else {
                                    _expandedScanIds.add(scanId);
                                  }
                                });
                              },
                              child: Row(
                                children: [
                                  Container(
                                    width: 58,
                                    height: 58,
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: riskLevel == 'high'
                                            ? [const Color(0xFFDC2626), const Color(0xFF991B1B)]
                                            : [const Color(0xFF6B7280), const Color(0xFF4B5563)],
                                      ),
                                      border: Border.all(color: Colors.white, width: 2.2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (riskLevel == 'high'
                                                  ? const Color(0xFFDC2626)
                                                  : Colors.black)
                                              .withValues(alpha: 0.16),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      localizedSummaryList,
                                      maxLines: 3,
                                      overflow: TextOverflow.clip,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 6.5,
                                        height: 1.15,
                                        fontWeight: FontWeight.w600,
                                      ),
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
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          redTriggers.isNotEmpty
                                              ? AppLocale.t(
                                                  'Phát hiện $additiveCount phụ gia · ${redTriggers.length} BÁO ĐỎ dị ứng',
                                                  'Detected $additiveCount additives · ${redTriggers.length} RED allergy alerts',
                                                )
                                              : (warningCount > 0
                                                  ? AppLocale.t(
                                                      'Phát hiện $additiveCount phụ gia · $warningCount cảnh báo',
                                                      'Detected $additiveCount additives · $warningCount warnings',
                                                    )
                                                  : AppLocale.t(
                                                      'Phát hiện $additiveCount phụ gia',
                                                      'Detected $additiveCount additives',
                                                    )),
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: redTriggers.isNotEmpty
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: redTriggers.isNotEmpty
                                                ? _riskHighRed
                                                : const Color(0xFF6B7280),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        _buildRiskPill(riskLevel),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: isExpanded
                                          ? _brandGreen.withValues(alpha: 0.14)
                                          : const Color(0xFFF0EFEA),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: AnimatedRotation(
                                        turns: isExpanded ? 0.5 : 0.0,
                                        duration: const Duration(milliseconds: 220),
                                        curve: Curves.easeOutCubic,
                                        child: PhosphorIcon(
                                          PhosphorIconsBold.caretDown,
                                          color: isExpanded ? _brandGreen : const Color(0xFF4B5563),
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              child: isExpanded
                                  ? AnimatedOpacity(
                                      opacity: isExpanded ? 1.0 : 0.0,
                                      duration: const Duration(milliseconds: 220),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 14),
                                          const Divider(height: 1, color: Color(0xFFE5E7EB)),
                                          const SizedBox(height: 12),
                                          Text(
                                            AppLocale.t(
                                              'Thành phần đã phân tích: $localizedSummaryList',
                                              'Analyzed ingredients: $localizedSummaryList',
                                            ),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF4B5563),
                                              height: 1.4,
                                            ),
                                          ),
                                          if (redTriggers.isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            Container(
                                              padding: const EdgeInsets.all(11),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF2F2),
                                                borderRadius: BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: const Color(0xFFEF4444),
                                                  width: 1.4,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: redTriggers.map((t) {
                                                  final alLabel = AppLocale.translateAllergenCode(
                                                    t['allergen_code']?.toString(),
                                                    fallback: AppLocale.isEn
                                                        ? (t['allergen_name_en'] ?? t['allergen_code']).toString()
                                                        : (t['allergen_name_vi'] ?? t['allergen_code']).toString(),
                                                  );
                                                  final matchedName = AppLocale.isEn
                                                      ? (t['matched_en'] ?? t['matched'] ?? t['token']).toString()
                                                      : (t['matched_vi'] ?? t['token'] ?? t['matched']).toString();
                                                  final srcFood = (AppLocale.isEn
                                                          ? (t['source_food_en'] ?? t['source_food'] ?? '')
                                                          : (t['source_food_vi'] ?? t['source_food'] ?? ''))
                                                      .toString()
                                                      .trim();
                                                  final hasSrcFood =
                                                      srcFood.isNotEmpty && srcFood.toLowerCase() != alLabel.toLowerCase();

                                                  return Padding(
                                                    padding: const EdgeInsets.only(bottom: 6),
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        const Padding(
                                                          padding: EdgeInsets.only(top: 1),
                                                          child: PhosphorIcon(
                                                            PhosphorIconsFill.warningOctagon,
                                                            size: 17,
                                                            color: _riskHighRed,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 7),
                                                        Expanded(
                                                          child: Text(
                                                            hasSrcFood
                                                                ? AppLocale.t(
                                                                    'BÁO ĐỎ (Từ dị ứng "$srcFood"): Phát hiện "$matchedName" thuộc cùng nhóm $alLabel trên cây FoodOn!',
                                                                    'RED ALERT (From "$srcFood" allergy): Detected "$matchedName" in the $alLabel family via FoodOn!',
                                                                  )
                                                                : AppLocale.t(
                                                                    'BÁO ĐỎ DỊ ỨNG: Phát hiện "$matchedName" → Nhóm $alLabel',
                                                                    'ALLERGY RED ALERT: Detected "$matchedName" → $alLabel',
                                                                  ),
                                                            style: const TextStyle(
                                                              fontSize: 12.8,
                                                              fontWeight: FontWeight.w800,
                                                              color: Color(0xFFB91C1C),
                                                              height: 1.35,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          ],
                                          if (yellowTriggers.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            ...yellowTriggers.map((t) {
                                              final chLabel = AppLocale.translateChronicCode(
                                                t['chronic_code']?.toString(),
                                                fallback: AppLocale.isEn
                                                    ? (t['chronic_name_en'] ?? t['chronic_code']).toString()
                                                    : (t['chronic_name_vi'] ?? t['chronic_code']).toString(),
                                              );
                                              final matchedName = AppLocale.isEn
                                                  ? (t['matched_en'] ?? t['matched'] ?? t['token']).toString()
                                                  : (t['matched_vi'] ?? t['token'] ?? t['matched']).toString();
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 6),
                                                child: Row(
                                                  children: [
                                                    const PhosphorIcon(
                                                      PhosphorIconsFill.warning,
                                                      size: 16,
                                                      color: Color(0xFFD97706),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        AppLocale.t(
                                                          'Lưu ý: $matchedName → $chLabel',
                                                          'Health note: $matchedName → $chLabel',
                                                        ),
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w700,
                                                          color: Color(0xFFB45309),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                          ],
                                          if (details.isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            Builder(
                                              builder: (context) {
                                                final triggeredAlCodes = redTriggers
                                                    .map((t) => (t['allergen_code'] ?? '').toString())
                                                    .where((s) => s.isNotEmpty)
                                                    .toSet();
                                                final triggeredChCodes = yellowTriggers
                                                    .map((t) => (t['chronic_code'] ?? '').toString())
                                                    .where((s) => s.isNotEmpty)
                                                    .toSet();

                                                return Wrap(
                                                  spacing: 6,
                                                  runSpacing: 6,
                                                  children: details.map((d) {
                                                    final matched = d['matched'] == true;
                                                    final dispName = _localizedDetailName(d);
                                                    final dAls = (d['allergens'] as List? ?? [])
                                                        .map((x) => x.toString())
                                                        .toSet();
                                                    final dChs = (d['chronics'] as List? ?? [])
                                                        .map((x) => x.toString())
                                                        .toSet();
                                                    final isRedChip = (d['is_allergy_trigger'] == true) ||
                                                        dAls.intersection(triggeredAlCodes).isNotEmpty;
                                                    final isYellowChip = !isRedChip &&
                                                        ((d['is_chronic_trigger'] == true) ||
                                                            dChs.intersection(triggeredChCodes).isNotEmpty);

                                                    return GestureDetector(
                                                      onTap: () {
                                                        final matches = d['matches'];
                                                        if (matches is List &&
                                                            matches.isNotEmpty &&
                                                            matches.first is Map) {
                                                          _showConceptDetailSheet(
                                                            Map<String, dynamic>.from(matches.first as Map),
                                                          );
                                                        }
                                                      },
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 5,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: isRedChip
                                                              ? const Color(0xFFFEE2E2)
                                                              : (isYellowChip
                                                                  ? const Color(0xFFFEF3C7)
                                                                  : (matched
                                                                      ? const Color(0xFFE2ECE5)
                                                                      : const Color(0xFFF3F4F6))),
                                                          borderRadius: BorderRadius.circular(10),
                                                          border: isRedChip
                                                              ? Border.all(
                                                                  color: const Color(0xFFDC2626),
                                                                  width: 1.5,
                                                                )
                                                              : (isYellowChip
                                                                  ? Border.all(
                                                                      color: const Color(0xFFD97706),
                                                                      width: 1.1,
                                                                    )
                                                                  : null),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            if (isRedChip) ...[
                                                              const PhosphorIcon(
                                                                PhosphorIconsFill.warningOctagon,
                                                                size: 13.5,
                                                                color: Color(0xFFDC2626),
                                                              ),
                                                              const SizedBox(width: 4),
                                                            ] else if (isYellowChip) ...[
                                                              const PhosphorIcon(
                                                                PhosphorIconsFill.warning,
                                                                size: 13.5,
                                                                color: Color(0xFFD97706),
                                                              ),
                                                              const SizedBox(width: 4),
                                                            ],
                                                            Flexible(
                                                              child: Text(
                                                                dispName,
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight: isRedChip
                                                                      ? FontWeight.w800
                                                                      : FontWeight.w600,
                                                                  color: isRedChip
                                                                      ? const Color(0xFFB91C1C)
                                                                      : (isYellowChip
                                                                          ? const Color(0xFFB45309)
                                                                          : (matched
                                                                              ? _brandGreen
                                                                              : const Color(0xFF6B7280))),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                );
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    ),
    );
  }

  // ---------------------------------------------------------------------------
  // Floating Liquid Glass Tab Bar + Detached Emerald Scan Action Orb
  // ---------------------------------------------------------------------------
  List<Widget> _buildLiquidGlassBottomChrome(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final double bottomPad = bottomInset + 14;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    const double sideMargin = 14.0;
    const double actionSize = 60.0;
    const double gap = 10.0;
    final double barWidth =
        (screenWidth - sideMargin * 2 - actionSize - gap).clamp(240.0, 380.0);

    return [
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: LiquidGlassScrollEdge(
          edge: LiquidGlassEdge.bottom,
          height: bottomPad + 80,
          blur: 0,
          style: LiquidGlassScrollEdgeStyle.soft,
          color: const Color(0xDCEAF3EE),
        ),
      ),
      LiquidGlassBatch.exclude(
        child: ValueListenableBuilder<int>(
          valueListenable: _tabNotifier,
          builder: (context, currentTab, _) => LiquidGlassTabBar(
            alignment: Alignment.bottomLeft,
            margin: EdgeInsets.only(left: sideMargin, bottom: bottomPad),
            width: barWidth,
            height: 62,
            itemPadding: 4,
            selectedIndex: currentTab,
            onChanged: (idx) {
              if (_tabNotifier.value != idx) {
                HapticFeedback.selectionClick();
                _tabNotifier.value = idx;
              }
            },
            style: NutriVietGlass.navBar,
            pillStyle: NutriVietGlass.navPill,
            itemStyle: const LiquidGlassTabItemStyle(
              selectedColor: _brandGreen,
              unselectedColor: Color(0xFF1F2937),
              iconSize: 21,
              labelFontSize: 10.5,
              iconLabelGap: 2,
            ),
            items: [
              LiquidGlassTabBarItem(
                icon: PhosphorIconsRegular.house,
                selectedIcon: PhosphorIconsFill.house,
                label: AppLocale.t('Trang chủ', 'Home'),
              ),
              LiquidGlassTabBarItem(
                icon: PhosphorIconsRegular.flask,
                selectedIcon: PhosphorIconsFill.flask,
                label: AppLocale.t('Phụ gia', 'Additives'),
              ),
              LiquidGlassTabBarItem(
                icon: PhosphorIconsRegular.clockCounterClockwise,
                selectedIcon: PhosphorIconsFill.clockCounterClockwise,
                label: AppLocale.t('Lịch sử', 'History'),
              ),
              LiquidGlassTabBarItem(
                icon: PhosphorIconsRegular.slidersHorizontal,
                selectedIcon: PhosphorIconsFill.slidersHorizontal,
                label: AppLocale.t('Cài đặt', 'Settings'),
              ),
            ],
          ),
        ),
      ),
      Positioned(
        right: sideMargin,
        bottom: bottomPad + 1,
        child: LiquidGlassBatch.exclude(
          child: LiquidGlassTabBarAction(
            icon: PhosphorIconsBold.scan,
            foregroundColor: Colors.white,
            size: actionSize,
            style: NutriVietGlass.emeraldActionOrb,
            touch: NutriVietGlass.touchPronounced,
            onTap: _openScannerScreen,
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tabChildren = <Widget>[
      _buildHomeTab(),
      _buildAdditivesTab(),
      _buildHistoryTab(),
      SettingsScreen(
        userId: _userId,
        userName: _userName,
        userEmail: _userEmail,
        onProfileUpdated: _refreshUserData,
      ),
    ];
    return NutriVietGlassBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: ValueListenableBuilder<int>(
                valueListenable: _tabNotifier,
                builder: (context, currentTab, _) => NutriVietTabView(
                  index: currentTab,
                  children: tabChildren,
                ),
              ),
            ),
            ..._buildLiquidGlassBottomChrome(context),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Full-Screen Packaging Label Scanner Screen
// =============================================================================
class _PackagingScannerScreen extends StatefulWidget {
  final int userId;
  final String memberName;

  const _PackagingScannerScreen({
    required this.userId,
    required this.memberName,
  });

  @override
  State<_PackagingScannerScreen> createState() => _PackagingScannerScreenState();
}

class _PackagingScannerScreenState extends State<_PackagingScannerScreen> {
  static const Color _brandGreen = Color(0xFF14803C);
  static const Color _brandPurple = Color(0xFF4F37C8);

  bool _isScanning = false;
  late final TextEditingController _labelTitleCtrl;
  late final TextEditingController _ingredientsCtrl;

  @override
  void initState() {
    super.initState();
    _labelTitleCtrl = TextEditingController(
      text: AppLocale.t('Kết quả quét', 'Scan result'),
    );
    _ingredientsCtrl = TextEditingController(
      text: AppLocale.t(
        'Bột mì, đường kính, dầu cọ, sữa bột (8%), đạm whey, chất nhũ hóa (E322), chất tạo màu (E102, E110), chất điều vị (E621)',
        'Wheat flour, refined sugar, palm oil, milk powder (8%), whey protein, emulsifier (E322), food colors (E102, E110), flavor enhancer (E621)',
      ),
    );
  }

  @override
  void dispose() {
    _labelTitleCtrl.dispose();
    _ingredientsCtrl.dispose();
    super.dispose();
  }

  Future<void> _executeRealScan() async {
    final text = _ingredientsCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocale.t(
              'Vui lòng nhập hoặc dán danh sách thành phần trên bao bì.',
              'Please enter or paste the packaging ingredient list.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _isScanning = true);
    final res = await ProfileService.createScan(
      userId: widget.userId,
      rawText: text,
      labelTitle: _labelTitleCtrl.text.trim().isEmpty
          ? AppLocale.t('Kết quả quét', 'Scan result')
          : _labelTitleCtrl.text.trim(),
      memberName: widget.memberName,
    );
    if (!mounted) return;
    setState(() => _isScanning = false);

    if (res['success'] == true) {
      Navigator.pop(context, res);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message'] ??
                AppLocale.t(
                  'Không thể phân tích nhãn bao bì.',
                  'Unable to analyze packaging label.',
                ),
          ),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  void _openTextEditorSheet() {
    showLiquidGlassSheet(
      context: context,
      isScrollControlled: true,
      anchor: LiquidGlassSheetAnchor.attached,
      grabber: true,
      style: NutriVietGlass.lightSheet,
      foregroundColor: NutriVietGlass.inkPrimary,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                AppLocale.t(
                  'Nhập / Dán thành phần nhãn bao bì',
                  'Enter / Paste Packaging Ingredients',
                ),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _labelTitleCtrl,
                style: const TextStyle(color: Color(0xFF111827)),
                decoration: InputDecoration(
                  labelText: AppLocale.t('Tên nhãn / sản phẩm', 'Product / label name'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ingredientsCtrl,
                maxLines: 4,
                style: const TextStyle(color: Color(0xFF111827)),
                decoration: InputDecoration(
                  labelText: AppLocale.t(
                    'Danh sách thành phần & mã E trên bao bì',
                    'Ingredient list & E-codes on packaging',
                  ),
                  hintText: AppLocale.t(
                    'VD: Bột mì, đường, sữa bột, E102, E621...',
                    'e.g., Wheat flour, sugar, milk powder, E102, E621...',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              LiquidGlassButton(
                width: double.infinity,
                height: 50,
                style: NutriVietGlass.emeraldButton,
                foregroundColor: Colors.white,
                label: AppLocale.t(
                  'Phân tích thành phần ngay',
                  'Analyze ingredients now',
                ),
                touch: const LiquidGlassTouch.flexing(LiquidGlassFlex.subtle()),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {});
                  _executeRealScan();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: NutriVietGlassBackdrop(
        dark: true,
        child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Top Floating Liquid Glass App Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
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
                          icon: PhosphorIconsBold.notePencil,
                          foregroundColor: _brandGreen,
                          size: 40,
                          style: NutriVietGlass.circleOrb,
                          touch: NutriVietGlass.touchPronounced,
                          onTap: _openTextEditorSheet,
                        ),
                      ),
                      title: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          children: [
                            TextSpan(
                                text: 'Nutri',
                                style: TextStyle(color: _brandPurple)),
                            TextSpan(
                              text: 'Viet',
                              style: TextStyle(color: _brandGreen),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: LiquidGlassTabBarAction(
                            icon: PhosphorIconsBold.x,
                            foregroundColor: const Color(0xFF1F2937),
                            size: 40,
                            style: NutriVietGlass.circleOrb,
                            touch: NutriVietGlass.touchPronounced,
                            onTap: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Top Instruction Floating Glass Banner
            Positioned(
              top: MediaQuery.of(context).padding.top + 84,
              left: 24,
              right: 24,
              child: NutriVietEntranceMotion(
                offsetY: -10,
                child: LiquidGlassLens(
                  style: NutriVietGlass.smokedCameraGlass,
                  touch: NutriVietGlass.touchHorizontalCapsule,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    child: Text(
                      AppLocale.t(
                        'Hướng camera vào mã vạch hoặc danh sách thành phần',
                        'Point the camera at a barcode or ingredient list',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Center Interactive Packaging Preview Card with Animated 120Hz Reticle
            Center(
              child: NutriVietPressScale(
                pressedScale: 0.97,
                child: GestureDetector(
                  onTap: _openTextEditorSheet,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: LiquidGlassLens(
                            style: NutriVietGlass.cardGlass(
                              cornerRadius: 22,
                              tint: const Color(0xDCFFFFFF),
                            ).copyWith(
                              blur: 7.5,
                              refractionIndex: 1.07,
                              refractionWidth: 18,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: _brandGreen.withValues(alpha: 0.55),
                                  width: 1.4,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        AppLocale.t(
                                          'NHÃN THÀNH PHẦN ĐANG QUÉT',
                                          'PACKAGING LABEL IN VIEW',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: _brandGreen,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          const PhosphorIcon(
                                            PhosphorIconsDuotone.notePencil,
                                            size: 16,
                                            color: _brandGreen,
                                            duotoneSecondaryOpacity: 0.28,
                                            duotoneSecondaryColor: _brandGreen,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            AppLocale.t('Chỉnh sửa', 'Edit'),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _brandGreen
                                                  .withValues(alpha: 0.9),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _ingredientsCtrl.text,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      color: Color(0xFF1F2937),
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child:
                              NutriVietScannerReticle(isScanning: _isScanning),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Liquid Glass Blender Dock + Morphing Status Pill
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LiquidGlassBlender(
                      smoothness: 22,
                      style: NutriVietGlass.darkBlenderCluster,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: _openTextEditorSheet,
                            child: const SizedBox(
                              width: 56,
                              height: 56,
                              child: LiquidGlassLens(
                                style: NutriVietGlass.darkBlenderCluster,
                                touch: NutriVietGlass.touchPronounced,
                                child: Center(
                                  child: PhosphorIcon(
                                    PhosphorIconsBold.images,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          GestureDetector(
                            onTap: _isScanning ? null : _executeRealScan,
                            child: SizedBox(
                              width: 84,
                              height: 84,
                              child: LiquidGlassLens(
                                touch: NutriVietGlass.touchPronounced,
                                style: NutriVietGlass.emeraldActionOrb,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (_isScanning)
                                      NutriVietPulseHalo(
                                        glowColor: Colors.white,
                                        size: 74,
                                        active: true,
                                        child: Container(
                                          width: 66,
                                          height: 66,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.72),
                                              width: 2.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    const PhosphorIcon(
                                      PhosphorIconsBold.scan,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          GestureDetector(
                            onTap: _isScanning ? null : _openTextEditorSheet,
                            child: const SizedBox(
                              width: 56,
                              height: 56,
                              child: LiquidGlassLens(
                                style: NutriVietGlass.darkBlenderCluster,
                                touch: NutriVietGlass.touchPronounced,
                                child: Center(
                                  child: PhosphorIcon(
                                    PhosphorIconsBold.notePencil,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    LiquidGlassMorph(
                      motion: LiquidGlassMorphMotion.fluid,
                      smoothness: 24,
                      touch: NutriVietGlass.touchHorizontalCapsule,
                      style: NutriVietGlass.smokedCameraGlass,
                      child: Padding(
                        key: ValueKey(
                            'scan_pill_${_isScanning}_${AppLocale.code}'),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 9),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isScanning) ...[
                              const NutriVietShimmerBox.circle(
                                size: 12,
                                baseColor: Color(0x8834D399),
                                highlightColor: Colors.white,
                              ),
                              const SizedBox(width: 9),
                            ],
                            Text(
                              _isScanning
                                  ? AppLocale.t(
                                      'Đang phân tích thành phần...',
                                      'Analyzing label ingredients...',
                                    )
                                  : AppLocale.t(
                                      'Nhấn để đọc nhãn...',
                                      'Tap to scan label...',
                                    ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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

// =============================================================================
// Dashed Circle Painter for "+ Thêm / Add" Family Profile Avatar
// =============================================================================
class _DashedCirclePainter extends CustomPainter {
  final Color color;

  _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final radius = (math.min(size.width, size.height) / 2) - 1;
    final center = Offset(size.width / 2, size.height / 2);
    const int dashCount = 16;
    const double step = (2 * math.pi) / dashCount;
    const double dashArc = step * 0.55;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * step;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashArc,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) => oldDelegate.color != color;
}
