import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../theme/nutriviet_glass.dart';
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
  static const Color _riskLowYellow = Color(0xFFFACC15);
  static const Color _riskSafeGreen = Color(0xFF16A34A);

  int _currentTab = 0; // 0: Trang chủ, 1: Phụ gia, 2: Lịch sử, 3: Cài đặt

  int _userId = 0;
  String _userName = '';
  String _userEmail = '';
  String _langPref = 'all';

  // Real data from Backend SQLite DB & FoodOn Hybrid Engine
  List<Map<String, dynamic>> _allergens = [];
  List<Map<String, dynamic>> _familyMembers = [];
  String _selectedMemberName = '';

  List<Map<String, dynamic>> _scans = [];
  int _monthlyScans = 0;
  int _monthlyWarnings = 0;
  int _totalScans = 0;
  int _warningScans = 0;
  final Set<int> _expandedScanIds = {};

  // Tab 1: Phụ gia (Live from nutriviet_hybrid.db)
  final TextEditingController _additiveSearchCtrl = TextEditingController();
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _additiveItems = [];
  bool _loadingAdditives = false;
  String? _additiveError;

  // Home category filter ('sugar', 'salt', 'fat', 'allergen')
  String _selectedCategory = 'sugar';
  List<Map<String, dynamic>> _categoryItems = [];
  bool _loadingCategory = false;

  @override
  void initState() {
    super.initState();
    _initSessionAndData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _additiveSearchCtrl.dispose();
    super.dispose();
  }

  String get _shortName {
    if (_selectedMemberName.isNotEmpty) return _selectedMemberName;
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
    });

    await Future.wait([
      _refreshUserData(),
      _loadAdditives(''),
    ]);
  }

  Future<void> _refreshUserData() async {
    if (_userId <= 0) return;
    final results = await Future.wait([
      ProfileService.getAllergens(_userId),
      ProfileService.getChronics(_userId),
      ProfileService.getFamilyMembers(_userId),
      ProfileService.getScans(_userId),
      ProfileService.getSettings(_userId),
    ]);
    if (!mounted) return;

    setState(() {
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
      }
      if (results[4]['success'] == true && results[4]['settings'] is Map) {
        final s = results[4]['settings'] as Map;
        final l = (s['language'] ?? 'system').toString();
        _langPref = (l == 'vi' || l == 'en') ? l : 'all';
      }
    });

    await _loadCategoryConcepts(_selectedCategory);
  }

  Future<void> _loadAdditives(String query) async {
    if (!mounted) return;
    setState(() {
      _loadingAdditives = true;
      _additiveError = null;
    });

    final res = await ProfileService.getAdditives(
      query: query,
      lang: _langPref,
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

    final alCodes = _allergens.map((a) => (a['code'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
    final res = await ProfileService.getCategoryConcepts(
      category: category,
      allergens: alCodes,
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
      if (result['name'] != null && result['name'].toString().isNotEmpty) {
        setState(() => _userName = result['name'].toString());
      }
    }
    await _refreshUserData();
  }

  Future<void> _openAddFamilyMemberDialog() async {
    final nameCtrl = TextEditingController();
    final relCtrl = TextEditingController(text: 'Người thân');

    await showLiquidGlassDialog(
      context: context,
      builder: (ctx) {
        return LiquidGlassAlertDialog(
          style: NutriVietGlass.lightSheet,
          title: const Text(
            'Thêm hồ sơ gia đình',
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
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Color(0xFF111827)),
                  decoration: const InputDecoration(
                    labelText: 'Tên thành viên (VD: Mẹ, Bé An)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: relCtrl,
                  style: const TextStyle(color: Color(0xFF111827)),
                  decoration: const InputDecoration(
                    labelText: 'Mối quan hệ',
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
              label: 'Hủy',
              onPressed: () => Navigator.pop(ctx),
            ),
            LiquidGlassButton(
              height: 42,
              style: NutriVietGlass.emeraldButton,
              foregroundColor: Colors.white,
              label: 'Lưu hồ sơ',
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
                      content: Text(res['message'] ?? 'Không thể thêm hồ sơ.'),
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
  // Screen 3: Full-Screen Camera / Packaging Label Scanner (Screenshot 3)
  // ---------------------------------------------------------------------------
  Future<void> _openScannerScreen() async {
    final scanRes = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _PackagingScannerScreen(
          userId: _userId,
          memberName: _shortName,
        ),
      ),
    );

    if (scanRes != null && scanRes['success'] == true) {
      await _refreshUserData();
      if (!mounted) return;
      final latest = scanRes['latest_scan'];
      if (latest is Map<String, dynamic>) {
        setState(() {
          _currentTab = 2; // Switch to Lịch sử tab and expand latest result
          if (latest['id'] is int) {
            _expandedScanIds.add(latest['id'] as int);
          }
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Risk Pill Badge Widget (Matches Screenshots 2 & 4)
  // ---------------------------------------------------------------------------
  Widget _buildRiskPill(String riskLevel, {String? customLabel}) {
    final level = riskLevel.toLowerCase();
    if (level == 'high' || level == 'red') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: _riskHighRed,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 12, color: _riskHighRed),
            ),
            const SizedBox(width: 6),
            Text(
              customLabel ?? 'Nguy cơ cao',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    } else if (level == 'safe' || level == 'green') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: _riskSafeGreen,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 12, color: _riskSafeGreen),
            ),
            const SizedBox(width: 6),
            Text(
              customLabel ?? 'An toàn',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: _riskLowYellow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(color: Color(0xFF1F2937), shape: BoxShape.circle),
              child: const Center(
                child: Text(
                  '!',
                  style: TextStyle(
                    color: _riskLowYellow,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              customLabel ?? 'Nguy cơ thấp',
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Concept Detail Bottom Sheet (FoodOn Ontology Lineage + Kala Terms)
  // ---------------------------------------------------------------------------
  void _showConceptDetailSheet(Map<String, dynamic> item) {
    final code = (item['code'] ?? item['curie'] ?? '').toString();
    final curie = (item['curie'] ?? '').toString();
    final title = (item['title'] ?? item['label_en'] ?? '').toString();
    final desc = (item['description'] ?? '').toString();
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
                    'Mã phụ gia Quốc tế (Europe / Codex INS): ${ecodes.join(", ")}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _brandGreen),
                  ),
                ],
                if (viTerms.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Từ đồng nghĩa Tiếng Việt (Kala DB): ${viTerms.join(", ")}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                  ),
                ],
                if (enTerms.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Thuật ngữ Tiếng Anh (FoodOn OWL): ${enTerms.join(", ")}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                ],
                if (lineageNodes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Cây phân loại FoodOn Ontology:',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: lineageNodes.map((n) {
                      final lbl = (n['label_vi'] != null && n['label_vi'].toString().isNotEmpty)
                          ? '${n['label_vi']} (${n['label_en']})'
                          : n['label_en'].toString();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${n['curie']}: $lbl',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                        ),
                      );
                    }).toList(),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text('Mã định danh: $curie', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ],
              ],
            ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 0: Trang chủ (Screenshot 1)
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
        child: ListView(
          scrollCacheExtent: const ScrollCacheExtent.pixels(800),
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            // Top-right Liquid Glass chat/feedback orb
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  showLiquidGlassDialog(
                    context: context,
                    builder: (ctx) => LiquidGlassAlertDialog(
                      style: NutriVietGlass.lightSheet,
                      title: const Text(
                        'Hỗ trợ & Phản hồi',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      content: const Text(
                        'Hệ thống tra cứu nhãn thực phẩm song ngữ được kết nối trực tiếp từ cơ sở dữ liệu FoodOn Ontology (25,577 khái niệm, 742 mã E/INS) và từ điển Kala.',
                        style: TextStyle(
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
                          label: 'Đóng',
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  );
                },
                child: const SizedBox(
                  width: 46,
                  height: 46,
                  child: LiquidGlassLens(
                    style: NutriVietGlass.circleOrb,
                    touch: LiquidGlassTouch.flexing(LiquidGlassFlex.subtle()),
                    child: Center(
                      child: Icon(
                        Icons.forum_outlined,
                        color: Color(0xFF1F2937),
                        size: 21,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const Text(
              'Trang chủ',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 14),

            // Main Hero Green Card (Matches Screenshot 1)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              decoration: BoxDecoration(
                color: _brandGreen,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _brandGreen.withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'THÁNG NÀY',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Thống kê số nhãn thực phẩm đã quét và số cảnh báo phát hiện trong tháng hiện tại.'),
                              backgroundColor: _brandGreen,
                            ),
                          );
                        },
                        child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_monthlyScans',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Đã đọc $_monthlyScans nhãn · Phát hiện $_monthlyWarnings cảnh báo',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Còn 1 lần quét miễn phí',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // HỒ SƠ GIA ĐÌNH Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'HỒ SƠ GIA ĐÌNH',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                      GestureDetector(
                        onTap: _openAllergyProfile,
                        child: const Row(
                          children: [
                            Text(
                              'Quản lý hồ sơ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Family Member Avatars Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...members.map((m) {
                          final mName = (m['member_name'] ?? _shortName).toString();
                          final isSelected = mName == _selectedMemberName || (_selectedMemberName.isEmpty && m == members.first);
                          return Padding(
                            padding: const EdgeInsets.only(right: 22),
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedMemberName = mName),
                              child: Column(
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const RadialGradient(
                                        colors: [Color(0xFF60A5FA), Color(0xFF1D4ED8)],
                                        center: Alignment(-0.2, -0.2),
                                        radius: 0.9,
                                      ),
                                      border: Border.all(
                                        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                                        width: isSelected ? 2.5 : 1.5,
                                      ),
                                    ),
                                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    mName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                        // Dashed "+ Thêm" button
                        GestureDetector(
                          onTap: _openAddFamilyMemberDialog,
                          child: Column(
                            children: [
                              RepaintBoundary(
                                child: CustomPaint(
                                  painter: _DashedCirclePainter(color: Colors.white.withValues(alpha: 0.85)),
                                  child: const SizedBox(
                                    width: 54,
                                    height: 54,
                                    child: Center(
                                      child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Thêm',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Bottom White Pill Button "[||] Quét nhãn"
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _openScannerScreen,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _brandGreen,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner_rounded, color: _brandGreen, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Quét nhãn',
                            style: TextStyle(
                              color: _brandGreen,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),

            // Section: Huy hiệu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Huy hiệu',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _currentTab = 2),
                  child: const Text(
                    'Xem tất cả',
                    style: TextStyle(
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
                      icon: Icons.find_in_page_outlined,
                      unlocked: badgeFirstScan,
                      title: 'Đọc nhãn đầu\ntiên của bạn',
                    ),
                  ),
                  Expanded(
                    child: _buildBadgeColumn(
                      icon: Icons.shield_rounded,
                      unlocked: badgeFirstWarning,
                      title: 'Phát hiện cảnh\nbáo đầu tiên',
                    ),
                  ),
                  Expanded(
                    child: _buildBadgeColumn(
                      icon: Icons.star_rounded,
                      unlocked: badgeTenScans,
                      title: 'Đọc 10 nhãn',
                      progress: tenProgress,
                      progressText: '${_totalScans.clamp(0, 10)}/10 nhãn',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Category Pills Row: Đường, Muối, Chất béo, Dị ứng
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryPill(
                    id: 'sugar',
                    icon: Icons.view_in_ar_rounded,
                    label: 'Đường',
                  ),
                  const SizedBox(width: 10),
                  _buildCategoryPill(
                    id: 'salt',
                    icon: Icons.grid_on_rounded,
                    label: 'Muối',
                  ),
                  const SizedBox(width: 10),
                  _buildCategoryPill(
                    id: 'fat',
                    icon: Icons.water_drop_rounded,
                    label: 'Chất béo',
                  ),
                  const SizedBox(width: 10),
                  _buildCategoryPill(
                    id: 'allergen',
                    icon: Icons.grain_rounded,
                    label: 'Dị ứng',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Active Category Knowledge Section (Driven by real FoodOn DB)
            Text(
              _selectedCategory == 'sugar'
                  ? 'Đường'
                  : (_selectedCategory == 'salt'
                      ? 'Muối'
                      : (_selectedCategory == 'fat' ? 'Chất béo' : 'Dị ứng')),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 10),
            if (_loadingCategory)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: _brandGreen)),
              )
            else if (_categoryItems.isEmpty)
              const NutriVietGlassCard(
                cornerRadius: 22,
                padding: EdgeInsets.all(18),
                child: Text(
                  'Không có dữ liệu cho danh mục này.',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              )
            else
              ..._categoryItems.take(6).map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildAdditiveOrConceptCard(item),
                  )),
          ],
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
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: unlocked ? const Color(0xFFD6E8DC) : const Color(0xFFEBEAE4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 30,
                color: unlocked ? _brandGreen : const Color(0xFF6B7280),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: unlocked ? _brandGreen : const Color(0xFFD6D5CE),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  unlocked ? Icons.check_rounded : Icons.lock_rounded,
                  size: 13,
                  color: unlocked ? Colors.white : const Color(0xFF6B7280),
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
              child: LinearProgressIndicator(
                value: math.max(progress, 0.15),
                minHeight: 5,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: const AlwaysStoppedAnimation<Color>(_brandGreen),
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
    );
  }

  Widget _buildCategoryPill({
    required String id,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedCategory == id;
    return GestureDetector(
      onTap: () => _loadCategoryConcepts(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xD4E0EFE5) : const Color(0xD8FFFFFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? _brandGreen.withValues(alpha: 0.48)
                : const Color(0xF0FFFFFF),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0B0F2418),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: _brandGreen),
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
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Phụ gia (Screenshot 2) — Scrolling list under Floating Glass Search
  // ---------------------------------------------------------------------------
  Widget _buildAdditivesTab() {
    final double topInset = MediaQuery.paddingOf(context).top;
    final double listTopPadding = topInset + 136;

    return Stack(
      children: [
        Positioned.fill(
          child: _loadingAdditives
              ? Padding(
                  padding: EdgeInsets.only(top: listTopPadding),
                  child: const Center(
                    child: CircularProgressIndicator(color: _brandGreen),
                  ),
                )
              : _additiveError != null
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(24, listTopPadding, 24, 120),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 42, color: _riskHighRed),
                            const SizedBox(height: 10),
                            Text(
                              _additiveError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF4B5563)),
                            ),
                            const SizedBox(height: 14),
                            LiquidGlassButton(
                              height: 44,
                              style: NutriVietGlass.emeraldButton,
                              foregroundColor: Colors.white,
                              label: 'Thử lại',
                              onPressed: () => _loadAdditives(_additiveSearchCtrl.text),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _additiveItems.isEmpty
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(24, listTopPadding, 24, 120),
                            child: const Text(
                              'Không tìm thấy mã E hoặc thành phần phù hợp trong cơ sở dữ liệu FoodOn.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF6B7280)),
                            ),
                          ),
                        )
                      : ListView.separated(
                          scrollCacheExtent: const ScrollCacheExtent.pixels(800),
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          addAutomaticKeepAlives: false,
                          padding: EdgeInsets.fromLTRB(20, listTopPadding, 20, 128),
                          itemCount: _additiveItems.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (ctx, idx) {
                            return RepaintBoundary(
                              child: _buildAdditiveOrConceptCard(_additiveItems[idx]),
                            );
                          },
                        ),
        ),

        // Soft mist scroll fade under top floating header & glass search bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LiquidGlassScrollEdge(
            edge: LiquidGlassEdge.top,
            height: topInset + 164,
            blur: 0,
            curve: const Interval(0.42, 1.0, curve: Curves.easeOut),
            color: const Color(0xFFF3F6F3),
          ),
        ),

        // Floating Title + Live Liquid Glass Search Capsule
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Phụ gia',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    child: LiquidGlassLens(
                      style: NutriVietGlass.floatingChrome,
                      touch: const LiquidGlassTouch.flexing(LiquidGlassFlex.subtle()),
                      child: Center(
                        child: TextField(
                          controller: _additiveSearchCtrl,
                          onChanged: (val) {
                            _searchDebounce?.cancel();
                            _searchDebounce = Timer(const Duration(milliseconds: 220), () {
                              _loadAdditives(val);
                            });
                          },
                          style: const TextStyle(fontSize: 15.5, color: Color(0xFF111827)),
                          decoration: InputDecoration(
                            filled: false,
                            hintText: 'Tìm mã E hoặc thành phần',
                            hintStyle: const TextStyle(fontSize: 15.5, color: Color(0xFF6B7280)),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF374151),
                              size: 22,
                            ),
                            suffixIcon: _additiveSearchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      _additiveSearchCtrl.clear();
                                      _loadAdditives('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdditiveOrConceptCard(Map<String, dynamic> item) {
    final code = (item['code'] ?? item['curie'] ?? '').toString();
    final title = (item['title'] ?? item['label_en'] ?? '').toString();
    final desc = (item['description'] ?? '').toString();
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
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF6B7280),
                size: 22,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Lịch sử (Screenshot 4)
  // ---------------------------------------------------------------------------
  Widget _buildHistoryTab() {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: _brandGreen,
        onRefresh: _refreshUserData,
        child: ListView(
          scrollCacheExtent: const ScrollCacheExtent.pixels(600),
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 128),
          children: [
            const Text(
              'Lịch sử',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 18),
            if (_scans.isEmpty)
              NutriVietGlassCard(
                cornerRadius: 22,
                padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
                child: Column(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF9CA3AF)),
                    const SizedBox(height: 12),
                    const Text(
                      'Chưa có lịch sử quét nhãn',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Hãy nhấn nút "Quét nhãn" để kiểm tra thành phần và phụ gia trên bao bì thực phẩm.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    LiquidGlassButton(
                      height: 46,
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Quét nhãn ngay',
                      foregroundColor: Colors.white,
                      style: NutriVietGlass.emeraldButton,
                      onPressed: _openScannerScreen,
                    ),
                  ],
                ),
              )
            else
              ..._scans.map((scan) {
                final scanId = (scan['id'] ?? 0) as int;
                final isExpanded = _expandedScanIds.contains(scanId);
                final title = (scan['label_title'] ?? 'Kết quả quét').toString();
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

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: RepaintBoundary(
                    child: NutriVietGlassCard(
                      cornerRadius: 22,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () {
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
                                // Left circular label preview thumbnail (no expensive ClipOval layer)
                                Container(
                                  width: 58,
                                  height: 58,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: riskLevel == 'high'
                                        ? const Color(0xFFB91C1C)
                                        : const Color(0xFF78716C),
                                    border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                                  ),
                                  child: Text(
                                    rawText,
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
                                      warningCount > 0
                                          ? 'Phát hiện $additiveCount phụ gia · $warningCount cảnh báo'
                                          : 'Phát hiện $additiveCount phụ gia',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildRiskPill(riskLevel),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF0EFEA),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: const Color(0xFF4B5563),
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isExpanded) ...[
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: Color(0xFFE5E7EB)),
                          const SizedBox(height: 12),
                          Text(
                            'Thành phần đã quét: $rawText',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF4B5563),
                              height: 1.4,
                            ),
                          ),
                          if (redTriggers.isNotEmpty || yellowTriggers.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ...redTriggers.map((t) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.cancel_rounded, size: 16, color: _riskHighRed),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Dị ứng: ${t['token']} → ${t['allergen_name_vi']} (${t['curie']})',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: _riskHighRed,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                            ...yellowTriggers.map((t) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Lưu ý: ${t['token']} → ${t['chronic_name_vi'] ?? t['allergen_name_vi']} (${t['curie']})',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFB45309),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                          if (details.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: details.map((d) {
                                final matched = d['matched'] == true;
                                final matches = List<Map<String, dynamic>>.from(d['matches'] ?? []);
                                final curie = matches.isNotEmpty ? matches.first['curie'] : '';
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: matched ? const Color(0xFFE2ECE5) : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    matched ? '${d['input']} ($curie)' : '${d['input']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: matched ? _brandGreen : const Color(0xFF6B7280),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ],
                    ),
                    ),
                  ),
                );
              }),
          ],
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
          height: bottomPad + 78,
          blur: 0,
          color: const Color(0xDCEAF1EE),
        ),
      ),
      LiquidGlassTabBar(
        alignment: Alignment.bottomLeft,
        margin: EdgeInsets.only(left: sideMargin, bottom: bottomPad),
        width: barWidth,
        height: 62,
        itemPadding: 4,
        selectedIndex: _currentTab,
        onChanged: (idx) {
          if (_currentTab != idx) {
            setState(() => _currentTab = idx);
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
        items: const [
          LiquidGlassTabBarItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'Trang chủ',
          ),
          LiquidGlassTabBarItem(
            icon: Icons.assignment_outlined,
            selectedIcon: Icons.assignment_rounded,
            label: 'Phụ gia',
          ),
          LiquidGlassTabBarItem(
            icon: Icons.inventory_2_outlined,
            selectedIcon: Icons.inventory_2_rounded,
            label: 'Lịch sử',
          ),
          LiquidGlassTabBarItem(
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
            label: 'Cài đặt',
          ),
        ],
      ),
      Positioned(
        right: sideMargin,
        bottom: bottomPad + 1,
        child: LiquidGlassTabBarAction(
          icon: Icons.qr_code_scanner_rounded,
          foregroundColor: Colors.white,
          size: actionSize,
          style: NutriVietGlass.emeraldActionOrb,
          touch: const LiquidGlassTouch.flexing(LiquidGlassFlex.subtle()),
          onTap: _openScannerScreen,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return NutriVietGlassBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(
                index: _currentTab,
                children: [
                  RepaintBoundary(child: _buildHomeTab()),
                  RepaintBoundary(child: _buildAdditivesTab()),
                  RepaintBoundary(child: _buildHistoryTab()),
                  RepaintBoundary(
                    child: SettingsScreen(
                      userId: _userId,
                      userName: _userName,
                      userEmail: _userEmail,
                      onProfileUpdated: _refreshUserData,
                    ),
                  ),
                ],
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
// Full-Screen Packaging Label Scanner Screen (Matches Screenshot 3)
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
  final TextEditingController _labelTitleCtrl = TextEditingController(text: 'Kết quả quét');
  final TextEditingController _ingredientsCtrl = TextEditingController(
    text: 'Bột mì, đường kính, dầu cọ, sữa bột (8%), whey protein, chất nhũ hóa (E322), chất tạo màu (E102, E110), chất điều vị (E621)',
  );

  Future<void> _executeRealScan() async {
    final text = _ingredientsCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập hoặc dán danh sách thành phần trên bao bì.')),
      );
      return;
    }

    setState(() => _isScanning = true);
    final res = await ProfileService.createScan(
      userId: widget.userId,
      rawText: text,
      labelTitle: _labelTitleCtrl.text.trim().isEmpty ? 'Kết quả quét' : _labelTitleCtrl.text.trim(),
      memberName: widget.memberName,
    );
    if (!mounted) return;
    setState(() => _isScanning = false);

    if (res['success'] == true) {
      Navigator.pop(context, res);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Không thể phân tích nhãn bao bì.'),
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
              const Text(
                'Nhập / Dán thành phần nhãn bao bì',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _labelTitleCtrl,
                style: const TextStyle(color: Color(0xFF111827)),
                decoration: const InputDecoration(
                  labelText: 'Tên nhãn / sản phẩm',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ingredientsCtrl,
                maxLines: 4,
                style: const TextStyle(color: Color(0xFF111827)),
                decoration: const InputDecoration(
                  labelText: 'Danh sách thành phần & mã E trên bao bì',
                  hintText: 'VD: Bột mì, đường, sữa bột, E102, E621...',
                ),
              ),
              const SizedBox(height: 16),
              LiquidGlassButton(
                width: double.infinity,
                height: 50,
                style: NutriVietGlass.emeraldButton,
                foregroundColor: Colors.white,
                label: 'Phân tích bằng FoodOn + Kala Engine',
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
    return Scaffold(
      backgroundColor: const Color(0xFFD8D0C5),
      body: Stack(
        children: [
          // Simulated live camera viewfinder surface with subtle warm room gradient (Matches Screenshot 3)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFDDD6CA),
                    Color(0xFFD2C9BC),
                    Color(0xFFC4B9AA),
                  ],
                ),
              ),
            ),
          ),

          // Top Header Bar ("YukoThực phẩm" + Liquid Glass Close Orb)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: const Color(0xB8F1F4F1),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          children: [
                            TextSpan(text: 'Yuko', style: TextStyle(color: _brandPurple)),
                            TextSpan(text: 'Thực phẩm', style: TextStyle(color: _brandGreen)),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: LiquidGlassTabBarAction(
                          icon: Icons.close_rounded,
                          foregroundColor: const Color(0xFF1F2937),
                          size: 42,
                          style: NutriVietGlass.circleOrb,
                          touch: const LiquidGlassTouch.flexing(LiquidGlassFlex.subtle()),
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
            top: MediaQuery.of(context).padding.top + 76,
            left: 28,
            right: 28,
            child: const LiquidGlassLens(
              style: NutriVietGlass.smokedCameraGlass,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Text(
                  'Hướng camera vào mã vạch hoặc danh sách thành phần',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),

          // Center Interactive Packaging Preview Card (Tap to edit ingredients)
          Center(
            child: GestureDetector(
              onTap: _openTextEditorSheet,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: LiquidGlassLite(
                  shape: const LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 22),
                  blur: 0,
                  color: const Color(0xE8FFFFFF),
                  specular: const LiquidGlassLight.specular(
                    thickness: 2.2,
                    sharpness: 0.68,
                    angle: 40,
                    spread: 0.85,
                    intensity: 0.85,
                    color: Color(0xF5FFFFFF),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _brandGreen.withValues(alpha: 0.45), width: 1.4),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'NHÃN THÀNH PHẦN ĐANG QUÉT',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: _brandGreen,
                                letterSpacing: 0.4,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.edit_note_rounded, size: 16, color: _brandGreen),
                                const SizedBox(width: 4),
                                Text(
                                  'Chỉnh sửa',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _brandGreen.withValues(alpha: 0.9),
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
            ),
          ),

          // Bottom Scanner Controls (Liquid Glass Gallery Orb + Center Shutter + Status Capsule)
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Left Gallery / Edit Input Glass Orb
                        Align(
                          alignment: Alignment.centerLeft,
                          child: LiquidGlassTabBarAction(
                            icon: Icons.photo_library_outlined,
                            foregroundColor: Colors.white,
                            size: 54,
                            style: NutriVietGlass.smokedCameraGlass.copyWith(
                              shape: const LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 99),
                            ),
                            touch: const LiquidGlassTouch.flexing(LiquidGlassFlex.subtle()),
                            onTap: _openTextEditorSheet,
                          ),
                        ),

                        // Center Large Scan Shutter Button with Green Progress Ring
                        GestureDetector(
                          onTap: _isScanning ? null : _executeRealScan,
                          child: SizedBox(
                            width: 82,
                            height: 82,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const LiquidGlassLite(
                                  shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 99),
                                  blur: 0,
                                  color: Color(0xB89E9D99),
                                  specular: LiquidGlassLight.specular(
                                    thickness: 2.5,
                                    angle: 39,
                                    spread: 0.9,
                                    intensity: 0.9,
                                    color: Color(0xCCFFFFFF),
                                  ),
                                  child: SizedBox(width: 82, height: 82),
                                ),
                                SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: CircularProgressIndicator(
                                    value: _isScanning ? null : 0.35,
                                    strokeWidth: 4.5,
                                    backgroundColor: Colors.white.withValues(alpha: 0.35),
                                    valueColor: const AlwaysStoppedAnimation<Color>(_brandGreen),
                                  ),
                                ),
                                const Icon(
                                  Icons.search_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  LiquidGlassLite(
                    shape: const LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 20),
                    blur: 0,
                    color: const Color(0xC08B8986),
                    specular: const LiquidGlassLight.specular(
                      thickness: 1.8,
                      angle: 39,
                      spread: 0.85,
                      intensity: 0.7,
                      color: Color(0xAAFFFFFF),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      child: Text(
                        _isScanning ? 'Đang đọc nhãn...' : 'Nhấn để đọc nhãn...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Dashed Circle Painter for "+ Thêm" Family Profile Avatar
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
