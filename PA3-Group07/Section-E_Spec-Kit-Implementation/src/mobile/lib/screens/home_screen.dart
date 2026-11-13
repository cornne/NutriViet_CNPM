import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'login_screen.dart';
import 'allergy_profile_screen.dart';
import 'settings_screen.dart';
import 'community_feed_screen.dart';
import 'contribute_product_screen.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  List<dynamic> _allergens = [];
  bool _isLoadingAllergens = true;
  Map<String, dynamic>? _userMetrics;
  late String _userName;
  late String _userEmail;

  @override
  void initState() {
    super.initState();
    _userName = widget.user['full_name'] ?? '';
    _userEmail = widget.user['email'] ?? '';
    _loadUserSession();
    _loadUserAllergens();
  }

  Future<void> _loadUserSession() async {
    final session = await AuthService.getSession();
    if (session != null && mounted) {
      setState(() {
        if (_userEmail.isEmpty || _userEmail == 'an.nguyen@nutriviet.vn') {
          _userEmail = session['email'] ?? '';
        }
        if (_userName.isEmpty || _userName == 'Nguyễn Văn An') {
          _userName = session['full_name'] ?? '';
        }
      });
    }
  }

  void _showEditNameDialog(int userId) {
    final controller = TextEditingController(text: _userName.isNotEmpty ? _userName : (widget.user['full_name'] ?? ''));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.badge_outlined, color: Color(0xFF10B981), size: 22),
            SizedBox(width: 8),
            Text('Đổi Họ và Tên', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Họ và tên mới',
            hintText: 'Nhập tên của bạn...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);
              final res = await AuthService.updateProfile(userId: userId, fullName: newName);
              if (res['success'] == true && mounted) {
                setState(() => _userName = newName);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cập nhật họ và tên thành công!'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Lỗi khi cập nhật tên.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserAllergens() async {
    final userId = widget.user['id'] is int
        ? widget.user['id']
        : int.tryParse(widget.user['id']?.toString() ?? '1') ?? 1;

    setState(() => _isLoadingAllergens = true);
    final res = await ProfileService.getAllergens(userId);
    final mRes = await ProfileService.getMetrics(userId);
    if (!mounted) return;

    setState(() {
      _allergens = res['success'] == true ? (res['allergens'] ?? []) : [];
      if (mRes['success'] == true) {
        _userMetrics = mRes['metrics'];
      }
      _isLoadingAllergens = false;
    });
  }

  Future<void> _handleLogout(BuildContext context) async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _openScanModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF10B981), size: 26),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quét Nhãn Bao Bì Thực Phẩm',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'OCR FoodOn AI • Phát hiện dị ứng tức thì',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Viewfinder Mockup
            Container(
              height: 170,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 150,
                    height: 110,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF10B981), width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.camera_alt_outlined, color: Colors.white70, size: 36),
                      SizedBox(height: 8),
                      Text(
                        'Đặt khung hình vào bảng thành phần',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Chọn Ảnh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tính năng tải ảnh thư viện: Đang liên kết module OCR.'),
                          backgroundColor: Color(0xFF10B981),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('Chụp Bao Bì'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mở Camera quét OCR: Đang sẵn sàng tích hợp CameraX.'),
                          backgroundColor: Color(0xFF10B981),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _openHistoryModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.history_rounded, color: Color(0xFF3B82F6), size: 24),
                SizedBox(width: 8),
                Text('Lịch Sử Quét Thực Phẩm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Chưa có lượt quét nào gần đây. Hãy bấm nút QUÉT ở giữa thanh Taskbar để kiểm tra sản phẩm đầu tiên của bạn!',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openScanModal();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Quét Sản Phẩm Ngay'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isSelected = _currentTab == index;
    final color = isSelected ? const Color(0xFF10B981) : const Color(0xFF64748B);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getAllergenEmoji(String code) {
    switch (code) {
      case 'peanuts':
        return '🥜';
      case 'seafood':
        return '🦐';
      case 'milk':
        return '🥛';
      case 'gluten':
        return '🌾';
      case 'eggs':
        return '🥚';
      case 'soy':
        return '🌱';
      case 'tree_nuts':
        return '🌰';
      case 'sesame':
        return '🌿';
      default:
        return '⚠️';
    }
  }

  String _getSeverityLabel(String severity) {
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

  Color _getSeverityColor(String severity) {
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

  Widget _buildQuickActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String fullName = _userName.isNotEmpty ? _userName : (widget.user['full_name'] ?? 'Người dùng');
    final String email = _userEmail.isNotEmpty ? _userEmail : (widget.user['email'] ?? '');
    final int userId = widget.user['id'] is int
        ? widget.user['id']
        : int.tryParse(widget.user['id']?.toString() ?? '1') ?? 1;

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
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text('🛡️', style: TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NutriViet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const Text(
                            'Allergen Safety Shield',
                            style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Cài đặt & Đổi mật khẩu',
                        icon: const Icon(Icons.settings_outlined, color: Color(0xFF64748B), size: 22),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SettingsScreen(user: {
                                'id': userId,
                                'full_name': fullName,
                                'email': email,
                              }),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Đăng xuất',
                        icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B), size: 20),
                        onPressed: () => _handleLogout(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserAllergens,
        color: const Color(0xFF10B981),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Profile Banner - Tap to edit Age, Height, Weight & Allergens
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  final res = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AllergyProfileScreen(
                        userId: userId,
                        userName: fullName,
                        userEmail: email,
                      ),
                    ),
                  );
                  if (res is Map && res['full_name'] != null) {
                    setState(() {
                      _userName = res['full_name'];
                      if (res['email'] != null && res['email'].toString().isNotEmpty) {
                        _userEmail = res['email'];
                      }
                    });
                  }
                  _loadUserAllergens();
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text('👤', style: TextStyle(fontSize: 24)),
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
                                    '$fullName (${_userMetrics?['age'] ?? 22} tuổi)',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => _showEditNameDialog(userId),
                                  borderRadius: BorderRadius.circular(12),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(Icons.edit_outlined, size: 16, color: Color(0xFF10B981)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  email.isNotEmpty ? email : 'Đang tải thông tin...',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                                if (_userMetrics != null) ...[
                                  const Text(' • ', style: TextStyle(color: Color(0xFFCBD5E1))),
                                  Text(
                                    'BMI ${_userMetrics?['bmi'] ?? 22.5}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1FAE5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Hồ sơ cá nhân chính • Chạm để chỉnh sửa ✎',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Active Allergens Monitoring Card
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
                          '🚨 Nhóm Dị Ứng Cần Tránh',
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
                            '${_allergens.length} đã chọn',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingAllergens)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                          ),
                        ),
                      )
                    else if (_allergens.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Chưa chọn dị ứng nào. Bấm Chỉnh sửa hồ sơ để cài đặt các nhóm dị ứng cần tránh.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _allergens.map((item) {
                          final code = item['code'] ?? '';
                          final name = item['name'] ?? '';
                          final severity = item['severity'] ?? 'high';
                          final emoji = _getAllergenEmoji(code);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFEF4444), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$emoji $name',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: _getSeverityColor(severity),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _getSeverityLabel(severity),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Camera Scanner Hero Card (Feature Highlight)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.document_scanner_rounded, color: Color(0xFF10B981), size: 28),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quét Nhãn Thực Phẩm',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'OCR FoodOn AI • Cảnh báo tức thì',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Chụp ảnh bảng thành phần dinh dưỡng để phát hiện ngay các chất dị ứng hoặc dẫn xuất ẩn.',
                      style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: const Text('Bắt Đầu Quét Bao Bì'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: _openScanModal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Other System Features Grid/List (All intact & accessible!)
              const Text(
                'Chức năng hệ sinh thái NutriViet',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),

              _buildQuickActionCard(
                icon: Icons.dynamic_feed_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Mạng Xã Hội Cộng Đồng Dị Ứng',
                subtitle: 'Xem bảng tin, cảnh báo an toàn & bài viết chia sẻ thực phẩm',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommunityFeedScreen(user: widget.user),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              _buildQuickActionCard(
                icon: Icons.add_photo_alternate_rounded,
                iconColor: const Color(0xFF06B6D4),
                title: 'Đăng Tải Sản Phẩm (Upload Ảnh)',
                subtitle: 'Đóng góp ảnh bao bì & phân tích thành phần cho cộng đồng',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContributeProductScreen(user: widget.user),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              _buildQuickActionCard(
                icon: Icons.history_rounded,
                iconColor: const Color(0xFF3B82F6),
                title: 'Lịch Sử Quét & Cảnh Báo An Toàn',
                subtitle: 'Xem lại các sản phẩm đã kiểm tra an toàn và gắn cờ cảnh báo',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Lịch sử quét: Tính năng lưu vết OCR đang sẵn sàng tích hợp.'),
                      backgroundColor: Color(0xFF3B82F6),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              _buildQuickActionCard(
                icon: Icons.shopping_basket_outlined,
                iconColor: const Color(0xFF10B981),
                title: 'Danh Sách Đi Chợ An Toàn (Safe Shopping)',
                subtitle: 'Gợi ý các thực phẩm thay thế không chứa chất dị ứng',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Danh sách mua sắm: Gợi ý thay thế lành mạnh.'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              _buildQuickActionCard(
                icon: Icons.monitor_heart_outlined,
                iconColor: const Color(0xFFF59E0B),
                title: 'Nhật Ký Phản Ứng & Triệu Chứng',
                subtitle: 'Theo dõi phản ứng tiêu hóa, ngứa ngáy sau khi ăn',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Nhật ký sức khỏe: Ghi nhận phản ứng lâm sàng.'),
                      backgroundColor: Color(0xFFF59E0B),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Cloud Backend Verified Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Cloud Backend: ngobinh2006.pythonanywhere.com (Active)',
                        style: TextStyle(
                          color: Color(0xFF065F46),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.cloud_done_rounded, color: Color(0xFF059669), size: 16),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        width: 66,
        height: 66,
        margin: const EdgeInsets.only(top: 22),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _openScanModal,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 28),
                SizedBox(height: 1),
                Text(
                  'QUÉT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        elevation: 12,
        surfaceTintColor: Colors.white,
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left Group: Home & Community Feed (Social Network)
            Row(
              children: [
                _buildTabItem(
                  index: 0,
                  icon: Icons.home_rounded,
                  label: 'Trang chủ',
                  onTap: () {
                    setState(() => _currentTab = 0);
                  },
                ),
                const SizedBox(width: 8),
                _buildTabItem(
                  index: 1,
                  icon: Icons.dynamic_feed_rounded,
                  label: 'Cộng đồng',
                  onTap: () async {
                    setState(() => _currentTab = 1);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommunityFeedScreen(user: widget.user),
                      ),
                    );
                    setState(() => _currentTab = 0);
                  },
                ),
              ],
            ),

            // Spacer for center floating scan button
            const SizedBox(width: 48),

            // Right Group: Upload Product & Scan History
            Row(
              children: [
                _buildTabItem(
                  index: 2,
                  icon: Icons.add_photo_alternate_rounded,
                  label: 'Đăng tải',
                  onTap: () async {
                    setState(() => _currentTab = 2);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ContributeProductScreen(user: widget.user),
                      ),
                    );
                    setState(() => _currentTab = 0);
                  },
                ),
                const SizedBox(width: 8),
                _buildTabItem(
                  index: 3,
                  icon: Icons.history_rounded,
                  label: 'Lịch sử',
                  onTap: () {
                    _openHistoryModal();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
